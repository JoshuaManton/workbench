package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"

      import odingl "shared:odin-gl"

      import stb    "shared:workbench/stb"
      import        "shared:workbench/glfw"

//
// Rendermodes
//

Rendermode_Proc :: #type proc(Vec3) -> Vec3;

model_matrix:      Mat4;
view_matrix:       Mat4;
projection_matrix: Mat4;

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

world_to_viewport :: inline proc(position: Vec3) -> Vec3 {
	if is_perspective {
		mvp := mul(mul(projection_matrix, view_matrix), model_matrix);
		result := mul(mvp, Vec4{position.x, position.y, position.z, 1});
		assert(result.w != 0);
		new_result := Vec3{result.x, result.y, result.z} / result.w;
		return new_result;
	}

	result := mul(projection_matrix, Vec4{position.x, position.y, position.z, 1});
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

//
// Bound GPU things
//

current_shader:      Shader_Program;
current_texture:     Texture;

set_shader :: inline proc(program: Shader_Program, location := #caller_location) {
	_draw_flush();

	current_shader = program;
	use_program(program);
}

set_texture :: inline proc(texture: Texture, location := #caller_location) {
	_draw_flush();

	current_texture = texture;
	bind_texture2d(texture);
}

//
// Primitives
//

camera_size: f32 = 1;
camera_position: Vec3;
camera_rotation: Vec3;
camera_target: Vec3;

COLOR_WHITE  := Colorf{1, 1, 1, 1};
COLOR_RED    := Colorf{1, 0, 0, 1};
COLOR_GREEN  := Colorf{0, 1, 0, 1};
COLOR_BLUE   := Colorf{0, 0, 1, 1};
COLOR_BLACK  := Colorf{0, 0, 0, 1};
COLOR_YELLOW := Colorf{1, 1, 0, 1};

push_quad :: proc[push_quad_color, push_quad_sprite, push_quad_sprite_color];

push_quad_color :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, min, max: Vec3, color: Colorf, auto_cast render_order: int = current_render_layer) {
	push_quad_sprite_color(rendermode, shader, min, max, Sprite{}, color, render_order);
}
push_quad_sprite :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, min, max: Vec3, sprite: Sprite, auto_cast render_order: int = current_render_layer) {
	push_quad_sprite_color(rendermode, shader, min, max, sprite, COLOR_WHITE, render_order);
}
push_quad_sprite_color :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, min, max: Vec3, sprite: Sprite, color: Colorf, auto_cast render_order: int = current_render_layer) {
	p0, p1, p2, p3 := min, Vec3{min.x, max.y, max.z}, max, Vec3{max.x, min.y, min.z};

	push_vertex(rendermode, shader, sprite.id, p0, sprite.uvs[0], color, render_order);
	push_vertex(rendermode, shader, sprite.id, p1, sprite.uvs[1], color, render_order);
	push_vertex(rendermode, shader, sprite.id, p2, sprite.uvs[2], color, render_order);
	push_vertex(rendermode, shader, sprite.id, p2, sprite.uvs[2], color, render_order);
	push_vertex(rendermode, shader, sprite.id, p3, sprite.uvs[3], color, render_order);
	push_vertex(rendermode, shader, sprite.id, p0, sprite.uvs[0], color, render_order);

	if debugging_rendering {
		draw_debug_line(rendermode, p0, p1, COLOR_GREEN);
		draw_debug_line(rendermode, p1, p2, COLOR_GREEN);
		draw_debug_line(rendermode, p2, p0, COLOR_GREEN);
		draw_debug_line(rendermode, p2, p3, COLOR_GREEN);
		draw_debug_line(rendermode, p3, p0, COLOR_GREEN);
		draw_debug_line(rendermode, p0, p2, COLOR_GREEN);
	}
}
push_sprite :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, position: Vec3, scale: Vec3, sprite: Sprite, color: Colorf, _pivot := Vec2{0.5, 0.5}, auto_cast render_order: int = current_render_layer) {
	pivot := to_vec3(_pivot);
	size := (Vec3{sprite.width, sprite.height, 0} * scale);
	min := position;
	max := min + size;
	min -= size * pivot;
	max -= size * pivot;
	p0, p1, p2, p3 := min, Vec3{min.x, max.y, max.z}, max, Vec3{max.x, min.y, min.z};

	push_vertex(rendermode, shader, sprite.id, p0, sprite.uvs[0], color, render_order);
	push_vertex(rendermode, shader, sprite.id, p1, sprite.uvs[1], color, render_order);
	push_vertex(rendermode, shader, sprite.id, p2, sprite.uvs[2], color, render_order);
	push_vertex(rendermode, shader, sprite.id, p2, sprite.uvs[2], color, render_order);
	push_vertex(rendermode, shader, sprite.id, p3, sprite.uvs[3], color, render_order);
	push_vertex(rendermode, shader, sprite.id, p0, sprite.uvs[0], color, render_order);

	if debugging_rendering {
		draw_debug_line(rendermode, p0, p1, COLOR_GREEN);
		draw_debug_line(rendermode, p1, p2, COLOR_GREEN);
		draw_debug_line(rendermode, p2, p0, COLOR_GREEN);
		draw_debug_line(rendermode, p2, p3, COLOR_GREEN);
		draw_debug_line(rendermode, p3, p0, COLOR_GREEN);
		draw_debug_line(rendermode, p0, p2, COLOR_GREEN);
	}
}

push_vertex :: proc[push_vertex_color, push_vertex_color_texture];
push_vertex_color :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, position: Vec3, color: Colorf, auto_cast render_order: int = current_render_layer) {
	push_vertex_color_texture(rendermode, shader, 0, position, Vec2{}, color, render_order);
}

push_vertex_color_texture :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, texture: Texture, position: Vec3, tex_coord: Vec2, color: Colorf, auto_cast render_order: int = current_render_layer, buffer := buffered_vertices) {
	assert(shader != 0);
	serial := len(buffered_vertices);
	vertex_info := Buffered_Vertex{render_order, serial, position, tex_coord, color, rendermode, shader, texture, do_scissor, scissor_rect1};
	append(&buffered_vertices, vertex_info);
}

draw_string :: proc(rendermode: Rendermode_Proc, font: ^Font, str: string, position: Vec2, color: Colorf, size: f32, layer: int) -> f32 {
	// todo: make draw_string() be render_mode agnostic
	// old := current_render_mode;
	// rendering_unit_space();
	// defer old();

	assert(rendermode == unit_to_viewport);

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
			push_quad_sprite_color(rendermode, shader_text, to_vec3(min), to_vec3(max), sprite, color, layer);
		}

		width := max.x - min.x;
		position.x += width + (width * whitespace_ratio);
	}

	width := position.x - start.x;
	return width;
}

get_string_width :: proc(font: ^Font, str: string, size: f32) -> f32 {
	// todo: make draw_string() be render_mode agnostic
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

end_scissor :: proc() {
	assert(do_scissor);
	do_scissor = false;
	scissor_rect1 = {0, 0, cast(int)(current_window_width+0.5), cast(int)(current_window_height+0.5)};
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

Vertex_Type :: struct {
	vertex_position: Vec3,
	tex_coord: Vec2,
	color: Colorf,
}

Sprite :: struct {
	uvs:    [4]Vec2,
	width:  f32,
	height: f32,
	id:     Texture,
}

buffered_vertices:   [dynamic]Buffered_Vertex;
queued_for_drawing:  [dynamic]Vertex_Type;

debugging_rendering: bool;

_update_renderer :: proc(dt: f32) {
	clear(&debug_vertices);
	clear(&debug_lines);
	clear(&buffered_vertices);
}

_wb_render :: proc() {
	if get_key_down(Key.F4) {
		debugging_rendering = !debugging_rendering;
	}

	bind_vao(vao);
	bind_buffer(vbo);

	set_vertex_format(Vertex_Type);

	odingl.Enable(odingl.BLEND);
	// odingl.Enable(odingl.CULL_FACE);
	// odingl.Enable(odingl.DEPTH_TEST); // note(josh): @DepthTest: fucks with the sorting of 2D stuff because all Z is 0 :/
	odingl.BlendFunc(odingl.SRC_ALPHA, odingl.ONE_MINUS_SRC_ALPHA);

	odingl.ClearColor(sin01(time), 0.5, 0.8, 1.0);
	odingl.Viewport(0, 0, cast(i32)current_window_width, cast(i32)current_window_height);
	// odingl.Clear(odingl.COLOR_BUFFER_BIT | odingl.DEPTH_BUFFER_BIT); // note(josh): @DepthTest: DEPTH stuff fucks with 2D sorting because all Z is 0.
	odingl.Clear(odingl.COLOR_BUFFER_BIT);

	client_render_proc(client_target_delta_time);

	draw_buffered_vertices(odingl.TRIANGLES, buffered_vertices);
	_debug_on_after_render();
}

is_scissor: bool;

draw_buffered_vertices :: proc(mode: u32, verts: [dynamic]Buffered_Vertex) {
	sort.quick_sort_proc(verts[:], proc(a, b: Buffered_Vertex) -> int {
			diff := a.render_order - b.render_order;
			if diff != 0 do return diff;
			return a.serial_number - b.serial_number;
		});

	for vertex_info in verts {
		shader_mismatch  := vertex_info.shader != current_shader;
		texture_mismatch := vertex_info.texture != current_texture;
		scissor_mismatch := vertex_info.scissor != is_scissor;
		if shader_mismatch || texture_mismatch || scissor_mismatch {
			_draw_flush();
		}

		if shader_mismatch  do set_shader(vertex_info.shader);
		if texture_mismatch do set_texture(vertex_info.texture);
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

		vertex := Vertex_Type{vertex_info.rendermode(vertex_info.position), vertex_info.tex_coord, vertex_info.color};
		append(&queued_for_drawing, vertex);
	}

	_draw_flush(mode);
}

_draw_flush :: proc(mode : u32 = odingl.TRIANGLES, loc := #caller_location) {
	if len(queued_for_drawing) == 0 {
		return;
	}

	bind_buffer(vbo);

	// TODO: investigate STATIC_DRAW vs others
	odingl.BufferData(odingl.ARRAY_BUFFER, size_of(Vertex_Type) * len(queued_for_drawing), &queued_for_drawing[0], odingl.STREAM_DRAW);

	program := get_current_shader();
	uniform(program, "atlas_texture", 0);

	odingl.DrawArrays(mode, 0, cast(i32)len(queued_for_drawing));

	clear(&queued_for_drawing);
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
debug_lines:    [dynamic]Line_Segment;

draw_debug_line :: inline proc(rendermode: Rendermode_Proc, a, b: Vec3, color: Colorf) {
	append(&debug_lines, Line_Segment{a, b, color, rendermode});
}

draw_debug_box :: proc[draw_debug_box_min_max, draw_debug_box_points];
draw_debug_box_min_max :: inline proc(rendermode: Rendermode_Proc, min, max: Vec3, color: Colorf) {
	draw_debug_line(rendermode, Vec3{min.x, min.y, min.z}, Vec3{min.x, max.y, max.z}, color);
	draw_debug_line(rendermode, Vec3{min.x, max.y, max.z}, Vec3{max.x, max.y, max.z}, color);
	draw_debug_line(rendermode, Vec3{max.x, max.y, max.z}, Vec3{max.x, min.y, min.z}, color);
	draw_debug_line(rendermode, Vec3{max.x, min.y, min.z}, Vec3{min.x, min.y, min.z}, color);
}
draw_debug_box_points :: inline proc(rendermode: Rendermode_Proc, a, b, c, d: Vec3, color: Colorf) {
	draw_debug_line(rendermode, a, b, color);
	draw_debug_line(rendermode, b, c, color);
	draw_debug_line(rendermode, c, d, color);
	draw_debug_line(rendermode, d, a, color);
}

_debug_on_after_render :: inline proc() {
	_draw_flush();

	// kinda weird, kinda neat
	old_vertices := buffered_vertices;
	buffered_vertices = debug_vertices;

	for line in debug_lines {
		push_vertex(line.rendermode, shader_rgba, 0, line.a, Vec2{}, line.color);
		push_vertex(line.rendermode, shader_rgba, 0, line.b, Vec2{}, line.color);
	}

	draw_buffered_vertices(odingl.LINES, buffered_vertices);

	debug_vertices = buffered_vertices;
	buffered_vertices = old_vertices;
}