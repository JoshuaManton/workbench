package workbench

using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"

      import        "platform"
      import        "gpu"
using import        "math"
using import        "types"
using import        "logging"

      import        "external/stb"
      import        "external/glfw"
      import        "external/imgui"

      import pf     "profiler"

//
// API
//

im_quad :: inline proc(
	rendermode: Rendermode_Proc,
	shader: gpu.Shader_Program,
	min, max: Vec2,
	color: Colorf,
	texture: Texture, // note(josh): can be empty
	auto_cast render_order: int = current_render_layer) {

		cmd := Draw_Command{
			render_order = render_order,
			serial_number = len(buffered_draw_commands),
			rendermode = rendermode,
			shader = shader,
			texture = texture,
			scissor = do_scissor,
			scissor_rect = current_scissor_rect,

			kind = Draw_Quad_Command {
				min = min,
				max = max,
				color = color,
			},
		};

		append(&buffered_draw_commands, cmd);
}
im_quad_pos :: inline proc(
	rendermode: Rendermode_Proc,
	shader: gpu.Shader_Program,
	pos, size: Vec2,
	color: Colorf,
	texture: Texture, // note(josh): can be empty
	auto_cast render_order: int = current_render_layer) {

		im_quad(rendermode, shader, pos-(size*0.5), pos+(size*0.5), color, texture, render_order);
}

im_sprite :: inline proc(
	rendermode: Rendermode_Proc,
	shader: gpu.Shader_Program,
	position, scale: Vec2,
	sprite: Sprite,
	color := Colorf{1, 1, 1, 1},
	pivot := Vec2{0.5, 0.5},
	auto_cast render_order: int = current_render_layer) {

		size := (Vec2{sprite.width, sprite.height} * scale);
		min := position;
		max := min + size;
		min -= size * pivot;
		max -= size * pivot;

		im_sprite_minmax(rendermode, shader, min, max, sprite, color, render_order);
}
im_sprite_minmax :: inline proc(
	rendermode: Rendermode_Proc,
	shader: gpu.Shader_Program,
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
			scissor_rect = current_scissor_rect,

			kind = Draw_Sprite_Command{
				min = min,
				max = max,
				color = color,
				uvs = sprite.uvs,
			},
		};

		append(&buffered_draw_commands, cmd);
}

im_text :: proc(
	rendermode: Rendermode_Proc,
	font: Font,
	str: string,
	position: Vec2,
	color: Colorf,
	size: f32,
	layer: int,
	actually_draw: bool = true,
	loc := #caller_location) -> f32 {

		// todo: make push_text() be render_mode agnostic
		// old := current_render_mode;
		// rendering_unit_space();
		// defer old();

		position := position;

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

				ww := cast(f32)platform.current_window_width;
				hh := cast(f32)platform.current_window_height;
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
				sprite = Sprite{{uv0, uv1, uv2, uv3}, 0, 0, font.texture};
			}

			if !is_space && actually_draw {
				im_sprite_minmax(rendermode, wb_catalog.shaders["text"], min, max, sprite, color, layer);
			}

			width := max.x - min.x;
			position.x += width + (width * whitespace_ratio);
		}

		width := position.x - start.x;
		return width;
}

get_string_width :: inline proc(
	rendermode: Rendermode_Proc,
	font: Font,
	str: string,
	size: f32) -> f32 {

		return im_text(rendermode, font, str, {}, {}, size, 0, false);
}



// Camera utilities

@(deferred_out=im_pop_camera)
IM_PUSH_CAMERA :: proc(camera: ^Camera) -> ^Camera {
	return push_camera_non_deferred(camera);
}

@private
im_pop_camera :: proc(old_camera: ^Camera) {
	im_flush();
	pop_camera(old_camera);
}



// Render layers

@(deferred_out=pop_render_layer)
PUSH_RENDER_LAYER :: proc(auto_cast layer: int) -> int {
	tmp := current_render_layer;
	current_render_layer = layer;
	return tmp;
}

@private
pop_render_layer :: proc(layer: int) {
	current_render_layer = layer;
}



// Scissor

im_scissor :: proc(x1, y1, ww, hh: int) {
	if do_scissor do logln("You are nesting scissors. I don't know if this is a problem, if it's not you can delete this log");
	do_scissor = true;
	current_scissor_rect = {x1, y1, ww, hh};
}

im_scissor_end :: proc() {
	assert(do_scissor);
	do_scissor = false;
	current_scissor_rect = {0, 0, cast(int)(platform.current_window_width+0.5), cast(int)(platform.current_window_height+0.5)};
}



//
// Internal
//

_internal_im_model: Model;
buffered_draw_commands: [dynamic]Draw_Command;

do_scissor: bool;
current_scissor_rect: [4]int;

current_render_layer: int;

im_flush :: proc() {
	pf.TIMED_SECTION(&wb_profiler);

	if buffered_draw_commands == nil do return;
	if len(buffered_draw_commands) == 0 do return;

	defer clear(&buffered_draw_commands);


	sort.quick_sort_proc(buffered_draw_commands[:], proc(a, b: Draw_Command) -> int {
			diff := a.render_order - b.render_order;
			if diff != 0 do return diff;
			return a.serial_number - b.serial_number;
		});

	@static im_queued_for_drawing: [dynamic]Vertex2D;

	current_rendermode : Rendermode_Proc = nil;
	is_scissor := false;
	current_shader := gpu.Shader_Program(0);
	current_texture: Texture;

	command_loop:
	for cmd in buffered_draw_commands {
		shader_mismatch     := cmd.shader         != current_shader;
		texture_mismatch    := cmd.texture.gpu_id != current_texture.gpu_id;
		scissor_mismatch    := cmd.scissor        != is_scissor;
		rendermode_mismatch := cmd.rendermode     != current_rendermode;
		if shader_mismatch || texture_mismatch || scissor_mismatch || rendermode_mismatch {
			draw_vertex_list(im_queued_for_drawing[:], current_shader, current_texture);
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
				gpu.scissor(cmd.scissor_rect);
			}
			else {
				gpu.unscissor(platform.current_window_width, platform.current_window_height);
			}
		}

		#complete
		switch kind in cmd.kind {
			case Draw_Quad_Command: {
				// weird order because of backface culling
				p1, p2, p3, p4 := kind.min, Vec2{kind.max.x, kind.min.y}, kind.max, Vec2{kind.min.x, kind.max.y};

				v1 := Vertex2D{p1, {0, 1}, kind.color};
				v2 := Vertex2D{p2, {1, 1}, kind.color};
				v3 := Vertex2D{p3, {1, 0}, kind.color};
				v4 := Vertex2D{p3, {1, 0}, kind.color};
				v5 := Vertex2D{p4, {0, 0}, kind.color};
				v6 := Vertex2D{p1, {0, 1}, kind.color};

				append(&im_queued_for_drawing, v1, v2, v3, v4, v5, v6);
			}
			case Draw_Sprite_Command: {
				// weird order because of backface culling
				p1, p2, p3, p4 := kind.min, Vec2{kind.max.x, kind.min.y}, kind.max, Vec2{kind.min.x, kind.max.y};

				v1 := Vertex2D{p1, kind.uvs[0], kind.color};
				v2 := Vertex2D{p2, kind.uvs[1], kind.color};
				v3 := Vertex2D{p3, kind.uvs[2], kind.color};
				v4 := Vertex2D{p3, kind.uvs[2], kind.color};
				v5 := Vertex2D{p4, kind.uvs[3], kind.color};
				v6 := Vertex2D{p1, kind.uvs[0], kind.color};

				append(&im_queued_for_drawing, v1, v2, v3, v4, v5, v6);
			}
			case Draw_Texture_Command: {
				unimplemented();
			}
			case: panic(tprint("unhandled case: ", kind));
		}
	}

	if len(im_queued_for_drawing) > 0 {
		draw_vertex_list(im_queued_for_drawing[:], current_shader, current_texture);
		clear(&im_queued_for_drawing);
	}
}

draw_vertex_list :: proc(list: []Vertex2D, shader: gpu.Shader_Program, texture: Texture, loc := #caller_location) {
	if len(list) == 0 {
		return;
	}

	update_mesh(&_internal_im_model, 0, list, []u32{});
	gpu.use_program(shader);
	draw_model(_internal_im_model, Vec3{}, Vec3{1, 1, 1}, Quat{0, 0, 0, 1}, texture, COLOR_WHITE, false, {}, loc);
}

Draw_Command :: struct {
	render_order:  int,
	serial_number: int,

	rendermode:   Rendermode_Proc,
	shader:       gpu.Shader_Program,
	texture:      Texture,
	scissor:      bool,
	scissor_rect: [4]int,

	kind: union {
		Draw_Quad_Command,
		Draw_Texture_Command,
		Draw_Sprite_Command,
	},

}
Draw_Quad_Command :: struct {
	min, max: Vec2,
	color: Colorf,
}
Draw_Texture_Command :: struct {
	position: Vec2,
	scale: Vec2,
	color: Colorf,
}
Draw_Sprite_Command :: struct {
	min, max: Vec2,
	color: Colorf,
	uvs: [4]Vec2,
}



// Debug

// todo(josh): support all rendermodes for debug lines, right now we force rendermode_world
draw_debug_line :: proc(a, b: Vec3, color: Colorf) {
	append(&debug_lines, Debug_Line{a, b, color, {0, 0, 0, 1}});
}

draw_debug_box :: proc(position, scale: Vec3, color: Colorf, rotation := Quat{0, 0, 0, 1}) {
	append(&debug_cubes, Debug_Cube{position, scale, rotation, color});
}

debug_geo_flush :: proc() {
	old_polygon_mode := current_camera.polygon_mode;
	defer current_camera.polygon_mode = old_polygon_mode;
	current_camera.polygon_mode = .Line;

	// todo(josh): support all rendermodes
	rendermode_world();

	gpu.use_program(wb_catalog.shaders["default"]);
	for line in debug_lines {
		verts: [2]Vertex3D;
		verts[0] = Vertex3D{line.a, {}, line.color, {}, {}, {}};
		verts[1] = Vertex3D{line.b, {}, line.color, {}, {}, {}};
		update_mesh(&debug_line_model, 0, verts[:], []u32{});
		draw_model(debug_line_model, {}, {1, 1, 1}, {0, 0, 0, 1}, {}, {1, 1, 1, 1}, false);
	}

	for cube in debug_cubes {
		draw_model(wb_cube_model, cube.position, cube.scale, cube.rotation, {}, cube.color, true);
	}
}



Debug_Line :: struct {
	a, b: Vec3,
	color: Colorf,
	rotation: Quat,
}
Debug_Cube :: struct {
	position: Vec3,
	scale: Vec3,
	rotation: Quat,
	color: Colorf,
}