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

rendermode_world :: proc() {
	if current_camera.is_perspective {
		mvp_matrix = mul(mul(perspective_projection_matrix, current_camera.view_matrix), model_matrix);
	}
	else {
		mvp_matrix = orthographic_projection_matrix;
	}
}
rendermode_unit :: proc() {
	mvp_matrix = unit_to_viewport_matrix;
}
rendermode_pixel :: proc() {
	mvp_matrix = pixel_to_viewport_matrix;
}

//
// Immediate-mode rendering
//

im_quad :: proc{im_quad_color, im_quad_sprite, im_quad_sprite_color};

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

im_vertex :: proc{im_vertex_color, im_vertex_color_texture};
im_vertex_color :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, position: Vec3, color: Colorf, auto_cast render_order: int = current_render_layer) {
	im_vertex_color_texture(rendermode, shader, 0, position, Vec2{}, color, render_order);
}

im_vertex_color_texture :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, texture: Texture, position: Vec3, tex_coord: Vec2, color: Colorf, auto_cast render_order: int = current_render_layer) {
	assert(shader != 0);
	serial := len(im_buffered_verts);
	vertex_info := Buffered_Vertex{render_order, serial, position, tex_coord, color, rendermode, shader, texture, do_scissor, scissor_rect1};
	append(&im_buffered_verts, vertex_info);
}

im_text :: proc(rendermode: Rendermode_Proc, font: ^Font, str: string, position: Vec2, color: Colorf, size: f32, layer: int, actually_draw: bool = true) -> f32 {
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

		if !is_space && actually_draw {
			im_quad_sprite_color(rendermode, shader_text, to_vec3(min), to_vec3(max), sprite, color, layer);
		}

		width := max.x - min.x;
		position.x += width + (width * whitespace_ratio);
	}

	width := position.x - start.x;
	return width;
}

get_string_width :: inline proc(rendermode: Rendermode_Proc, font: ^Font, str: string, size: f32) -> f32 {
	return im_text(rendermode, font, str, {}, {}, size, 0, false);
}

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

do_scissor: bool;
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

im_buffered_verts:     [dynamic]Buffered_Vertex;
im_queued_for_drawing: [dynamic]Vertex2D;

current_rendermode: Rendermode_Proc;

im_draw_flush :: proc(mode: u32, verts: []Buffered_Vertex) {
	if !current_camera.is_perspective {
		sort.quick_sort_proc(verts[:], proc(a, b: Buffered_Vertex) -> int {
				diff := a.render_order - b.render_order;
				if diff != 0 do return diff;
				return a.serial_number - b.serial_number;
			});
	}

	model_matrix = identity(Mat4);

	current_rendermode = nil;
	is_scissor := false;
	current_shader := Shader_Program(0);
	current_texture := Texture(0);

	for vertex_info in verts {
		shader_mismatch     := vertex_info.shader     != current_shader;
		texture_mismatch    := vertex_info.texture    != current_texture;
		scissor_mismatch    := vertex_info.scissor    != is_scissor;
		rendermode_mismatch := vertex_info.rendermode != current_rendermode;
		if shader_mismatch || texture_mismatch || scissor_mismatch || rendermode_mismatch {
			draw_vertex_list(im_queued_for_drawing[:], current_shader, current_texture, mode);
			clear(&im_queued_for_drawing);
		}

		if shader_mismatch     do current_shader  = vertex_info.shader;
		if texture_mismatch    do current_texture = vertex_info.texture;
		if rendermode_mismatch {
			current_rendermode = vertex_info.rendermode;
			vertex_info.rendermode();
		}

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

	draw_vertex_list(im_queued_for_drawing[:], current_shader, current_texture, mode);
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

draw_vertex_list :: proc(list: []$Vertex_Type, shader: Shader_Program, texture: Texture, mode: u32, loc := #caller_location) {
	if len(list) == 0 {
		return;
	}

	when DEVELOPER {
		if debugging_rendering_max_draw_calls != -1 && num_draw_calls >= debugging_rendering_max_draw_calls {
			num_draw_calls += 1;
			return;
		}
	}

	use_program(shader);
	bind_texture2d(texture);

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

	depth_test := odingl.IsEnabled(odingl.DEPTH_TEST);
	odingl.Disable(odingl.DEPTH_TEST);
	defer if depth_test == odingl.TRUE {
		odingl.Enable(odingl.DEPTH_TEST);
	}

	// TODO: investigate STATIC_DRAW vs others
	buffer_vertices(list);
	odingl.BufferData(odingl.ARRAY_BUFFER, size_of(Vertex_Type) * len(list), &list[0], odingl.STATIC_DRAW);

	program := get_current_shader();
	uniform_matrix4fv(program, "mvp_matrix", 1, false, &mvp_matrix[0][0]);

	num_draw_calls += 1;

	odingl.DrawArrays(mode, 0, cast(i32)len(list));
}