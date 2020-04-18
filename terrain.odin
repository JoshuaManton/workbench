package workbench

import "core:fmt"

import "gpu"
import log "logging"
import "math"
import "types"
import "profiler"

Terrain :: struct {
    model: gpu.Model,

    color0: Colorf,
    color1: Colorf,

    height_map: [][]f32,
    step: f32,
}

Terrain_Vertex :: struct {
    position: Vec3,
    colour: Colorf,
}

create_terrain :: proc(size: int, height_map: [][]f32, step : f32 = 0.25) -> Terrain {
    assert(size <= len(height_map), "Height map too smalle for terrain");

    terrain := Terrain {
        gpu.Model {
            "terrain",
            make([dynamic]Mesh, 0, 1),
            {}, {}, false,
        },
        {36.0/255.0, 191.0/255.0, 70.0/255.0, 1},
        {150.0/255.0, 130.0/255.0, 65.0/255.0, 1},
        height_map,
        step
    };

    verts := make([dynamic]Terrain_Vertex, 0, size);
    for x in 0..size {
        for z in 0..size {

            height := height_map[x][z];

            append(&verts, Terrain_Vertex {
                Vec3 { f32(x) * step, height, f32(z) * step },
                types.color_lerp(terrain.color0, terrain.color1, height),
            });
        }
    }

    inds := make([dynamic]u32, 0, size);
    for x in 0..size-1 {
        for z in 0..size-1 {
            bottom_left := ((size+1) * x) + z;
            bottom_right := bottom_left + (size+1);
            top_left := bottom_left + 1;
            top_right := bottom_right + 1;

            append(&inds, u32(bottom_left));
            append(&inds, u32(top_right));
            append(&inds, u32(bottom_right));

            append(&inds, u32(bottom_left));
            append(&inds, u32(top_left));
            append(&inds, u32(top_right));
        }
    }

    add_mesh_to_model(&terrain.model, verts[:], inds[:], {});

    return terrain;
}

blerp :: proc(c00, c10, c01, c11, tx, ty: f32) -> f32 {
    return lerp(lerp(c00, c10, tx), lerp(c01, c11, tx), ty);
}

get_height_at_position :: proc(terrain: Terrain, terrain_origin: Vec3, _x, _z: f32) -> (f32, bool) {
    x := int((_x - terrain_origin.x) / terrain.step);
    z := int((_z - terrain_origin.z) / terrain.step);

    if x < 0 || z < 0 do return 0, false;
    if x >= len(terrain.height_map) do return 0, false;
    if z >= len(terrain.height_map[x]) do return 0, false;

    h0 := terrain.height_map[x][z];

    h1 := h0;
    if x+1 >= 0 && x+1 < len(terrain.height_map) {
        h1 = terrain.height_map[x+1][z];
    }

    h2 := h0;
    if z+1 >= 0 && z+1 < len(terrain.height_map[x]) {
        h2 = terrain.height_map[x][z+1];
    }

    h3 := h0;
    if x+1 >= 0 && z+1 >= 0 &&
       x+1 < len(terrain.height_map) &&
       z+1 < len(terrain.height_map[x+1]) {
        h3 = terrain.height_map[x+1][z+1];
    }

    x0 := math.floor(_x);
    z0 := math.floor(_z);
    x1 := x0 + terrain.step;
    z1 := z0 + terrain.step;
    mp := (Vec3{_x,0,_z} - Vec3{x0,0,z0}) / (Vec3{x1,0,z1} - Vec3{x0,0,z0}); // mid point on the current terrain quad

    return terrain_origin.y + blerp(h0, h1, h2, h3, mp.x, mp.z), true;
}

MAX_DISTANCE : f32 : 1000;
raycast_into_terrain :: proc(terrain: Terrain, terrain_origin, ray_origin, ray_direction: Vec3, max : f32 = MAX_DISTANCE, narrow_phase_min : f32 = 0.1) -> (Vec3, bool) {
    profiler.TIMED_SECTION(&wb_profiler);
    for dist : f32 = 0; dist < max; dist += terrain.step {
        current_pos := ray_origin + (ray_direction * dist);

        height, exists := get_height_at_position(terrain, terrain_origin, current_pos.x, current_pos.z);
        if !exists do continue;

        if height >= current_pos.y {
            prev_pos := current_pos;
            prev_height := height;
            prev_distance := dist;
            current_step := terrain.step;
            for i in 0..10 {
                if abs(prev_height - prev_pos.y) <= narrow_phase_min do break;

                if prev_height < current_pos.y {
                    prev_distance += current_step / 2;
                } else if prev_height > current_pos.y {
                    prev_distance -= current_step / 2;
                }

                prev_pos = ray_origin + (ray_direction * prev_distance);
                h, e := get_height_at_position(terrain, terrain_origin, prev_pos.x, prev_pos.z);
                current_step := current_step / 2;
                prev_height = h;
            }

            return prev_pos, true;
        }
    }

    return {}, false;
}