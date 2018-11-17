package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"

      import odingl "external/gl"

      import        "external/stb"
      import        "external/glfw"
      import        "external/imgui"

//
// Rendermodes
//

Rendermode_Proc :: #type proc();

mvp_matrix: Mat4;

view_matrix: Mat4;
model_matrix: Mat4;

perspective_projection_matrix: Mat4;
orthographic_projection_matrix: Mat4;

unit_to_pixel_matrix:  Mat4;
unit_to_viewport_matrix:  Mat4;

pixel_to_world_matrix: Mat4;
pixel_to_viewport_matrix: Mat4;

viewport_to_pixel_matrix: Mat4;
viewport_to_unit_matrix:  Mat4;

is_perspective: bool;

orthographic_camera :: inline proc(size: f32) {
	is_perspective = false;
	camera_size = size;
}
perspective_camera :: inline proc(fov: f32) {
	is_perspective = true;
	camera_size = fov;
}


// note(josh): these rendermode_* procs cannot be marked as inline because https://i.imgur.com/ROXPLQe.png
rendermode_world :: proc() {
	current_rendermode = rendermode_world;
	if is_perspective {
		mvp_matrix = mul(mul(perspective_projection_matrix, view_matrix), model_matrix);
	}
	else {
		mvp_matrix = orthographic_projection_matrix;
	}
}
rendermode_unit :: proc() {
	current_rendermode = rendermode_unit;
	mvp_matrix = unit_to_viewport_matrix;
}
rendermode_pixel :: proc() {
	current_rendermode = rendermode_pixel;
	mvp_matrix = pixel_to_viewport_matrix;
}


world_to_viewport :: inline proc(position: Vec3) -> Vec3 {
	if is_perspective {
		mv := mul(perspective_projection_matrix, view_matrix);
		result := mul(mv, Vec4{position.x, position.y, position.z, 1});
		if result.w > 0 do result /= result.w;
		new_result := Vec3{result.x, result.y, result.z};
		return new_result;
	}

	result := mul(orthographic_projection_matrix, Vec4{position.x, position.y, position.z, 1});
	return Vec3{result.x, result.y, result.z};
}
world_to_pixel :: inline proc(a: Vec3) -> Vec3 {
	result := world_to_viewport(a);
	result = viewport_to_pixel(result);
	return result;
}
world_to_unit :: inline proc(a: Vec3) -> Vec3 {
	result := world_to_viewport(a);
	result = viewport_to_unit(result);
	return result;
}

unit_to_pixel :: inline proc(a: Vec3) -> Vec3 {
	result := mul(unit_to_pixel_matrix, Vec4{a.x, a.y, 0, 1});
	return Vec3{result.x, result.y, 0};
}
unit_to_viewport :: inline proc(a: Vec3) -> Vec3 {
	result := mul(unit_to_viewport_matrix, Vec4{a.x, a.y, 0, 1});
	return Vec3{result.x, result.y, 0};
}

pixel_to_viewport :: inline proc(a: Vec3) -> Vec3 {
	a /= Vec3{current_window_width/2, current_window_height/2, 0};
	a -= Vec3{1, 1, 0};
	a.z = 0;
	return a;
}
pixel_to_unit :: inline proc(a: Vec3) -> Vec3 {
	a /= Vec3{current_window_width, current_window_height, 0};
	a.z = 0;
	return a;
}

viewport_to_pixel :: inline proc(a: Vec3) -> Vec3 {
	a += Vec3{1, 1, 0};
	a *= Vec3{current_window_width/2, current_window_height/2, 0};
	a.z = 0;
	return a;
}
viewport_to_unit :: inline proc(a: Vec3) -> Vec3 {
	a += Vec3{1, 1, 0};
	a /= 2;
	a.z = 0;
	return a;
}

camera_size: f32 = 1;
camera_position: Vec3;
camera_rotation: Vec3;
camera_target: Vec3;

//
// Immediate-mode rendering
//

im_quad :: proc[im_quad_color, im_quad_sprite, im_quad_sprite_color];

im_quad_color :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, min, max: Vec3, color: Colorf, auto_cast render_order: int = current_render_layer) {
	im_quad_sprite_color(rendermode, shader, min, max, Sprite{}, color, render_order);
}
im_quad_sprite :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, min, max: Vec3, sprite: Sprite, auto_cast render_order: int = current_render_layer) {
	im_quad_sprite_color(rendermode, shader, min, max, sprite, COLOR_WHITE, render_order);
}
im_quad_sprite_color :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, min, max: Vec3, sprite: Sprite, color: Colorf, auto_cast render_order: int = current_render_layer) {
	p0, p1, p2, p3 := min, Vec3{min.x, max.y, max.z}, max, Vec3{max.x, min.y, min.z};

	im_vertex(rendermode, shader, sprite.id, p0, sprite.uvs[0], color, render_order);
	im_vertex(rendermode, shader, sprite.id, p1, sprite.uvs[1], color, render_order);
	im_vertex(rendermode, shader, sprite.id, p2, sprite.uvs[2], color, render_order);
	im_vertex(rendermode, shader, sprite.id, p2, sprite.uvs[2], color, render_order);
	im_vertex(rendermode, shader, sprite.id, p3, sprite.uvs[3], color, render_order);
	im_vertex(rendermode, shader, sprite.id, p0, sprite.uvs[0], color, render_order);
}
im_sprite :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, position: Vec3, scale: Vec3, sprite: Sprite, color: Colorf, _pivot := Vec2{0.5, 0.5}, auto_cast render_order: int = current_render_layer) {
	pivot := to_vec3(_pivot);
	size := (Vec3{sprite.width, sprite.height, 0} * scale);
	min := position;
	max := min + size;
	min -= size * pivot;
	max -= size * pivot;
	p0, p1, p2, p3 := min, Vec3{min.x, max.y, max.z}, max, Vec3{max.x, min.y, min.z};

	im_vertex(rendermode, shader, sprite.id, p0, sprite.uvs[0], color, render_order);
	im_vertex(rendermode, shader, sprite.id, p1, sprite.uvs[1], color, render_order);
	im_vertex(rendermode, shader, sprite.id, p2, sprite.uvs[2], color, render_order);
	im_vertex(rendermode, shader, sprite.id, p2, sprite.uvs[2], color, render_order);
	im_vertex(rendermode, shader, sprite.id, p3, sprite.uvs[3], color, render_order);
	im_vertex(rendermode, shader, sprite.id, p0, sprite.uvs[0], color, render_order);
}

im_cube :: inline proc(position: Vec3, scale: f32) {
	vertex_positions := [?]Vec3 {
		{-0.5,-0.5,-0.5}, {-0.5,-0.5, 0.5}, {-0.5, 0.5, 0.5},
	    {0.5, 0.5,-0.5}, {-0.5,-0.5,-0.5}, {-0.5, 0.5,-0.5},
	    {0.5,-0.5, 0.5}, {-0.5,-0.5,-0.5}, {0.5,-0.5,-0.5},
	    {0.5, 0.5,-0.5}, {0.5,-0.5,-0.5}, {-0.5,-0.5,-0.5},
	    {-0.5,-0.5,-0.5}, {-0.5, 0.5, 0.5}, {-0.5, 0.5,-0.5},
	    {0.5,-0.5, 0.5}, {-0.5,-0.5, 0.5}, {-0.5,-0.5,-0.5},
	    {-0.5, 0.5, 0.5}, {-0.5,-0.5, 0.5}, {0.5,-0.5, 0.5},
	    {0.5, 0.5, 0.5}, {0.5,-0.5,-0.5}, {0.5, 0.5,-0.5},
	    {0.5,-0.5,-0.5}, {0.5, 0.5, 0.5}, {0.5,-0.5, 0.5},
	    {0.5, 0.5, 0.5}, {0.5, 0.5,-0.5}, {-0.5, 0.5,-0.5},
	    {0.5, 0.5, 0.5}, {-0.5, 0.5,-0.5}, {-0.5, 0.5, 0.5},
	    {0.5, 0.5, 0.5}, {-0.5, 0.5, 0.5}, {0.5,-0.5, 0.5},
	};
	for p, i in vertex_positions {
		t := cast(f32)i / len(vertex_positions);
		im_vertex(rendermode_world, shader_rgba_3d, position + p * scale, Colorf{t, 0, 0, 1});
	}
}

im_vertex :: proc[im_vertex_color, im_vertex_color_texture];
im_vertex_color :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, position: Vec3, color: Colorf, auto_cast render_order: int = current_render_layer) {
	im_vertex_color_texture(rendermode, shader, 0, position, Vec2{}, color, render_order);
}

im_vertex_color_texture :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, texture: Texture, position: Vec3, tex_coord: Vec2, color: Colorf, auto_cast render_order: int = current_render_layer) {
	assert(shader != 0);
	serial := len(im_buffered_verts);
	vertex_info := Buffered_Vertex{render_order, serial, position, tex_coord, color, rendermode, shader, texture, do_scissor, scissor_rect1};
	append(&im_buffered_verts, vertex_info);
}

im_text :: proc(rendermode: Rendermode_Proc, font: ^Font, str: string, position: Vec2, color: Colorf, size: f32, layer: int) -> f32 {
	// todo: make im_text() be render_mode agnostic
	// old := current_render_mode;
	// rendering_unit_space();
	// defer old();

	assert(rendermode == rendermode_unit);

	start := position;
	for _, i in str {
		c := str[i];
		is_space := c == ' ';
		if is_space do c = 'l'; // @DrawStringSpaces: @Hack:

		min, max: Vec2;
		whitespace_ratio: f32;
		quad: stb.Aligned_Quad;
		{
			//
			size_pixels: Vec2;
			// NOTE!!!!!!!!!!! quad x0 y0 is TOP LEFT and x1 y1 is BOTTOM RIGHT. // I think?!!!!???!!!!
			quad = stb.get_baked_quad(font.chars, font.dim, font.dim, cast(int)c, &size_pixels.x, &size_pixels.y, true);
			size_pixels.y = abs(quad.y1 - quad.y0);
			size_pixels *= size;

			ww := cast(f32)current_window_width;
			hh := cast(f32)current_window_height;
			// min = position + (Vec2{quad.x0, -quad.y1} * size);
			// max = position + (Vec2{quad.x1, -quad.y0} * size);
			min = position + (Vec2{quad.x0, -quad.y1} * size / Vec2{ww, hh});
			max = position + (Vec2{quad.x1, -quad.y0} * size / Vec2{ww, hh});
			// Padding
			{
				// todo(josh): @DrawStringSpaces: Currently dont handle spaces properly :/
				abs_hh := abs(quad.t1 - quad.t0);
				char_aspect: f32;
				if abs_hh == 0 {
					char_aspect = 1;
				}
				else {
					char_aspect = abs(quad.s1 - quad.s0) / abs(quad.t1 - quad.t0);
				}
				full_width := size_pixels.x;
				char_width := size_pixels.y * char_aspect;
				whitespace_ratio = 1 - (char_width / full_width);
			}
		}

		sprite: Sprite;
		{
			uv0 := Vec2{quad.s0, quad.t1};
			uv1 := Vec2{quad.s0, quad.t0};
			uv2 := Vec2{quad.s1, quad.t0};
			uv3 := Vec2{quad.s1, quad.t1};
			sprite = Sprite{{uv0, uv1, uv2, uv3}, 0, 0, font.id};
		}

		if !is_space {
			im_quad_sprite_color(rendermode, shader_text, to_vec3(min), to_vec3(max), sprite, color, layer);
		}

		width := max.x - min.x;
		position.x += width + (width * whitespace_ratio);
	}

	width := position.x - start.x;
	return width;
}

get_string_width :: proc(font: ^Font, str: string, size: f32) -> f32 {
	// todo: make im_text() be render_mode agnostic
	// old := current_render_mode;
	// rendering_unit_space();
	// defer old();

	start: Vec2;
	position := start;
	for _, i in str {
		c := str[i];
		is_space := c == ' ';
		if is_space do c = 'l'; // @DrawStringSpaces: @Hack:

		min, max: Vec2;
		whitespace_ratio: f32;
		quad: stb.Aligned_Quad;
		{
			//
			size_pixels: Vec2;
			// NOTE!!!!!!!!!!! quad x0 y0 is TOP LEFT and x1 y1 is BOTTOM RIGHT. // I think?!!!!???!!!!
			quad = stb.get_baked_quad(font.chars, font.dim, font.dim, cast(int)c, &size_pixels.x, &size_pixels.y, true);
			size_pixels.y = abs(quad.y1 - quad.y0);
			size_pixels *= size;

			ww := cast(f32)current_window_width;
			hh := cast(f32)current_window_height;
			// min = position + (Vec2{quad.x0, -quad.y1} * size);
			// max = position + (Vec2{quad.x1, -quad.y0} * size);
			min = position + (Vec2{quad.x0, -quad.y1} * size / Vec2{ww, hh});
			max = position + (Vec2{quad.x1, -quad.y0} * size / Vec2{ww, hh});
			// Padding
			{
				// todo(josh): @DrawStringSpaces: Currently dont handle spaces properly :/
				abs_hh := abs(quad.t1 - quad.t0);
				char_aspect: f32;
				if abs_hh == 0 {
					char_aspect = 1;
				}
				else {
					char_aspect = abs(quad.s1 - quad.s0) / abs(quad.t1 - quad.t0);
				}
				full_width := size_pixels.x;
				char_width := size_pixels.y * char_aspect;
				whitespace_ratio = 1 - (char_width / full_width);
			}
		}

		width := max.x - min.x;
		position.x += width + (width * whitespace_ratio);
	}

	width := position.x - start.x;
	return width;
}

// get_font_height :: inline proc(font: ^Font, size: f32) -> f32 {
// 	size_ratio := _get_size_ratio_for_font(font, size);
// 	// return size * size_ratio / 2;
// 	assert(current_render_mode == rendering_unit_space);

// 	biggest_height: f32;
// 	for c in font.chars {
// 		height := cast(f32)c.y1 - cast(f32)c.y0;
// 		if height > biggest_height {
// 			biggest_height = height;
// 		}
// 	}

// 	biggest_height /= cast(f32)current_window_height * size_ratio;

// 	return biggest_height * size;
// }

// get_centered_baseline :: inline proc(font: ^Font, text: string, size: f32, min, max: Vec2) -> Vec2 {
// 	string_width  := get_string_width(font, text, size);
// 	string_height := get_font_height(font, size);
// 	box_width     := max.x - min.x;
// 	box_height    := max.y - min.y;

// 	leftover_x := box_width - string_width;
// 	xx := leftover_x - (leftover_x / 2);

// 	leftover_y := box_height - string_height;
// 	// todo
// 	yy := string_height;// - (leftover_y / 2);

// 	result := min + Vec2{xx, yy};

// 	return result;
// }

//
// Render layers
//

current_render_layer: int;

swap_render_layers :: inline proc(auto_cast layer: int) -> int {
	tmp := current_render_layer;
	current_render_layer = layer;
	return tmp;
}

//
// Scissor
//

do_scissor:   bool;
scissor_rect1: [4]int;

scissor :: proc(x1, y1, ww, hh: int) {
	assert(do_scissor == false, "We don't support nested scissors right now.");
	do_scissor = true;
	scissor_rect1 = {x1, y1, ww, hh};
}

full_screen_scissor_rect :: proc() -> [4]int {
	return {0, 0, cast(int)(current_window_width+0.5), cast(int)(current_window_height+0.5)};
}

end_scissor :: proc() {
	assert(do_scissor);
	do_scissor = false;
	scissor_rect1 = full_screen_scissor_rect();
}

//
// Internals
//

Buffered_Vertex :: struct {
	render_order:  int,
	serial_number: int,

	position:  Vec3,
	tex_coord: Vec2,
	color:     Colorf,

	rendermode:   Rendermode_Proc,
	shader:       Shader_Program,
	texture:      Texture,
	scissor:      bool,
	scissor_rect: [4]int,
}

Vertex2D :: struct {
	position: Vec3,
	tex_coord: Vec2,
	color: Colorf,
}

Sprite :: struct {
	uvs:    [4]Vec2,
	width:  f32,
	height: f32,
	id:     Texture,
}

im_buffered_verts:     [dynamic]Buffered_Vertex;
im_queued_for_drawing: [dynamic]Vertex2D;

_update_renderer :: proc() {
	clear(&debug_vertices);
	clear(&im_buffered_verts);

	log_gl_errors(#procedure);

	odingl.Enable(odingl.BLEND);
	odingl.BlendFunc(odingl.SRC_ALPHA, odingl.ONE_MINUS_SRC_ALPHA);
	if is_perspective {
		// odingl.Enable(odingl.CULL_FACE);
		odingl.Enable(odingl.DEPTH_TEST); // note(josh): @DepthTest: fucks with the sorting of 2D stuff because all Z is 0 :/
		odingl.Clear(odingl.COLOR_BUFFER_BIT | odingl.DEPTH_BUFFER_BIT); // note(josh): @DepthTest: DEPTH stuff fucks with 2D sorting because all Z is 0.
	}
	else {
		odingl.Disable(odingl.DEPTH_TEST); // note(josh): @DepthTest: fucks with the sorting of 2D stuff because all Z is 0 :/
		odingl.Clear(odingl.COLOR_BUFFER_BIT);
	}

	odingl.Viewport(0, 0, cast(i32)current_window_width, cast(i32)current_window_height);
}

set_clear_color :: inline proc(color: Colorf) {
	odingl.ClearColor(color.r, color.g, color.b, 1.0);
}

render_scene :: proc(scene: Scene) {
	log_gl_errors(#procedure);

	num_draw_calls = 0;
	if scene.render != nil {
		scene.render(client_target_delta_time);
	}
	im_draw_flush(odingl.TRIANGLES, im_buffered_verts);
	draw_debug_lines();
	log_gl_errors(tprint("scene_name: ", scene.name));
}

is_scissor: bool;

current_shader:     Shader_Program;
current_texture:    Texture;
current_rendermode: proc();

im_draw_flush :: proc(mode: u32, verts: [dynamic]Buffered_Vertex) {
	set_shader :: inline proc(program: Shader_Program, mode: u32, location := #caller_location) {
		current_shader = program;
		use_program(program);
	}

	set_texture :: inline proc(texture: Texture, mode: u32, location := #caller_location) {
		current_texture = texture;
		bind_texture2d(texture);
	}

	if !is_perspective {
		sort.quick_sort_proc(verts[:], proc(a, b: Buffered_Vertex) -> int {
				diff := a.render_order - b.render_order;
				if diff != 0 do return diff;
				return a.serial_number - b.serial_number;
			});
	}

	model_matrix = identity(Mat4);

	current_shader = 0;
	current_texture = 0;
	current_rendermode = nil;

	for vertex_info in verts {
		shader_mismatch  := vertex_info.shader != current_shader;
		texture_mismatch := vertex_info.texture != current_texture;
		scissor_mismatch := vertex_info.scissor != is_scissor;
		rendermode_mismatch := vertex_info.rendermode != current_rendermode;
		if shader_mismatch || texture_mismatch || scissor_mismatch || rendermode_mismatch {
			draw_vertex_list(im_queued_for_drawing, mode);
			clear(&im_queued_for_drawing);
		}

		if shader_mismatch  do set_shader(vertex_info.shader, mode);
		if texture_mismatch do set_texture(vertex_info.texture, mode);
		if rendermode_mismatch { vertex_info.rendermode(); }
		if scissor_mismatch {
			is_scissor = vertex_info.scissor;
			if is_scissor {
				odingl.Enable(odingl.SCISSOR_TEST);
				odingl.Scissor(vertex_info.scissor_rect[0], vertex_info.scissor_rect[1], vertex_info.scissor_rect[2], vertex_info.scissor_rect[3]);
			}
			else {
				odingl.Disable(odingl.SCISSOR_TEST);
				odingl.Scissor(0, 0, current_window_width, current_window_height);
			}
		}

		vertex := Vertex2D{vertex_info.position, vertex_info.tex_coord, vertex_info.color};
		append(&im_queued_for_drawing, vertex);
	}

	draw_vertex_list(im_queued_for_drawing, mode);
	clear(&im_queued_for_drawing);
}

debugging_rendering: bool;

// note(josh): i32 because my dear-imgui stuff wasn't working with int
debugging_rendering_max_draw_calls : i32 = -1;
num_draw_calls: i32;
when DEVELOPER {
	debug_will_issue_next_draw_call :: proc() -> bool {
		return debugging_rendering_max_draw_calls == -1 || num_draw_calls < debugging_rendering_max_draw_calls;
	}
}

draw_vertex_list :: proc(list: [dynamic]$Vertex_Type, mode: u32, loc := #caller_location) {
	if len(list) == 0 {
		return;
	}

	when DEVELOPER {
		if debugging_rendering_max_draw_calls != -1 && num_draw_calls >= debugging_rendering_max_draw_calls {
			num_draw_calls += 1;
			return;
		}
	}

	bind_vao(vao);
	bind_buffer(vbo);

	set_vertex_format(Vertex_Type);

	when DEVELOPER {
		if debugging_rendering {
			for _, i in list {
				vert := &list[i];
				push_debug_vertex(current_rendermode, vert.position, COLOR_GREEN);
			}
		}
	}

	// TODO: investigate STATIC_DRAW vs others
	odingl.BufferData(odingl.ARRAY_BUFFER, size_of(Vertex_Type) * len(list), &list[0], odingl.STATIC_DRAW);

	program := get_current_shader();
	uniform(program, "atlas_texture", 0);
	uniform_matrix4fv(program, "mvp_matrix", 1, false, &mvp_matrix[0][0]);

	num_draw_calls += 1;

	odingl.DrawArrays(mode, 0, cast(i32)len(list));
}

draw_mesh_raw :: proc(mesh: Mesh)
{
	when DEVELOPER {
		if debugging_rendering_max_draw_calls != -1 && num_draw_calls >= debugging_rendering_max_draw_calls {
			num_draw_calls += 1;
			return;
		}
	}

	bind_vao(mesh.vertex_array);
	bind_buffer(mesh.vertex_buffer);
	bind_buffer(mesh.index_buffer);

	program := get_current_shader();
	uniform(program, "atlas_texture", 0);
	uniform_matrix4fv(program, "mvp_matrix", 1, false, &mvp_matrix[0][0]);

	num_draw_calls += 1;

	//odingl.DrawArrays(odingl.TRIANGLES, 0, i32(mesh.vertex_count));

	if debugging_rendering {
		odingl.DrawElements(odingl.LINES, i32(mesh.index_count), odingl.UNSIGNED_INT, nil);
	}
	else {
		odingl.DrawElements(odingl.TRIANGLES, i32(mesh.index_count), odingl.UNSIGNED_INT, nil);
	}
}

//
// Debug
//

Line_Segment :: struct {
	a, b: Vec3,
	color: Colorf,
	rendermode: Rendermode_Proc,
}

debug_vertices: [dynamic]Buffered_Vertex;

push_debug_vertex :: inline proc(rendermode: Rendermode_Proc, a: Vec3, color: Colorf) {
	v := Buffered_Vertex{0, len(debug_vertices), a, {}, color, rendermode, shader_rgba, {}, false, full_screen_scissor_rect()};
	append(&debug_vertices, v);
}

push_debug_line :: inline proc(rendermode: Rendermode_Proc, a, b: Vec3, color: Colorf) {
	push_debug_vertex(rendermode, a, color);
	push_debug_vertex(rendermode, b, color);
}

push_debug_box :: proc[push_debug_box_min_max, push_debug_box_points];
push_debug_box_min_max :: inline proc(rendermode: Rendermode_Proc, min, max: Vec3, color: Colorf) {
	push_debug_line(rendermode, Vec3{min.x, min.y, min.z}, Vec3{min.x, max.y, max.z}, color);
	push_debug_line(rendermode, Vec3{min.x, max.y, max.z}, Vec3{max.x, max.y, max.z}, color);
	push_debug_line(rendermode, Vec3{max.x, max.y, max.z}, Vec3{max.x, min.y, min.z}, color);
	push_debug_line(rendermode, Vec3{max.x, min.y, min.z}, Vec3{min.x, min.y, min.z}, color);
}
push_debug_box_points :: inline proc(rendermode: Rendermode_Proc, a, b, c, d: Vec3, color: Colorf) {
	push_debug_line(rendermode, a, b, color);
	push_debug_line(rendermode, b, c, color);
	push_debug_line(rendermode, c, d, color);
	push_debug_line(rendermode, d, a, color);
}

draw_debug_lines :: inline proc() {
	assert(len(debug_vertices) % 2 == 0);
	im_draw_flush(odingl.LINES, debug_vertices);
}