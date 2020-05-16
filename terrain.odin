package workbench

import "core:fmt"

import "gpu"
import "math"
import "types"
import "shared"
import log "logging"
import plat "platform"
import "external/imgui"

edge_tex, tri_tex: Texture;

Terrain :: struct {
    model: Model,
    chunks: [dynamic]Terrain_Chunk,

    material: Material,

    chunk_size: Vec3,
    step: f32,
    iso_level: f32,
    poly_shaded: bool,

    // editing
    editing_active: bool,
    selected_brush: int,
    brush_size: f32,
    brush_strength: f32,
}

Terrain_Chunk :: struct {
    chunk_idx: int, // indexes into model meshes
    density_map: [][][]f32,
    data_tex: Texture,

    // compute shader
    vertex_count: u32,
    ssbo_vert: gpu.SSBO,
    ssbo_count: gpu.SSBO,
}

Terrain_Vertex :: struct {
    position: Vec3,
    tex_coord: Vec3,
    color: Colorf,
    normal: Vec3,
}

init_terrain :: proc() {
    ops := default_texture_options();
    ops.gpu_format = .R32I;
    ops.initial_data_format = .Red_Integer;
    ops.initial_data_element_type = .Int;
    edge_tex = create_texture_2d(256, 1, ops, transmute(^u8)&edgeTable[0]);
    tri_tex = create_texture_2d(16, 256, ops, transmute(^u8)&triTable[0]);
}

create_terrain :: proc(chunk_size: Vec3, step : f32 = 1, iso_max : f32 = 5) -> Terrain {

    density_map := make([][][]f32, int(chunk_size.x));
    for x in 0..<int(chunk_size.x) {
        hm1 := make([][]f32, int(chunk_size.z));
        for z in 0..<int(chunk_size.z) {
            hm2 := make([]f32, int(chunk_size.y));
            for y in 0..<int(chunk_size.y) {
                // val := f32(y-2);
                // hm2[y] = abs(val) > iso_max ? math.sign(val) * iso_max : val;
                hm2[y] = -f32(y-2);
            }
            hm1[z] = hm2;
        }

        density_map[x] = hm1;
    }

    terrain := Terrain {
        Model { "terrain", make([dynamic]Mesh, 0, 1), {}, {}, false, },
        make([dynamic]Terrain_Chunk, 0, 1),
        {},
        chunk_size,
        step,
        0,
        false, false, -1, 1, 0.25,
    };

    add_terrain_chunk(&terrain, density_map);

    return terrain;
}

add_terrain_chunk :: proc(using terrain: ^Terrain, _density_map: [][][]f32) {
    x := len(_density_map);
    z := len(_density_map[0]);
    y := len(_density_map[0][0]);
    chunk_size = {f32(x),f32(y),f32(z)};

    index := len(model.meshes);

    chunk := Terrain_Chunk {};
    chunk.chunk_idx = index;
    chunk.density_map = _density_map;

    when !shared.HEADLESS {
        chunk.ssbo_vert = gpu.gen_shaderbuffer_storage();
        chunk.ssbo_count = gpu.gen_shaderbuffer_storage();

        mesh_idx := add_mesh_to_model(&terrain.model, []Terrain_Vertex{}, {}, {});
        mesh := &model.meshes[mesh_idx];
        mesh.ssbo = chunk.ssbo_vert;

        gpu.bind_shaderbuffer(chunk.ssbo_vert);
        gpu.buffer_shader_storage(u32(15 * x * y * z * size_of(Terrain_Vertex)));
        gpu.bind_shader_storage_buffer_base(0, chunk.ssbo_vert);

        gpu.bind_shaderbuffer(chunk.ssbo_count);
        gpu.buffer_shader_storage(32, false);
        gpu.bind_shader_storage_buffer_base(1, chunk.ssbo_count);
    }

    append(&chunks, chunk);

    when !shared.HEADLESS {
        update_mesh(&model, index, []Terrain_Vertex{}, {});
        refresh_terrain_chunk_density(terrain, _density_map, index);
    }
}

refresh_terrain_chunk_density :: proc(using terrain: ^Terrain, _density_map: [][][]f32, index: int) {
    chunk := chunks[index];

    x := len(_density_map);
    z := len(_density_map[0]);
    y := len(_density_map[0][0]);

    dm := make([]f32, (x+2) * (y+2) * (z+2));
    defer delete(dm);

    i := 0;
    for ix in 0..<x { for iz in 0..<z { for iy in 0..<y {
        dm[i] = _density_map[ix][iz][iy];
        i += 1;
    } } }

    chunk.density_map = _density_map;
    chunk.vertex_count = 0;
    delete_texture(chunk.data_tex);
    ops := default_texture_options();
    ops.gpu_format = .R32F;
    ops.initial_data_format = .Red;
    ops.initial_data_element_type = .Float;
    chunk.data_tex = create_texture_3d(y, z, x, ops, transmute(^u8)&dm[0]);

    mesh := &model.meshes[chunk.chunk_idx];

    gpu.bind_vao(mesh.vao);

    // uniforms and textures
    shader := get_shader("terrain");
    gpu.use_program(shader);
    bind_texture_to_shader("dataFieldTex", chunk.data_tex, 0, shader);
    bind_texture_to_shader("edgeTableTex", edge_tex, 1, shader);
    bind_texture_to_shader("triTableTex", tri_tex, 2, shader);
    gpu.uniform_float(shader, "iso_level", iso_level);
    gpu.uniform_float(shader, "step", step);
    gpu.uniform_vec3(shader, "chunk_size", chunk_size);
    gpu.uniform_int(shader, "poly_shade", poly_shaded ? 1 : 0);

    gpu.bind_shaderbuffer(chunk.ssbo_count);
    gpu.buffer_shader_storage_sub_data(4, &chunk.vertex_count);

    gpu.dispatch_compute(cast(u32)chunk_size.x, cast(u32)chunk_size.y, cast(u32)chunk_size.z);
    gpu.memory_barrier();

    gpu.get_shader_storage_sub_data(4, &chunk.vertex_count);
    mesh.vertex_count = int(chunk.vertex_count);

    chunks[index] = chunk;
}

render_terrain :: proc(using terrain: ^Terrain, terrain_offset, scale: Vec3) {

    // edit mode
    if editing_active {
        mouse_world := get_mouse_world_position(main_camera, plat.main_window.mouse_position_unit);
        mouse_direction := get_mouse_direction_from_camera(main_camera, plat.main_window.mouse_position_unit);
        hit_pos, chunk_index, hit := raycast_into_terrain(terrain^, terrain_offset, mouse_world, mouse_direction);

        if hit {
            chunk := chunks[chunk_index];

            // TODO(jake): add chunks to the terrain as the user edits near the edge

            if plat.get_input(.Mouse_Left) {
                for xo:=-brush_size-step/2; xo<=brush_size+step/2; xo+=1 {
                    for yo:=-brush_size-step/2; yo<=brush_size+step/2; yo+=1 {
                        for zo:=-brush_size-step/2; zo<=brush_size+step/2; zo+=1 {

                            // grid_pos := Vec3{x,y,z} + brush_grid_center;
                            brush_pos := hit_pos + Vec3{xo,yo,zo}*step;
                            x := int((brush_pos.x-terrain_offset.x)/step);
                            y := int((brush_pos.y-terrain_offset.y)/step);
                            z := int((brush_pos.z-terrain_offset.z)/step);

                            if x<0 || y<0 || z<0 do continue;
                            if x>=len(chunk.density_map) || z>=len(chunk.density_map[x]) || y>=len(chunk.density_map[x][z]) do continue;

                            distance_to_center :f32= math.magnitude(hit_pos - brush_pos);
                            distance_strength :=  1 - (math.maxv(distance_to_center, 0.000001)/brush_size);
                            if distance_strength <= 0 do continue;

                            switch selected_brush {
                                case 0: { // raise
                                    current_val := chunk.density_map[x][z][y];
                                    chunk.density_map[x][z][y] = current_val + (distance_strength*brush_strength);
                                }
                                case 1: { // lower
                                    current_val := chunk.density_map[x][z][y];
                                    chunk.density_map[x][z][y] = current_val - (distance_strength*brush_strength);
                                }
                                case 2: { // place
                                    chunk.density_map[x][z][y] = iso_level+1;
                                }
                                case 3: { // delete
                                    chunk.density_map[x][z][y] = iso_level-1;
                                }
                                case: break;
                            }
                        }
                    }
                }

                refresh_terrain_chunk_density(terrain, chunk.density_map, chunk_index);
            }

            // Draw the brush
            cmd := create_draw_command(wb_sphere_model, get_shader("lit"), hit_pos, {1,1,1}*brush_size/8, {0,0,0,1}, {0, 0.3, 0.7, 0.3}, {0.5,0.5,0.5}, {});
            submit_draw_command(cmd);
        }
    }

    // actual terrain rendering

    // TODO (jake): cull far away terrain
    for chunk in chunks {
        cmd := create_draw_command(model, get_shader("lit"), terrain_offset, scale, {0,0,0,1}, {1,1,1,1}, material, {});
        submit_draw_command(cmd);
    }
}

render_terrain_editor :: proc(using terrain: ^Terrain) {
    if imgui.collapsing_header("Terrain") {
        imgui.indent();
        defer imgui.unindent();

        dirty := false;
        dirty |= imgui.slider_float("iso", &iso_level, -50, 50);
        dirty |= imgui.slider_float("Step", &step, 0.1, 2);
        dirty |= imgui.checkbox("Poly Shade", &poly_shaded);
        imgui_struct(&material, "Material", false);

        imgui.spacing();imgui.spacing();imgui.spacing();
        imgui.text("Brush");
        imgui.same_line();
        if imgui.button(editing_active ? "Disable Editing" : "Enable Editing") {
            editing_active = !editing_active;
        }

        @static brush_names : []string = { "Raise", "Lower", "Paint", "Delete" };

        imgui.same_line();
        if imgui.button("Tool") {
            imgui.open_popup("select_popup");
        }
        imgui.same_line();
        imgui.text_unformatted(selected_brush == -1 ? "<None>" : brush_names[selected_brush]);
        if (imgui.begin_popup("select_popup"))
        {
            imgui.text("Brushes");
            imgui.separator();
            for name, i in brush_names {
                if imgui.selectable(brush_names[i]) {
                    selected_brush = i;
                }
            }
            imgui.end_popup();
        }

        imgui.slider_float("Brush Strength", &brush_strength, 0, 1);
        imgui.slider_float("Brush Size", &brush_size, 1, 10);

        if dirty {
            for chunk, i in chunks {
                refresh_terrain_chunk_density(terrain, chunk.density_map, i);
            }
        }

        // size
        // {
        //     imgui.text("Size");
        //     imgui.push_item_width(100);
        //     imgui.input_float(tprint("x", "##non_range"), &chunk_size.x);imgui.same_line();
        //     imgui.input_float(tprint("y", "##non_range"), &chunk_size.y);imgui.same_line();
        //     imgui.input_float(tprint("z", "##non_range"), &chunk_size.z);
        //     imgui.pop_item_width();
        // }

        // if imgui.button("Regenerate") {

        //     new_density_map := make([][][]f32, int(chunk_size.x));
        //     for x in 0..<int(chunk_size.x) {
        //         hm1 := make([][]f32, int(chunk_size.z));
        //         for z in 0..<int(chunk_size.z) {
        //             hm2 := make([]f32, int(chunk_size.y));
        //             for y in 0..<int(chunk_size.y) {
        //                 hm2[y] = -f32(y-2);
        //             }
        //             hm1[z] = hm2;
        //         }

        //         new_density_map[x] = hm1;
        //     }

        //     // TODO(jake) something better for resizing
        //     // for yz in density_map {
        //     //     for z in density_map {
        //     //         delete(z);
        //     //     }
        //     //     delete(yz);
        //     // }
        //     // delete(density_map);

        //     // density_map = new_density_map;
        //     // refresh_terrain(terrain, new_density_map);
        // }
    }
}

vertex_interp :: proc(iso: f32, p1, p2: $T, v1, v2: f32) -> T {
    if abs(v1-v2) >0.0001 {
        return p1 + (p2 - p1)/(v2 - v1)*(iso - v1);
    } else {
        return p1;
    }
}

get_height_at_position :: proc(terrain: Terrain, terrain_origin: Vec3, _x, _z, y_min: f32) -> (f32, bool) {
    x := _x - terrain_origin.x;
    z := _z - terrain_origin.z;
    if x < 0 || z < 0 do return 0, false;
    if terrain.step <= 0 do return 0, false;

    // TODO(jake): broadphase terrain
    for chunk in terrain.chunks {
        if len(chunk.density_map)-1 <= int(x/terrain.step) do return 0, false;
        if len(chunk.density_map[int(x/terrain.step)])-1 <= int(z/terrain.step) do return 0, false;

        for val, y in chunk.density_map[int(x/terrain.step)][int(z/terrain.step)] {

            if terrain_origin.y + f32(y) < y_min do continue;

            next_val : f32 = -10000000000000;
            if y+1 < len(chunk.density_map[int(x/terrain.step)][int(z/terrain.step)]) {
                next_val = chunk.density_map[int(x/terrain.step)][int(z/terrain.step)][y+1];
            }

            if next_val < terrain.iso_level && val >= terrain.iso_level {
                if abs(next_val - val) > 0.00001 {
                    ypos := vertex_interp(terrain.iso_level, f32(y), f32(y+1), val, next_val);
                    return ypos+terrain_origin.y, true;
                }
                else {
                    return terrain_origin.y+f32(y), true;
                }
            }
        }
    }
    return 0, false;
}

MAX_DISTANCE : f32 : 1000;
raycast_into_terrain :: proc(using terrain: Terrain, terrain_origin, ray_origin, ray_direction: Vec3, max : f32 = MAX_DISTANCE, narrow_phase_min : f32 = 0.5) -> (Vec3, int, bool) {

    // TODO(jake): broadphase terrain physics
    for chunk, chunk_index in chunks {
        for dist : f32 = 0; dist < max; dist += step {
            
            current_pos := ray_origin + (ray_direction * dist);
            current_grid_pos := (current_pos - terrain_origin) / step;

            if  current_grid_pos.x < 0 ||
                current_grid_pos.z < 0 ||
                current_grid_pos.y < 0  {
                continue;
            }
            if  current_grid_pos.x >= chunk_size.x ||
                current_grid_pos.z >= chunk_size.z ||
                current_grid_pos.y >= chunk_size.y  {
                continue;
            }

            val0 := cube_val(chunk.density_map, 0, current_grid_pos);
            val1 := cube_val(chunk.density_map, 1, current_grid_pos);
            val2 := cube_val(chunk.density_map, 2, current_grid_pos);
            val3 := cube_val(chunk.density_map, 3, current_grid_pos);
            val4 := cube_val(chunk.density_map, 4, current_grid_pos);
            val5 := cube_val(chunk.density_map, 5, current_grid_pos);
            val6 := cube_val(chunk.density_map, 6, current_grid_pos);
            val7 := cube_val(chunk.density_map, 7, current_grid_pos);

            cube_index := 0;
            if val0 < iso_level do cube_index |= 1;
            if val1 < iso_level do cube_index |= 2;
            if val2 < iso_level do cube_index |= 4;
            if val3 < iso_level do cube_index |= 8;
            if val4 < iso_level do cube_index |= 16;
            if val5 < iso_level do cube_index |= 32;
            if val6 < iso_level do cube_index |= 64;
            if val7 < iso_level do cube_index |= 128;

            if cube_index == 0 || cube_index == 255 do continue;

            edge_val := edgeTable[cube_index];
            if edge_val == 0 do continue;

            pos0 := cube_pos(0, current_grid_pos)*step + terrain_origin;
            pos1 := cube_pos(1, current_grid_pos)*step + terrain_origin;
            pos2 := cube_pos(2, current_grid_pos)*step + terrain_origin;
            pos3 := cube_pos(3, current_grid_pos)*step + terrain_origin;
            pos4 := cube_pos(4, current_grid_pos)*step + terrain_origin;
            pos5 := cube_pos(5, current_grid_pos)*step + terrain_origin;
            pos6 := cube_pos(6, current_grid_pos)*step + terrain_origin;
            pos7 := cube_pos(7, current_grid_pos)*step + terrain_origin;

            vert_list := [12]Vec3{};
            vert_list[0] = vertex_interp(iso_level, pos0, pos1, val0, val1);
            vert_list[1] = vertex_interp(iso_level, pos1, pos2, val1, val2);
            vert_list[2] = vertex_interp(iso_level, pos2, pos3, val2, val3);
            vert_list[3] = vertex_interp(iso_level, pos3, pos0, val3, val0);
            vert_list[4] = vertex_interp(iso_level, pos4, pos5, val4, val5);
            vert_list[5] = vertex_interp(iso_level, pos5, pos6, val5, val6);
            vert_list[6] = vertex_interp(iso_level, pos6, pos7, val6, val7);
            vert_list[7] = vertex_interp(iso_level, pos7, pos4, val7, val4);
            vert_list[8] = vertex_interp(iso_level, pos0, pos4, val0, val4);
            vert_list[9] = vertex_interp(iso_level, pos1, pos5, val1, val5);
            vert_list[10] = vertex_interp(iso_level, pos2, pos6, val2, val6);
            vert_list[11] = vertex_interp(iso_level, pos3, pos7, val3, val7);

            for i:=0; triTable[cube_index][i] != -1; i += 3 {
                pos1 := vert_list[triTable[cube_index][i+0]];
                pos2 := vert_list[triTable[cube_index][i+1]];
                pos3 := vert_list[triTable[cube_index][i+2]];

                pt, intersects := intersect_triangle(ray_origin, ray_direction, pos1, pos2, pos3);

                draw_debug_box(pos1, {0.05,0.05, 0.05}, intersects ? {0,1,0,1} : {1,0,0,1});
                draw_debug_box(pos2, {0.05,0.05, 0.05}, intersects ? {0,1,0,1} : {1,0,0,1});
                draw_debug_box(pos3, {0.05,0.05, 0.05}, intersects ? {0,1,0,1} : {1,0,0,1});

                if intersects {
                    return pt, chunk_index, true;
                }
            }
        }
    }

    return Vec3{}, -1, false;
}


cube_val :: proc(dm: [][][]f32, i: int, pos: Vec3) -> f32 {
    // // The data texture is streamed in y > z > x
    corner := pos + vert_decals[i];

    x := int(math.round(corner.x));
    z := int(math.round(corner.z));
    y := int(math.round(corner.y));

    x = math.minv(x, len(dm)-1);
    z = math.minv(z, len(dm[x])-1);
    y = math.minv(y, len(dm[x][z])-1);

    return dm[x][z][y];
}

cube_pos :: proc(i: int, pos: Vec3) -> Vec3 { 
    p := pos + vert_decals[i];
    return Vec3{math.floor(p.x), math.floor(p.y), math.floor(p.z)};
}

intersect_triangle :: proc(origin, direction: Vec3, A, B, C: Vec3) -> (Vec3, bool) { 
   E1 := B-A;
   E2 := C-A;
   N := math.cross(E1,E2);
   det := -math.dot(direction, N);
   invdet := 1.0/det;
   AO := origin - A;
   DAO := math.cross(AO, direction);
   u :=  math.dot(E2,DAO) * invdet;
   v := -math.dot(E1,DAO) * invdet;
   t :=  math.dot(AO,N)  * invdet; 
   return origin + direction*t, (det >= 1e-6 && t >= 0.0 && u >= 0.0 && v >= 0.0 && (u+v) <= 1.0);
}

vert_decals := [8]Vec3 {
    {0, 0, 1},
    {1, 0, 1},
    {1, 0, 0},
    {0, 0, 0},
    {0, 1, 1},
    {1, 1, 1},
    {1, 1, 0},
    {0, 1, 0},
};

// CUBE MARCHING TABLES
edgeTable := [256]i32 {
    0x0  , 0x109, 0x203, 0x30a, 0x406, 0x50f, 0x605, 0x70c,
    0x80c, 0x905, 0xa0f, 0xb06, 0xc0a, 0xd03, 0xe09, 0xf00,
    0x190, 0x99 , 0x393, 0x29a, 0x596, 0x49f, 0x795, 0x69c,
    0x99c, 0x895, 0xb9f, 0xa96, 0xd9a, 0xc93, 0xf99, 0xe90,
    0x230, 0x339, 0x33 , 0x13a, 0x636, 0x73f, 0x435, 0x53c,
    0xa3c, 0xb35, 0x83f, 0x936, 0xe3a, 0xf33, 0xc39, 0xd30,
    0x3a0, 0x2a9, 0x1a3, 0xaa , 0x7a6, 0x6af, 0x5a5, 0x4ac,
    0xbac, 0xaa5, 0x9af, 0x8a6, 0xfaa, 0xea3, 0xda9, 0xca0,
    0x460, 0x569, 0x663, 0x76a, 0x66 , 0x16f, 0x265, 0x36c,
    0xc6c, 0xd65, 0xe6f, 0xf66, 0x86a, 0x963, 0xa69, 0xb60,
    0x5f0, 0x4f9, 0x7f3, 0x6fa, 0x1f6, 0xff , 0x3f5, 0x2fc,
    0xdfc, 0xcf5, 0xfff, 0xef6, 0x9fa, 0x8f3, 0xbf9, 0xaf0,
    0x650, 0x759, 0x453, 0x55a, 0x256, 0x35f, 0x55 , 0x15c,
    0xe5c, 0xf55, 0xc5f, 0xd56, 0xa5a, 0xb53, 0x859, 0x950,
    0x7c0, 0x6c9, 0x5c3, 0x4ca, 0x3c6, 0x2cf, 0x1c5, 0xcc ,
    0xfcc, 0xec5, 0xdcf, 0xcc6, 0xbca, 0xac3, 0x9c9, 0x8c0,
    0x8c0, 0x9c9, 0xac3, 0xbca, 0xcc6, 0xdcf, 0xec5, 0xfcc,
    0xcc , 0x1c5, 0x2cf, 0x3c6, 0x4ca, 0x5c3, 0x6c9, 0x7c0,
    0x950, 0x859, 0xb53, 0xa5a, 0xd56, 0xc5f, 0xf55, 0xe5c,
    0x15c, 0x55 , 0x35f, 0x256, 0x55a, 0x453, 0x759, 0x650,
    0xaf0, 0xbf9, 0x8f3, 0x9fa, 0xef6, 0xfff, 0xcf5, 0xdfc,
    0x2fc, 0x3f5, 0xff , 0x1f6, 0x6fa, 0x7f3, 0x4f9, 0x5f0,
    0xb60, 0xa69, 0x963, 0x86a, 0xf66, 0xe6f, 0xd65, 0xc6c,
    0x36c, 0x265, 0x16f, 0x66 , 0x76a, 0x663, 0x569, 0x460,
    0xca0, 0xda9, 0xea3, 0xfaa, 0x8a6, 0x9af, 0xaa5, 0xbac,
    0x4ac, 0x5a5, 0x6af, 0x7a6, 0xaa , 0x1a3, 0x2a9, 0x3a0,
    0xd30, 0xc39, 0xf33, 0xe3a, 0x936, 0x83f, 0xb35, 0xa3c,
    0x53c, 0x435, 0x73f, 0x636, 0x13a, 0x33 , 0x339, 0x230,
    0xe90, 0xf99, 0xc93, 0xd9a, 0xa96, 0xb9f, 0x895, 0x99c,
    0x69c, 0x795, 0x49f, 0x596, 0x29a, 0x393, 0x99 , 0x190,
    0xf00, 0xe09, 0xd03, 0xc0a, 0xb06, 0xa0f, 0x905, 0x80c,
    0x70c, 0x605, 0x50f, 0x406, 0x30a, 0x203, 0x109, 0x0
};

triTable := [256][16]i32 {
    {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 8, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 1, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {1, 8, 3, 9, 8, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {1, 2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 8, 3, 1, 2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {9, 2, 10, 0, 2, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {2, 8, 3, 2, 10, 8, 10, 9, 8, -1, -1, -1, -1, -1, -1, -1},
    {3, 11, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 11, 2, 8, 11, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {1, 9, 0, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {1, 11, 2, 1, 9, 11, 9, 8, 11, -1, -1, -1, -1, -1, -1, -1},
    {3, 10, 1, 11, 10, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 10, 1, 0, 8, 10, 8, 11, 10, -1, -1, -1, -1, -1, -1, -1},
    {3, 9, 0, 3, 11, 9, 11, 10, 9, -1, -1, -1, -1, -1, -1, -1},
    {9, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {4, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {4, 3, 0, 7, 3, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 1, 9, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {4, 1, 9, 4, 7, 1, 7, 3, 1, -1, -1, -1, -1, -1, -1, -1},
    {1, 2, 10, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {3, 4, 7, 3, 0, 4, 1, 2, 10, -1, -1, -1, -1, -1, -1, -1},
    {9, 2, 10, 9, 0, 2, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1},
    {2, 10, 9, 2, 9, 7, 2, 7, 3, 7, 9, 4, -1, -1, -1, -1},
    {8, 4, 7, 3, 11, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {11, 4, 7, 11, 2, 4, 2, 0, 4, -1, -1, -1, -1, -1, -1, -1},
    {9, 0, 1, 8, 4, 7, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1},
    {4, 7, 11, 9, 4, 11, 9, 11, 2, 9, 2, 1, -1, -1, -1, -1},
    {3, 10, 1, 3, 11, 10, 7, 8, 4, -1, -1, -1, -1, -1, -1, -1},
    {1, 11, 10, 1, 4, 11, 1, 0, 4, 7, 11, 4, -1, -1, -1, -1},
    {4, 7, 8, 9, 0, 11, 9, 11, 10, 11, 0, 3, -1, -1, -1, -1},
    {4, 7, 11, 4, 11, 9, 9, 11, 10, -1, -1, -1, -1, -1, -1, -1},
    {9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {9, 5, 4, 0, 8, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 5, 4, 1, 5, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {8, 5, 4, 8, 3, 5, 3, 1, 5, -1, -1, -1, -1, -1, -1, -1},
    {1, 2, 10, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {3, 0, 8, 1, 2, 10, 4, 9, 5, -1, -1, -1, -1, -1, -1, -1},
    {5, 2, 10, 5, 4, 2, 4, 0, 2, -1, -1, -1, -1, -1, -1, -1},
    {2, 10, 5, 3, 2, 5, 3, 5, 4, 3, 4, 8, -1, -1, -1, -1},
    {9, 5, 4, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 11, 2, 0, 8, 11, 4, 9, 5, -1, -1, -1, -1, -1, -1, -1},
    {0, 5, 4, 0, 1, 5, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1},
    {2, 1, 5, 2, 5, 8, 2, 8, 11, 4, 8, 5, -1, -1, -1, -1},
    {10, 3, 11, 10, 1, 3, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1},
    {4, 9, 5, 0, 8, 1, 8, 10, 1, 8, 11, 10, -1, -1, -1, -1},
    {5, 4, 0, 5, 0, 11, 5, 11, 10, 11, 0, 3, -1, -1, -1, -1},
    {5, 4, 8, 5, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1},
    {9, 7, 8, 5, 7, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {9, 3, 0, 9, 5, 3, 5, 7, 3, -1, -1, -1, -1, -1, -1, -1},
    {0, 7, 8, 0, 1, 7, 1, 5, 7, -1, -1, -1, -1, -1, -1, -1},
    {1, 5, 3, 3, 5, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {9, 7, 8, 9, 5, 7, 10, 1, 2, -1, -1, -1, -1, -1, -1, -1},
    {10, 1, 2, 9, 5, 0, 5, 3, 0, 5, 7, 3, -1, -1, -1, -1},
    {8, 0, 2, 8, 2, 5, 8, 5, 7, 10, 5, 2, -1, -1, -1, -1},
    {2, 10, 5, 2, 5, 3, 3, 5, 7, -1, -1, -1, -1, -1, -1, -1},
    {7, 9, 5, 7, 8, 9, 3, 11, 2, -1, -1, -1, -1, -1, -1, -1},
    {9, 5, 7, 9, 7, 2, 9, 2, 0, 2, 7, 11, -1, -1, -1, -1},
    {2, 3, 11, 0, 1, 8, 1, 7, 8, 1, 5, 7, -1, -1, -1, -1},
    {11, 2, 1, 11, 1, 7, 7, 1, 5, -1, -1, -1, -1, -1, -1, -1},
    {9, 5, 8, 8, 5, 7, 10, 1, 3, 10, 3, 11, -1, -1, -1, -1},
    {5, 7, 0, 5, 0, 9, 7, 11, 0, 1, 0, 10, 11, 10, 0, -1},
    {11, 10, 0, 11, 0, 3, 10, 5, 0, 8, 0, 7, 5, 7, 0, -1},
    {11, 10, 5, 7, 11, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {10, 6, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 8, 3, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {9, 0, 1, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {1, 8, 3, 1, 9, 8, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1},
    {1, 6, 5, 2, 6, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {1, 6, 5, 1, 2, 6, 3, 0, 8, -1, -1, -1, -1, -1, -1, -1},
    {9, 6, 5, 9, 0, 6, 0, 2, 6, -1, -1, -1, -1, -1, -1, -1},
    {5, 9, 8, 5, 8, 2, 5, 2, 6, 3, 2, 8, -1, -1, -1, -1},
    {2, 3, 11, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {11, 0, 8, 11, 2, 0, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1},
    {0, 1, 9, 2, 3, 11, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1},
    {5, 10, 6, 1, 9, 2, 9, 11, 2, 9, 8, 11, -1, -1, -1, -1},
    {6, 3, 11, 6, 5, 3, 5, 1, 3, -1, -1, -1, -1, -1, -1, -1},
    {0, 8, 11, 0, 11, 5, 0, 5, 1, 5, 11, 6, -1, -1, -1, -1},
    {3, 11, 6, 0, 3, 6, 0, 6, 5, 0, 5, 9, -1, -1, -1, -1},
    {6, 5, 9, 6, 9, 11, 11, 9, 8, -1, -1, -1, -1, -1, -1, -1},
    {5, 10, 6, 4, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {4, 3, 0, 4, 7, 3, 6, 5, 10, -1, -1, -1, -1, -1, -1, -1},
    {1, 9, 0, 5, 10, 6, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1},
    {10, 6, 5, 1, 9, 7, 1, 7, 3, 7, 9, 4, -1, -1, -1, -1},
    {6, 1, 2, 6, 5, 1, 4, 7, 8, -1, -1, -1, -1, -1, -1, -1},
    {1, 2, 5, 5, 2, 6, 3, 0, 4, 3, 4, 7, -1, -1, -1, -1},
    {8, 4, 7, 9, 0, 5, 0, 6, 5, 0, 2, 6, -1, -1, -1, -1},
    {7, 3, 9, 7, 9, 4, 3, 2, 9, 5, 9, 6, 2, 6, 9, -1},
    {3, 11, 2, 7, 8, 4, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1},
    {5, 10, 6, 4, 7, 2, 4, 2, 0, 2, 7, 11, -1, -1, -1, -1},
    {0, 1, 9, 4, 7, 8, 2, 3, 11, 5, 10, 6, -1, -1, -1, -1},
    {9, 2, 1, 9, 11, 2, 9, 4, 11, 7, 11, 4, 5, 10, 6, -1},
    {8, 4, 7, 3, 11, 5, 3, 5, 1, 5, 11, 6, -1, -1, -1, -1},
    {5, 1, 11, 5, 11, 6, 1, 0, 11, 7, 11, 4, 0, 4, 11, -1},
    {0, 5, 9, 0, 6, 5, 0, 3, 6, 11, 6, 3, 8, 4, 7, -1},
    {6, 5, 9, 6, 9, 11, 4, 7, 9, 7, 11, 9, -1, -1, -1, -1},
    {10, 4, 9, 6, 4, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {4, 10, 6, 4, 9, 10, 0, 8, 3, -1, -1, -1, -1, -1, -1, -1},
    {10, 0, 1, 10, 6, 0, 6, 4, 0, -1, -1, -1, -1, -1, -1, -1},
    {8, 3, 1, 8, 1, 6, 8, 6, 4, 6, 1, 10, -1, -1, -1, -1},
    {1, 4, 9, 1, 2, 4, 2, 6, 4, -1, -1, -1, -1, -1, -1, -1},
    {3, 0, 8, 1, 2, 9, 2, 4, 9, 2, 6, 4, -1, -1, -1, -1},
    {0, 2, 4, 4, 2, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {8, 3, 2, 8, 2, 4, 4, 2, 6, -1, -1, -1, -1, -1, -1, -1},
    {10, 4, 9, 10, 6, 4, 11, 2, 3, -1, -1, -1, -1, -1, -1, -1},
    {0, 8, 2, 2, 8, 11, 4, 9, 10, 4, 10, 6, -1, -1, -1, -1},
    {3, 11, 2, 0, 1, 6, 0, 6, 4, 6, 1, 10, -1, -1, -1, -1},
    {6, 4, 1, 6, 1, 10, 4, 8, 1, 2, 1, 11, 8, 11, 1, -1},
    {9, 6, 4, 9, 3, 6, 9, 1, 3, 11, 6, 3, -1, -1, -1, -1},
    {8, 11, 1, 8, 1, 0, 11, 6, 1, 9, 1, 4, 6, 4, 1, -1},
    {3, 11, 6, 3, 6, 0, 0, 6, 4, -1, -1, -1, -1, -1, -1, -1},
    {6, 4, 8, 11, 6, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {7, 10, 6, 7, 8, 10, 8, 9, 10, -1, -1, -1, -1, -1, -1, -1},
    {0, 7, 3, 0, 10, 7, 0, 9, 10, 6, 7, 10, -1, -1, -1, -1},
    {10, 6, 7, 1, 10, 7, 1, 7, 8, 1, 8, 0, -1, -1, -1, -1},
    {10, 6, 7, 10, 7, 1, 1, 7, 3, -1, -1, -1, -1, -1, -1, -1},
    {1, 2, 6, 1, 6, 8, 1, 8, 9, 8, 6, 7, -1, -1, -1, -1},
    {2, 6, 9, 2, 9, 1, 6, 7, 9, 0, 9, 3, 7, 3, 9, -1},
    {7, 8, 0, 7, 0, 6, 6, 0, 2, -1, -1, -1, -1, -1, -1, -1},
    {7, 3, 2, 6, 7, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {2, 3, 11, 10, 6, 8, 10, 8, 9, 8, 6, 7, -1, -1, -1, -1},
    {2, 0, 7, 2, 7, 11, 0, 9, 7, 6, 7, 10, 9, 10, 7, -1},
    {1, 8, 0, 1, 7, 8, 1, 10, 7, 6, 7, 10, 2, 3, 11, -1},
    {11, 2, 1, 11, 1, 7, 10, 6, 1, 6, 7, 1, -1, -1, -1, -1},
    {8, 9, 6, 8, 6, 7, 9, 1, 6, 11, 6, 3, 1, 3, 6, -1},
    {0, 9, 1, 11, 6, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {7, 8, 0, 7, 0, 6, 3, 11, 0, 11, 6, 0, -1, -1, -1, -1},
    {7, 11, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {7, 6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {3, 0, 8, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 1, 9, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {8, 1, 9, 8, 3, 1, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1},
    {10, 1, 2, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {1, 2, 10, 3, 0, 8, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1},
    {2, 9, 0, 2, 10, 9, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1},
    {6, 11, 7, 2, 10, 3, 10, 8, 3, 10, 9, 8, -1, -1, -1, -1},
    {7, 2, 3, 6, 2, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {7, 0, 8, 7, 6, 0, 6, 2, 0, -1, -1, -1, -1, -1, -1, -1},
    {2, 7, 6, 2, 3, 7, 0, 1, 9, -1, -1, -1, -1, -1, -1, -1},
    {1, 6, 2, 1, 8, 6, 1, 9, 8, 8, 7, 6, -1, -1, -1, -1},
    {10, 7, 6, 10, 1, 7, 1, 3, 7, -1, -1, -1, -1, -1, -1, -1},
    {10, 7, 6, 1, 7, 10, 1, 8, 7, 1, 0, 8, -1, -1, -1, -1},
    {0, 3, 7, 0, 7, 10, 0, 10, 9, 6, 10, 7, -1, -1, -1, -1},
    {7, 6, 10, 7, 10, 8, 8, 10, 9, -1, -1, -1, -1, -1, -1, -1},
    {6, 8, 4, 11, 8, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {3, 6, 11, 3, 0, 6, 0, 4, 6, -1, -1, -1, -1, -1, -1, -1},
    {8, 6, 11, 8, 4, 6, 9, 0, 1, -1, -1, -1, -1, -1, -1, -1},
    {9, 4, 6, 9, 6, 3, 9, 3, 1, 11, 3, 6, -1, -1, -1, -1},
    {6, 8, 4, 6, 11, 8, 2, 10, 1, -1, -1, -1, -1, -1, -1, -1},
    {1, 2, 10, 3, 0, 11, 0, 6, 11, 0, 4, 6, -1, -1, -1, -1},
    {4, 11, 8, 4, 6, 11, 0, 2, 9, 2, 10, 9, -1, -1, -1, -1},
    {10, 9, 3, 10, 3, 2, 9, 4, 3, 11, 3, 6, 4, 6, 3, -1},
    {8, 2, 3, 8, 4, 2, 4, 6, 2, -1, -1, -1, -1, -1, -1, -1},
    {0, 4, 2, 4, 6, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {1, 9, 0, 2, 3, 4, 2, 4, 6, 4, 3, 8, -1, -1, -1, -1},
    {1, 9, 4, 1, 4, 2, 2, 4, 6, -1, -1, -1, -1, -1, -1, -1},
    {8, 1, 3, 8, 6, 1, 8, 4, 6, 6, 10, 1, -1, -1, -1, -1},
    {10, 1, 0, 10, 0, 6, 6, 0, 4, -1, -1, -1, -1, -1, -1, -1},
    {4, 6, 3, 4, 3, 8, 6, 10, 3, 0, 3, 9, 10, 9, 3, -1},
    {10, 9, 4, 6, 10, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {4, 9, 5, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 8, 3, 4, 9, 5, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1},
    {5, 0, 1, 5, 4, 0, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1},
    {11, 7, 6, 8, 3, 4, 3, 5, 4, 3, 1, 5, -1, -1, -1, -1},
    {9, 5, 4, 10, 1, 2, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1},
    {6, 11, 7, 1, 2, 10, 0, 8, 3, 4, 9, 5, -1, -1, -1, -1},
    {7, 6, 11, 5, 4, 10, 4, 2, 10, 4, 0, 2, -1, -1, -1, -1},
    {3, 4, 8, 3, 5, 4, 3, 2, 5, 10, 5, 2, 11, 7, 6, -1},
    {7, 2, 3, 7, 6, 2, 5, 4, 9, -1, -1, -1, -1, -1, -1, -1},
    {9, 5, 4, 0, 8, 6, 0, 6, 2, 6, 8, 7, -1, -1, -1, -1},
    {3, 6, 2, 3, 7, 6, 1, 5, 0, 5, 4, 0, -1, -1, -1, -1},
    {6, 2, 8, 6, 8, 7, 2, 1, 8, 4, 8, 5, 1, 5, 8, -1},
    {9, 5, 4, 10, 1, 6, 1, 7, 6, 1, 3, 7, -1, -1, -1, -1},
    {1, 6, 10, 1, 7, 6, 1, 0, 7, 8, 7, 0, 9, 5, 4, -1},
    {4, 0, 10, 4, 10, 5, 0, 3, 10, 6, 10, 7, 3, 7, 10, -1},
    {7, 6, 10, 7, 10, 8, 5, 4, 10, 4, 8, 10, -1, -1, -1, -1},
    {6, 9, 5, 6, 11, 9, 11, 8, 9, -1, -1, -1, -1, -1, -1, -1},
    {3, 6, 11, 0, 6, 3, 0, 5, 6, 0, 9, 5, -1, -1, -1, -1},
    {0, 11, 8, 0, 5, 11, 0, 1, 5, 5, 6, 11, -1, -1, -1, -1},
    {6, 11, 3, 6, 3, 5, 5, 3, 1, -1, -1, -1, -1, -1, -1, -1},
    {1, 2, 10, 9, 5, 11, 9, 11, 8, 11, 5, 6, -1, -1, -1, -1},
    {0, 11, 3, 0, 6, 11, 0, 9, 6, 5, 6, 9, 1, 2, 10, -1},
    {11, 8, 5, 11, 5, 6, 8, 0, 5, 10, 5, 2, 0, 2, 5, -1},
    {6, 11, 3, 6, 3, 5, 2, 10, 3, 10, 5, 3, -1, -1, -1, -1},
    {5, 8, 9, 5, 2, 8, 5, 6, 2, 3, 8, 2, -1, -1, -1, -1},
    {9, 5, 6, 9, 6, 0, 0, 6, 2, -1, -1, -1, -1, -1, -1, -1},
    {1, 5, 8, 1, 8, 0, 5, 6, 8, 3, 8, 2, 6, 2, 8, -1},
    {1, 5, 6, 2, 1, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {1, 3, 6, 1, 6, 10, 3, 8, 6, 5, 6, 9, 8, 9, 6, -1},
    {10, 1, 0, 10, 0, 6, 9, 5, 0, 5, 6, 0, -1, -1, -1, -1},
    {0, 3, 8, 5, 6, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {10, 5, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {11, 5, 10, 7, 5, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {11, 5, 10, 11, 7, 5, 8, 3, 0, -1, -1, -1, -1, -1, -1, -1},
    {5, 11, 7, 5, 10, 11, 1, 9, 0, -1, -1, -1, -1, -1, -1, -1},
    {10, 7, 5, 10, 11, 7, 9, 8, 1, 8, 3, 1, -1, -1, -1, -1},
    {11, 1, 2, 11, 7, 1, 7, 5, 1, -1, -1, -1, -1, -1, -1, -1},
    {0, 8, 3, 1, 2, 7, 1, 7, 5, 7, 2, 11, -1, -1, -1, -1},
    {9, 7, 5, 9, 2, 7, 9, 0, 2, 2, 11, 7, -1, -1, -1, -1},
    {7, 5, 2, 7, 2, 11, 5, 9, 2, 3, 2, 8, 9, 8, 2, -1},
    {2, 5, 10, 2, 3, 5, 3, 7, 5, -1, -1, -1, -1, -1, -1, -1},
    {8, 2, 0, 8, 5, 2, 8, 7, 5, 10, 2, 5, -1, -1, -1, -1},
    {9, 0, 1, 5, 10, 3, 5, 3, 7, 3, 10, 2, -1, -1, -1, -1},
    {9, 8, 2, 9, 2, 1, 8, 7, 2, 10, 2, 5, 7, 5, 2, -1},
    {1, 3, 5, 3, 7, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 8, 7, 0, 7, 1, 1, 7, 5, -1, -1, -1, -1, -1, -1, -1},
    {9, 0, 3, 9, 3, 5, 5, 3, 7, -1, -1, -1, -1, -1, -1, -1},
    {9, 8, 7, 5, 9, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {5, 8, 4, 5, 10, 8, 10, 11, 8, -1, -1, -1, -1, -1, -1, -1},
    {5, 0, 4, 5, 11, 0, 5, 10, 11, 11, 3, 0, -1, -1, -1, -1},
    {0, 1, 9, 8, 4, 10, 8, 10, 11, 10, 4, 5, -1, -1, -1, -1},
    {10, 11, 4, 10, 4, 5, 11, 3, 4, 9, 4, 1, 3, 1, 4, -1},
    {2, 5, 1, 2, 8, 5, 2, 11, 8, 4, 5, 8, -1, -1, -1, -1},
    {0, 4, 11, 0, 11, 3, 4, 5, 11, 2, 11, 1, 5, 1, 11, -1},
    {0, 2, 5, 0, 5, 9, 2, 11, 5, 4, 5, 8, 11, 8, 5, -1},
    {9, 4, 5, 2, 11, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {2, 5, 10, 3, 5, 2, 3, 4, 5, 3, 8, 4, -1, -1, -1, -1},
    {5, 10, 2, 5, 2, 4, 4, 2, 0, -1, -1, -1, -1, -1, -1, -1},
    {3, 10, 2, 3, 5, 10, 3, 8, 5, 4, 5, 8, 0, 1, 9, -1},
    {5, 10, 2, 5, 2, 4, 1, 9, 2, 9, 4, 2, -1, -1, -1, -1},
    {8, 4, 5, 8, 5, 3, 3, 5, 1, -1, -1, -1, -1, -1, -1, -1},
    {0, 4, 5, 1, 0, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {8, 4, 5, 8, 5, 3, 9, 0, 5, 0, 3, 5, -1, -1, -1, -1},
    {9, 4, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {4, 11, 7, 4, 9, 11, 9, 10, 11, -1, -1, -1, -1, -1, -1, -1},
    {0, 8, 3, 4, 9, 7, 9, 11, 7, 9, 10, 11, -1, -1, -1, -1},
    {1, 10, 11, 1, 11, 4, 1, 4, 0, 7, 4, 11, -1, -1, -1, -1},
    {3, 1, 4, 3, 4, 8, 1, 10, 4, 7, 4, 11, 10, 11, 4, -1},
    {4, 11, 7, 9, 11, 4, 9, 2, 11, 9, 1, 2, -1, -1, -1, -1},
    {9, 7, 4, 9, 11, 7, 9, 1, 11, 2, 11, 1, 0, 8, 3, -1},
    {11, 7, 4, 11, 4, 2, 2, 4, 0, -1, -1, -1, -1, -1, -1, -1},
    {11, 7, 4, 11, 4, 2, 8, 3, 4, 3, 2, 4, -1, -1, -1, -1},
    {2, 9, 10, 2, 7, 9, 2, 3, 7, 7, 4, 9, -1, -1, -1, -1},
    {9, 10, 7, 9, 7, 4, 10, 2, 7, 8, 7, 0, 2, 0, 7, -1},
    {3, 7, 10, 3, 10, 2, 7, 4, 10, 1, 10, 0, 4, 0, 10, -1},
    {1, 10, 2, 8, 7, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {4, 9, 1, 4, 1, 7, 7, 1, 3, -1, -1, -1, -1, -1, -1, -1},
    {4, 9, 1, 4, 1, 7, 0, 8, 1, 8, 7, 1, -1, -1, -1, -1},
    {4, 0, 3, 7, 4, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {4, 8, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {9, 10, 8, 10, 11, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {3, 0, 9, 3, 9, 11, 11, 9, 10, -1, -1, -1, -1, -1, -1, -1},
    {0, 1, 10, 0, 10, 8, 8, 10, 11, -1, -1, -1, -1, -1, -1, -1},
    {3, 1, 10, 11, 3, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {1, 2, 11, 1, 11, 9, 9, 11, 8, -1, -1, -1, -1, -1, -1, -1},
    {3, 0, 9, 3, 9, 11, 1, 2, 9, 2, 11, 9, -1, -1, -1, -1},
    {0, 2, 11, 8, 0, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {3, 2, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {2, 3, 8, 2, 8, 10, 10, 8, 9, -1, -1, -1, -1, -1, -1, -1},
    {9, 10, 2, 0, 9, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {2, 3, 8, 2, 8, 10, 0, 1, 8, 1, 10, 8, -1, -1, -1, -1},
    {1, 10, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {1, 3, 8, 9, 1, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 9, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {0, 3, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1},
    {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1}
};