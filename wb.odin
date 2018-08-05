package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"
      import coregl "core:opengl"

      import odingl "shared:odin-gl"

      import stb    "shared:workbench/stb"
      import        "shared:workbench/glfw"

DEVELOPER :: true;

pixel_to_world_matrix: Mat4;

ortho_matrix:     Mat4;
transform_matrix: Mat4;
pixel_matrix:     Mat4;

main_window: glfw.Window_Handle;

camera_size: f32 = 1;
camera_position: Vec2;
camera_rotation: f32;



current_window_width:  int;
_new_window_width:  int;

current_window_height: int;
_new_window_height: int;

current_aspect_ratio:  f32;
_new_aspect_ratio:  f32;



cursor_scroll: f32;
_new_cursor_scroll: f32;

cursor_world_position:       Vec2;
cursor_screen_position:      Vec2;
cursor_unit_position:        Vec2;
_new_cursor_screen_position: Vec2;

Render_Mode_Proc :: #type proc();

rendering_world_space :: inline proc() {
	current_render_mode = rendering_world_space;

	transform_matrix = mul(identity(Mat4), ortho_matrix);
	transform_matrix = scale(transform_matrix, 1.0 / camera_size);

	cam_offset := to_vec3(mul(transform_matrix, to_vec4(camera_position)));
	transform_matrix = translate(transform_matrix, -cam_offset);

	pixel_matrix = identity(Mat4);
	pixel_matrix = scale(pixel_matrix, 1.0 / PIXELS_PER_WORLD_UNIT);
}

rendering_unit_space :: inline proc() {
	current_render_mode = rendering_unit_space;

	transform_matrix = identity(Mat4);
	transform_matrix = translate(transform_matrix, Vec3{-1, -1, 0});
	transform_matrix = scale(transform_matrix, 2);

	pixel_matrix = identity(Mat4);
	pixel_matrix = scale(pixel_matrix, Vec3{cast(f32)current_window_width, cast(f32)current_window_height, 0});
}

rendering_pixel_space :: inline proc() {
	current_render_mode = rendering_pixel_space;

	transform_matrix = identity(Mat4);
	transform_matrix = scale(transform_matrix, to_vec3(Vec2{1.0 / cast(f32)current_window_width, 1.0 / cast(f32)current_window_height}));
	transform_matrix = translate(transform_matrix, Vec3{-1, -1, 0});
	transform_matrix = scale(transform_matrix, 2);

	pixel_matrix = identity(Mat4);
}

relative_to_pixel :: inline proc(a: Vec2) -> Vec2 {
	return to_vec2(mul(pixel_matrix, to_vec4(a)));
}

set_shader :: inline proc(program: Shader_Program, location := #caller_location) {
	draw_flush();

	current_shader = program;
	use_program(program);
}

set_texture :: inline proc(texture: Texture, location := #caller_location) {
	draw_flush();

	current_texture = texture;
	bind_texture2d(texture);
}

// glfw wrapper
window_should_close :: inline proc(window: glfw.Window_Handle) -> bool {
	return glfw.WindowShouldClose(window);
}

screen_to_world :: proc(screen: Vec2) -> Vec2 {
	// convert to unit size first
	pos := Vec2{screen.x / cast(f32)current_window_width, screen.y / cast(f32)current_window_height};

	// assume the incoming `screen` parameter is bottom left == 0, 0
	// pos.y = 1.0 - pos.y;

	camera_size_x := camera_size * current_aspect_ratio;
	camera_size_y := camera_size;

	pos.x *= camera_size_x * 2.0;
	pos.y *= camera_size_y * 2.0;

	pos.x -= camera_size_x;
	pos.y -= camera_size_y;

	pos += camera_position;

	return pos;
}

init_glfw :: proc(window_name: string, window_width, window_height: i32, opengl_version_major, opengl_version_minor: i32) {
	glfw_size_callback :: proc"c"(main_window: glfw.Window_Handle, w, h: i32) {
		_new_window_width  = cast(int)w;
		_new_window_height = cast(int)h;
		_new_aspect_ratio = cast(f32)w / cast(f32)h;

		top    : f32 =  1;
		bottom : f32 = -1;
		left   : f32 = -1 * _new_aspect_ratio;
		right  : f32 =  1 * _new_aspect_ratio;

		ortho_matrix = ortho3d(left, right, bottom, top, -1, 1);
	}

	glfw_cursor_callback :: proc"c"(main_window: glfw.Window_Handle, x, y: f64) {
		_new_cursor_screen_position = Vec2{cast(f32)x, cast(f32)current_window_height - cast(f32)y};
	}

	glfw_scroll_callback :: proc"c"(main_window: glfw.Window_Handle, x, y: f64) {
		_new_cursor_scroll = cast(f32)y;
	}

	glfw_error_callback :: proc"c"(error: i32, desc: cstring) {
		fmt.printf("Error code %d:\n    %s\n", error, cast(string)cast(cstring)desc);
	}

	// setup glfw
	glfw.SetErrorCallback(glfw_error_callback);

	if glfw.Init() == 0 do return;
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, opengl_version_major);
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, opengl_version_minor);
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
	main_window = glfw.CreateWindow(window_width, window_height, window_name, nil, nil);
	if main_window == nil do return;

	video_mode := glfw.GetVideoMode(glfw.GetPrimaryMonitor());
	glfw.SetWindowPos(main_window, video_mode.width / 2 - window_width / 2, video_mode.height / 2 - window_height / 2);

	glfw.MakeContextCurrent(main_window);
	glfw.SwapInterval(1);

	glfw.SetCursorPosCallback(main_window, glfw_cursor_callback);
	glfw.SetWindowSizeCallback(main_window, glfw_size_callback);

	glfw.SetKeyCallback(main_window, _glfw_key_callback);
	glfw.SetMouseButtonCallback(main_window, _glfw_mouse_button_callback);

	// :GlfwJoystickPollEventsCrash
	// this is crashing when I call PollEvents when I unplug a controller for some reason
	// glfw.SetJoystickCallback(main_window, _glfw_joystick_callback);

	// setup opengl
	odingl.load_up_to(cast(int)opengl_version_major, cast(int)opengl_version_minor,
		proc(p: rawptr, name: cstring) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name));
		});

	// Set initial size of window
	glfw_size_callback(main_window, window_width, window_height);

	// Setup glfw callbacks
	glfw.SetScrollCallback(main_window, glfw_scroll_callback);
}

vao: VAO;
vbo: VBO;

shader_rgba:    Shader_Program;
shader_text:    Shader_Program;
shader_texture: Shader_Program;

init_opengl :: proc() {
	vao = gen_vao();
	bind_vao(vao);

	vbo = gen_buffer();
	bind_buffer(vbo);

	set_vertex_format(Vertex_Type);

	odingl.ClearColor(0.2, 0.5, 0.8, 1.0);
	odingl.Enable(coregl.BLEND);
	odingl.BlendFunc(coregl.SRC_ALPHA, coregl.ONE_MINUS_SRC_ALPHA);

	ok: bool;
	shader_rgba, ok    = load_shader_text(SHADER_RGBA_VERT, SHADER_RGBA_FRAG);
	assert(ok);
	shader_texture, ok = load_shader_text(SHADER_TEXTURE_VERT, SHADER_TEXTURE_FRAG);
	assert(ok);
	shader_text, ok    = load_shader_text(SHADER_TEXT_VERT, SHADER_TEXT_FRAG);
	assert(ok);
}

Buffered_Vertex :: struct {
	render_order:  int,
	serial_number: int,
	render_mode_proc: Render_Mode_Proc,
	shader: Shader_Program,
	texture: Texture,
	position: Vec2,
	tex_coord: Vec2,
	color: Colorf,
}

buffered_vertices:   [dynamic]Buffered_Vertex;
debug_vertices:      [dynamic]Buffered_Vertex;
queued_for_drawing:  [dynamic]Vertex_Type;
debug_lines:         [dynamic]Line_Segment;

Vertex_Type :: struct {
	vertex_position: Vec2,
	tex_coord: Vec2,
	color: Colorf,
}

Sprite :: struct {
	uvs: [4]Vec2,
	width: f32,
	height: f32,
	id: Texture,
}

COLOR_WHITE := Colorf{1, 1, 1, 1};
COLOR_RED   := Colorf{1, 0, 0, 1};
COLOR_GREEN := Colorf{0, 1, 0, 1};
COLOR_BLUE  := Colorf{0, 0, 1, 1};
COLOR_BLACK := Colorf{0, 0, 0, 1};

current_render_mode: Render_Mode_Proc;
current_shader:      Shader_Program;
current_texture:     Texture;

push_quad :: proc[push_quad_min_max_color, push_quad_min_max_sprite, push_quad_min_max_sprite_color,
                  push_quad_points_color,  push_quad_points_sprite,  push_quad_points_sprite_color];

push_quad_min_max_color :: inline proc(shader: Shader_Program, min, max: Vec2, color: Colorf, render_order: int = 0) {
	_push_quad(shader, min, Vec2{min.x, max.y}, max, Vec2{max.x, min.y}, Sprite{}, color, render_order);
}
push_quad_min_max_sprite :: inline proc(shader: Shader_Program, min, max: Vec2, sprite: Sprite, render_order: int = 0) {
	_push_quad(shader, min, Vec2{min.x, max.y}, max, Vec2{max.x, min.y}, sprite, COLOR_WHITE, render_order);
}
push_quad_min_max_sprite_color :: inline proc(shader: Shader_Program, min, max: Vec2, sprite: Sprite, color: Colorf, render_order: int = 0) {
	_push_quad(shader, min, Vec2{min.x, max.y}, max, Vec2{max.x, min.y}, sprite, color, render_order);
}

push_quad_points_color :: inline proc(shader: Shader_Program, p0, p1, p2, p3: Vec2, color: Colorf, render_order: int = 0) {
	_push_quad(shader, p0, p1, p2, p3, Sprite{}, color, render_order);
}
push_quad_points_sprite :: inline proc(shader: Shader_Program, p0, p1, p2, p3: Vec2, sprite: Sprite, render_order: int = 0) {
	_push_quad(shader, p0, p1, p2, p3, sprite, COLOR_WHITE, render_order);
}
push_quad_points_sprite_color :: inline proc(shader: Shader_Program, p0, p1, p2, p3: Vec2, sprite: Sprite, color: Colorf, render_order: int = 0) {
	_push_quad(shader, p0, p1, p2, p3, sprite, color, render_order);
}

_push_quad :: inline proc(shader: Shader_Program, p0, p1, p2, p3: Vec2, sprite: Sprite, color: Colorf, render_order: int = 0) {
	push_vertex(shader, sprite.id, p0, sprite.uvs[0], color, render_order);
	push_vertex(shader, sprite.id, p1, sprite.uvs[1], color, render_order);
	push_vertex(shader, sprite.id, p2, sprite.uvs[2], color, render_order);
	push_vertex(shader, sprite.id, p2, sprite.uvs[2], color, render_order);
	push_vertex(shader, sprite.id, p3, sprite.uvs[3], color, render_order);
	push_vertex(shader, sprite.id, p0, sprite.uvs[0], color, render_order);

	if current_render_mode != rendering_pixel_space {
		p0 = to_vec2(mul(pixel_matrix, to_vec4(p0)));
		p1 = to_vec2(mul(pixel_matrix, to_vec4(p1)));
		p2 = to_vec2(mul(pixel_matrix, to_vec4(p2)));
		p3 = to_vec2(mul(pixel_matrix, to_vec4(p3)));
	}

	// draw_debug_line(p0, p1, COLOR_GREEN);
	// draw_debug_line(p1, p2, COLOR_GREEN);
	// draw_debug_line(p2, p1, COLOR_GREEN);
	// draw_debug_line(p2, p3, COLOR_GREEN);
	// draw_debug_line(p3, p0, COLOR_GREEN);
}

push_vertex :: inline proc(shader: Shader_Program, texture: Texture, position: Vec2, tex_coord: Vec2, color: Colorf, render_order: int = 0) {
	assert(shader != 0);
	assert(current_render_mode != nil, "Render mode isn't set yet.");
	serial := len(buffered_vertices);
	vertex_info := Buffered_Vertex{render_order, serial, current_render_mode, shader, texture, position, tex_coord, color};
	append(&buffered_vertices, vertex_info);
}

draw_buffered_vertex :: proc(vertex_info: Buffered_Vertex, mode: u32) {
	render_mode_mismatch := vertex_info.render_mode_proc != current_render_mode;
	shader_mismatch      := vertex_info.shader != current_shader;
	texture_mismatch     := vertex_info.texture != current_texture;
	if render_mode_mismatch || shader_mismatch || texture_mismatch {
		draw_flush();
	}

	if shader_mismatch  do set_shader(vertex_info.shader);
	if texture_mismatch do set_texture(vertex_info.texture);

	if render_mode_mismatch {
		current_render_mode = vertex_info.render_mode_proc;
		vertex_info.render_mode_proc();
	}

	vertex := Vertex_Type{vertex_info.position, vertex_info.tex_coord, vertex_info.color};
	append(&queued_for_drawing, vertex);
}

// get_string_width :: proc(font: ^Font, str: string, size: f32) -> f32 {
// 	size_ratio := _get_size_ratio_for_font(font, size);
// 	cur_pos: Vec2;
// 	for c in str {
// 		quad := stb.get_baked_quad(font.chars, font.dim, font.dim, cast(int)c, &cur_pos.x, &cur_pos.y, true);
// 		// char_width comes out as pixels, so we need to convert it to the current render mode
// 		if current_render_mode == rendering_pixel_space {
// 		}
// 		else if current_render_mode == rendering_unit_space {
// 			char_width = char_width / cast(f32)current_window_width * size_ratio;
// 		}
// 		else {
// 			assert(false);
// 		}

// 		cur_width += char_width;
// 	}

// 	return cur_width;
// }

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

draw_string :: proc(font: ^Font, str: string, position: Vec2, color: Colorf, size: f32, layer: int) -> f32 {
	// todo: make draw_string() be render_mode agnostic
	// old := current_render_mode;
	// rendering_unit_space();
	// defer old();

	assert(current_render_mode == rendering_unit_space);

	start := position;
	for c in str {
		min, max: Vec2;
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
				// full_to_char_width_aspect: f32;
				// {
				// 	char_aspect := abs(quad.s1 - quad.s0) / abs(quad.t1 - quad.t0);
				// 	full_width := size_pixels.x;
				// 	char_width := size_pixels.y * char_aspect;
				// 	full_to_char_width_aspect = char_width / full_width;
				// }

				// whitespace := (max.x - min.x) - ((max.x - min.x) * full_to_char_width_aspect);
				// min.x += whitespace / 2;
				// max.x -= whitespace / 2;
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

		push_quad(shader_text, min, max, sprite, color, layer);
		position.x += max.x - min.x;
	}

	width := position.x - start.x;
	return width;
}

Line_Segment :: struct {
	a, b: Vec2,
	color: Colorf,
}

log1: bool;
draw_debug_line :: inline proc(a, b: Vec2, color: Colorf) {
	append(&debug_lines, Line_Segment{a, b, color});
}

draw_debug_box :: proc[draw_debug_box_min_max, draw_debug_box_points];
draw_debug_box_min_max :: inline proc(min, max: Vec2, color: Colorf) {
	draw_debug_line(Vec2{min.x, min.y}, Vec2{min.x, max.y}, color);
	draw_debug_line(Vec2{min.x, max.y}, Vec2{max.x, max.y}, color);
	draw_debug_line(Vec2{max.x, max.y}, Vec2{max.x, min.y}, color);
	draw_debug_line(Vec2{max.x, min.y}, Vec2{min.x, min.y}, color);
}
draw_debug_box_points :: inline proc(a, b, c, d: Vec2, color: Colorf) {
	draw_debug_line(a, b, color);
	draw_debug_line(b, c, color);
	draw_debug_line(c, d, color);
	draw_debug_line(d, a, color);
}

flush_debug_lines :: inline proc() {
	// rendering_world_space();
	// rendering_pixel_space();
	rendering_unit_space();

	// kinda weird, kinda neat
	old_vertices := buffered_vertices;
	buffered_vertices = debug_vertices;
	defer buffered_vertices = old_vertices;

	for line in debug_lines {
		push_vertex(shader_rgba, 0, line.a, Vec2{}, line.color, 0);
		push_vertex(shader_rgba, 0, line.b, Vec2{}, line.color, 0);
	}

	draw_buffered_vertices(coregl.LINES);
	clear(&debug_lines);
}

draw_buffered_vertices :: proc(mode: u32) {
	for command in buffered_vertices {
		draw_buffered_vertex(command, mode);
	}

	draw_flush(mode);
}

draw_flush :: proc(mode : u32 = coregl.TRIANGLES, loc := #caller_location) {
	if len(queued_for_drawing) == 0 {
		return;
	}

	program := get_current_shader();
	uniform_matrix4fv(program, "transform", 1, false, &transform_matrix[0][0]);

	bind_buffer(vbo);

	// TODO: investigate STATIC_DRAW vs others
	odingl.BufferData(coregl.ARRAY_BUFFER, size_of(Vertex_Type) * len(queued_for_drawing), &queued_for_drawing[0], coregl.STATIC_DRAW);

	uniform(program, "atlas_texture", 0);

	odingl.DrawArrays(mode, 0, cast(i32)len(queued_for_drawing));

	clear(&queued_for_drawing);
}

//
// Game loop stuff
//

frame_count: u64;
time: f32;
last_delta_time: f32;
fps_to_draw: f32;

start_game_loop :: proc(update: proc(f32) -> bool, render: proc(f32), target_framerate: f32) {
	acc: f32;
	target_delta_time := 1 / target_framerate;

	game_loop:
	for !window_should_close(main_window) {
		frame_start := win32.time_get_time();

		last_time := time;
		time = cast(f32)glfw.GetTime();
		last_delta_time = time - last_time;

		acc += last_delta_time;
		old_frame_count := frame_count;
		update_tweeners(last_delta_time);

		for acc >= target_delta_time {
			frame_count += 1;
			acc -= target_delta_time;

			// Update vars from callbacks
			current_window_width   = _new_window_width;
			current_window_height  = _new_window_height;
			current_aspect_ratio   = _new_aspect_ratio;
			cursor_screen_position = _new_cursor_screen_position;
			cursor_unit_position   = cursor_screen_position / Vec2{cast(f32)current_window_width, cast(f32)current_window_height};
			cursor_world_position  = screen_to_world(cursor_screen_position);

			cursor_scroll          = _new_cursor_scroll;
			_new_cursor_scroll     = 0;

			clear(&buffered_vertices);
			update_input();
			if !update(target_delta_time) do break game_loop;
		}

		odingl.Viewport(0, 0, cast(i32)current_window_width, cast(i32)current_window_height);
		odingl.Clear(coregl.COLOR_BUFFER_BIT);

		render(target_delta_time);

		sort.quick_sort_proc(buffered_vertices[..], proc(a, b: Buffered_Vertex) -> int {
				diff := a.render_order - b.render_order;
				if diff != 0 do return diff;
				return a.serial_number - b.serial_number;
			});

		current_render_mode = nil;

		draw_buffered_vertices(coregl.TRIANGLES);

		flush_debug_lines();

		frame_end := win32.time_get_time();
		glfw.SwapBuffers(main_window);
		odingl.Finish();
		log_gl_errors("after SwapBuffers()");
	}
}

Font :: struct {
	dim: int,
	size: f32,
	chars: []stb.Baked_Char,
	id: Texture,
}

load_font :: proc(path: string, size: f32) -> (^Font, bool) {
	data, ok := os.read_entire_file(path);
	if !ok {
		logln("Couldn't open font: ", path);
		return nil, false;
	}
	defer delete(data);

	pixels: []u8;
	chars:  []stb.Baked_Char;
	dim := 128;

	// @InfiniteLoop
	for {
		pixels = make([]u8, dim * dim);
		ret: int;
		chars, ret = stb.bake_font_bitmap(data, 0, size, pixels, dim, dim, 0, 128);
		if ret < 0 {
			delete(pixels);
			dim *= 2;
		}
		else {
			break;
		}
	}

	texture := gen_texture();
	set_texture(texture);
	odingl.TexParameteri(coregl.TEXTURE_2D, coregl.TEXTURE_MIN_FILTER, coregl.LINEAR);
	odingl.TexParameteri(coregl.TEXTURE_2D, coregl.TEXTURE_MAG_FILTER, coregl.LINEAR);
	odingl.TexImage2D(coregl.TEXTURE_2D, 0, coregl.RGBA, cast(i32)dim, cast(i32)dim, 0, coregl.RED, coregl.UNSIGNED_BYTE, &pixels[0]);

	font := new_clone(Font{dim, size, chars, texture});
	return font, true;
}

destroy_font :: inline proc(font: ^Font) {
	delete(font.chars);
	delete_texture(font.id);
	free(font);
}

ATLAS_DIM :: 2048;

PIXELS_PER_WORLD_UNIT :: 64;

Texture_Atlas :: struct {
	id: Texture,
	atlas_x: i32,
	atlas_y: i32,
	biggest_height: i32,
}

create_atlas :: inline proc() -> ^Texture_Atlas {
	texture := gen_texture();
	set_texture(texture);
	odingl.TexImage2D(coregl.TEXTURE_2D, 0, coregl.RGBA, ATLAS_DIM, ATLAS_DIM, 0, coregl.RGBA, coregl.UNSIGNED_BYTE, nil);

	data := new_clone(Texture_Atlas{texture, 0, 0, 0});

	return data;
}

destroy_atlas :: inline proc(atlas: ^Texture_Atlas) {
	delete_texture(atlas.id);
	free(atlas);
}

load_sprite :: proc(filepath: string, texture: ^Texture_Atlas) -> (Sprite, bool) {
	stb.set_flip_vertically_on_load(1);
	sprite_width, sprite_height, channels: i32;
	pixel_data := stb.load(&filepath[0], &sprite_width, &sprite_height, &channels, 0);
	if pixel_data == nil {
		logln("Couldn't load sprite: ", filepath);
		return Sprite{}, false;
	}

	defer stb.image_free(pixel_data);

	set_texture(texture.id);

	if texture.atlas_x + sprite_width > ATLAS_DIM {
		texture.atlas_y += texture.biggest_height;
		texture.biggest_height = 0;
		texture.atlas_x = 0;
	}

	if sprite_height > texture.biggest_height do texture.biggest_height = sprite_height;
	odingl.TexSubImage2D(coregl.TEXTURE_2D, 0, texture.atlas_x, texture.atlas_y, sprite_width, sprite_height, coregl.RGBA, coregl.UNSIGNED_BYTE, pixel_data);
	odingl.TexParameteri(coregl.TEXTURE_2D, coregl.TEXTURE_WRAP_S, coregl.MIRRORED_REPEAT);
	odingl.TexParameteri(coregl.TEXTURE_2D, coregl.TEXTURE_WRAP_T, coregl.MIRRORED_REPEAT);
	odingl.TexParameteri(coregl.TEXTURE_2D, coregl.TEXTURE_MIN_FILTER, coregl.NEAREST);
	odingl.TexParameteri(coregl.TEXTURE_2D, coregl.TEXTURE_MAG_FILTER, coregl.NEAREST);
	bottom_left_x := cast(f32)texture.atlas_x / ATLAS_DIM;
	bottom_left_y := cast(f32)texture.atlas_y / ATLAS_DIM;

	width_fraction  := cast(f32)sprite_width / ATLAS_DIM;
	height_fraction := cast(f32)sprite_height / ATLAS_DIM;

	coords := [4]Vec2 {
		{bottom_left_x,                  bottom_left_y},
		{bottom_left_x,                  bottom_left_y + height_fraction},
		{bottom_left_x + width_fraction, bottom_left_y + height_fraction},
		{bottom_left_x + width_fraction, bottom_left_y},
	};

	texture.atlas_x += sprite_width;

	sprite := Sprite{coords, cast(f32)sprite_width / PIXELS_PER_WORLD_UNIT, cast(f32)sprite_height / PIXELS_PER_WORLD_UNIT, texture.id};
	return sprite, true;
}

main :: proc() {

}