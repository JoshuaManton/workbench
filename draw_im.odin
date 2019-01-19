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

      import pf     "profiler"

buffered_draw_commands: [dynamic]Draw_Command;
push_quad :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, min, max: Vec2, color: Colorf, auto_cast render_order: int = current_render_layer) {
	cmd := Draw_Command{
		render_order = render_order,
		serial_number = len(buffered_draw_commands),
		rendermode = rendermode,
		shader = shader,
		texture = {},
		scissor = do_scissor,
		scissor_rect = scissor_rect1,

		derived = Draw_Quad_Command {
			min = min,
			max = max,
			color = color,
		},
	};

	append(&buffered_draw_commands, cmd);
}

push_sprite :: inline proc(rendermode: Rendermode_Proc, shader: Shader_Program, position, scale: Vec2, sprite: Sprite, color := Colorf{1, 1, 1, 1}, pivot := Vec2{0.5, 0.5}, auto_cast render_order: int = current_render_layer) {
	size := (Vec2{sprite.width, sprite.height} * scale);
	min := position;
	max := min + size;
	min -= size * pivot;
	max -= size * pivot;

	push_sprite_minmax(rendermode, shader, min, max, sprite, color, render_order);
}

push_sprite_minmax :: inline proc(
	rendermode: Rendermode_Proc,
	shader: Shader_Program,
	min, max: Vec2,
	sprite: Sprite,
	color := Colorf{1, 1, 1, 1},
	auto_cast render_order: int = current_render_layer) {

		cmd := Draw_Command{
			render_order = render_order,
			serial_number = len(buffered_draw_commands),
			rendermode = rendermode,
			shader = shader,
			texture = sprite.id,
			scissor = do_scissor,
			scissor_rect = scissor_rect1,

			derived = Draw_Sprite_Command{
				min = min,
				max = max,
				color = color,
				uvs = sprite.uvs,
			},
		};

		append(&buffered_draw_commands, cmd);
}

push_mesh :: inline proc(
	id: MeshID,
	position: Vec3,
	scale: Vec3,
	rotation: Vec3,
	texture: Texture,
	shader: Shader_Program,
	color: Colorf,
	auto_cast render_order: int = current_render_layer) {

		cmd := Draw_Command{
			render_order = render_order,
			serial_number = len(buffered_draw_commands),
			rendermode = rendermode_world,
			shader = shader,
			texture = texture,
			scissor = do_scissor,
			scissor_rect = scissor_rect1,

			derived = Draw_Mesh_Command{
				mesh_id = id,
				position = position,
				scale = scale,
				rotation = rotation,
				color = color,
			},
		};

		append(&buffered_draw_commands, cmd);
		// append(&im_buffered_meshes, Buffered_Mesh{id, position, scale, rotation, texture, shader, color});
}

// im_cube :: inline proc(position: Vec3, scale: f32) {
// 	vertex_positions := [?]Vec3 {
// 		{-0.5,-0.5,-0.5}, {-0.5,-0.5, 0.5}, {-0.5, 0.5, 0.5},
// 	    {0.5, 0.5,-0.5}, {-0.5,-0.5,-0.5}, {-0.5, 0.5,-0.5},
// 	    {0.5,-0.5, 0.5}, {-0.5,-0.5,-0.5}, {0.5,-0.5,-0.5},
// 	    {0.5, 0.5,-0.5}, {0.5,-0.5,-0.5}, {-0.5,-0.5,-0.5},
// 	    {-0.5,-0.5,-0.5}, {-0.5, 0.5, 0.5}, {-0.5, 0.5,-0.5},
// 	    {0.5,-0.5, 0.5}, {-0.5,-0.5, 0.5}, {-0.5,-0.5,-0.5},
// 	    {-0.5, 0.5, 0.5}, {-0.5,-0.5, 0.5}, {0.5,-0.5, 0.5},
// 	    {0.5, 0.5, 0.5}, {0.5,-0.5,-0.5}, {0.5, 0.5,-0.5},
// 	    {0.5,-0.5,-0.5}, {0.5, 0.5, 0.5}, {0.5,-0.5, 0.5},
// 	    {0.5, 0.5, 0.5}, {0.5, 0.5,-0.5}, {-0.5, 0.5,-0.5},
// 	    {0.5, 0.5, 0.5}, {-0.5, 0.5,-0.5}, {-0.5, 0.5, 0.5},
// 	    {0.5, 0.5, 0.5}, {-0.5, 0.5, 0.5}, {0.5,-0.5, 0.5},
// 	};
// 	for p, i in vertex_positions {
// 		t := cast(f32)i / len(vertex_positions);
// 		im_vertex(rendermode_world, shader_rgba_3d, position + p * scale, Colorf{t, 0, 0, 1});
// 	}
// }

push_text :: proc(rendermode: Rendermode_Proc, font: ^Font, str: string, position: Vec2, color: Colorf, size: f32, layer: int, actually_draw: bool = true) -> f32 {
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
			push_sprite_minmax(rendermode, shader_text, min, max, sprite, color, layer);
		}

		width := max.x - min.x;
		position.x += width + (width * whitespace_ratio);
	}

	width := position.x - start.x;
	return width;
}

get_string_width :: inline proc(rendermode: Rendermode_Proc, font: ^Font, str: string, size: f32) -> f32 {
	return push_text(rendermode, font, str, {}, {}, size, 0, false);
}

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
// Render layers
//

current_render_layer: int;

@(deferred_out=_POP_RENDER_LAYER)
PUSH_RENDER_LAYER :: proc(auto_cast layer: int) -> int {
	tmp := current_render_layer;
	current_render_layer = layer;
	return tmp;
}

_POP_RENDER_LAYER :: proc(layer: int) {
	current_render_layer = layer;
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


im_draw_flush :: proc(mode: u32, cmds: []Draw_Command) {
	pf.TIMED_SECTION(&wb_profiler);

	static im_queued_for_drawing: [dynamic]Vertex2D;

	if !current_camera.is_perspective {
		sort.quick_sort_proc(cmds[:], proc(a, b: Draw_Command) -> int {
				diff := a.render_order - b.render_order;
				if diff != 0 do return diff;
				return a.serial_number - b.serial_number;
			});
	}

	model_matrix = identity(Mat4);

	current_rendermode : Rendermode_Proc = nil;
	is_scissor := false;
	current_shader := Shader_Program(0);
	current_texture := Texture(0);

	for cmd in cmds {
		shader_mismatch     := cmd.shader     != current_shader;
		texture_mismatch    := cmd.texture    != current_texture;
		scissor_mismatch    := cmd.scissor    != is_scissor;
		rendermode_mismatch := cmd.rendermode != current_rendermode;
		if shader_mismatch || texture_mismatch || scissor_mismatch || rendermode_mismatch {
			draw_vertex_list(im_queued_for_drawing[:], current_shader, current_texture, mode);
			clear(&im_queued_for_drawing);
		}

		if shader_mismatch     do current_shader  = cmd.shader;
		if texture_mismatch    do current_texture = cmd.texture;
		if rendermode_mismatch {
			current_rendermode = cmd.rendermode;
			cmd.rendermode();
		}

		if scissor_mismatch {
			is_scissor = cmd.scissor;
			if is_scissor {
				odingl.Enable(odingl.SCISSOR_TEST);
				odingl.Scissor(cmd.scissor_rect[0], cmd.scissor_rect[1], cmd.scissor_rect[2], cmd.scissor_rect[3]);
			}
			else {
				odingl.Disable(odingl.SCISSOR_TEST);
				odingl.Scissor(0, 0, current_window_width, current_window_height);
			}
		}

		#complete
		switch kind in cmd.derived {
			case Draw_Quad_Command: {
				p1, p2, p3, p4 := kind.min, Vec2{kind.min.x, kind.max.y}, kind.max, Vec2{kind.max.x, kind.min.y};

				v1 := Vertex2D{p1, {}, kind.color};
				v2 := Vertex2D{p2, {}, kind.color};
				v3 := Vertex2D{p3, {}, kind.color};
				v4 := Vertex2D{p3, {}, kind.color};
				v5 := Vertex2D{p4, {}, kind.color};
				v6 := Vertex2D{p1, {}, kind.color};

				append(&im_queued_for_drawing, v1, v2, v3, v4, v5, v6);
			}

			case Draw_Sprite_Command: {
				p1, p2, p3, p4 := kind.min, Vec2{kind.min.x, kind.max.y}, kind.max, Vec2{kind.max.x, kind.min.y};

				v1 := Vertex2D{p1, kind.uvs[0], kind.color};
				v2 := Vertex2D{p2, kind.uvs[1], kind.color};
				v3 := Vertex2D{p3, kind.uvs[2], kind.color};
				v4 := Vertex2D{p3, kind.uvs[2], kind.color};
				v5 := Vertex2D{p4, kind.uvs[3], kind.color};
				v6 := Vertex2D{p1, kind.uvs[0], kind.color};

				append(&im_queued_for_drawing, v1, v2, v3, v4, v5, v6);
			}

			case Draw_Mesh_Command: {
				// todo(josh): batching of meshes, right now it's a draw call per mesh

				mesh, ok := all_meshes[kind.mesh_id];
				if !ok {
					logln("Mesh was not loaded: ", kind.mesh_id);
				}
				else {
					model_matrix_from_elements(kind.position, kind.scale, kind.rotation);
					rendermode_world();

					when DEVELOPER {
						if debugging_rendering_max_draw_calls != -1 && num_draw_calls >= debugging_rendering_max_draw_calls {
							num_draw_calls += 1;
							return;
						}
					}

					bind_vao(mesh.vertex_array);
					bind_buffer(mesh.vertex_buffer);
					bind_buffer(mesh.index_buffer);
					use_program(cmd.shader);
					bind_texture2d(cmd.texture);

					program := get_current_shader();

					uniform4f(program, "mesh_color", kind.color.r, kind.color.g, kind.color.b, kind.color.a);
					uniform_matrix4fv(program, "mvp_matrix", 1, false, &mvp_matrix[0][0]);

					num_draw_calls += 1;

					if debugging_rendering {
						odingl.DrawElements(odingl.LINES, i32(mesh.index_count), odingl.UNSIGNED_INT, nil);
					}
					else {
						odingl.DrawElements(odingl.TRIANGLES, i32(mesh.index_count), odingl.UNSIGNED_INT, nil);
					}
				}
			}
			case: panic(tprint("unhandled case: ", kind));
		}
	}

	if len(im_queued_for_drawing) > 0 {
		draw_vertex_list(im_queued_for_drawing[:], current_shader, current_texture, mode);
		clear(&im_queued_for_drawing);
	}
}



debugging_rendering: bool;
debugging_rendering_max_draw_calls : i32 = -1; // note(josh): i32 because my dear-imgui stuff wasn't working with int
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
				// push_debug_vertex(current_rendermode, vert.position, COLOR_GREEN);
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