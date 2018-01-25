import "core:fmt.odin"
import "core:strings.odin"
import "core:mem.odin"
import "core:os.odin"
using import "core:math.odin"

import "shared:odin-glfw/glfw.odin"
import stbi  "shared:odin-stb/stb_image.odin"
import stbiw "shared:odin-stb/stb_image_write.odin"
import stbtt "shared:odin-stb/stb_truetype.odin"

import "gl.odin"
using import "basic.odin"

ortho_matrix:     Mat4;
transform_matrix: Mat4;
pixel_matrix:     Mat4;

main_window: glfw.Window_Handle;

camera_size: f32;
camera_position: Vec2;

current_window_width:  i32;
current_window_height: i32;
current_aspect_ratio:  f32;

rendering_world_space :: proc() {
	transform_matrix = mul(identity(Mat4), ortho_matrix);
	transform_matrix = scale(transform_matrix, 1 / camera_size);

	cam_offset := to_vec3(mul(transform_matrix, to_vec4(camera_position)));
	transform_matrix = translate(transform_matrix, -cam_offset);

	pixel_matrix = identity(Mat4);
}

rendering_camera_space_unit_scale :: proc() {
	transform_matrix = identity(Mat4);
	transform_matrix = translate(transform_matrix, Vec3{-1, -1, 0});
	transform_matrix = scale(transform_matrix, 2);

	pixel_matrix = identity(Mat4);
	pixel_matrix = scale(pixel_matrix, Vec3{1 / cast(f32)current_window_width, 1 / cast(f32)current_window_height, 0});
}

set_shader :: inline proc(program: gl.Shader_Program) {
	gl.use_program(program);
}

// glfw wrapper
window_should_close :: inline proc(window: glfw.Window_Handle) -> bool {
	return glfw.WindowShouldClose(window);
}

init_glfw :: proc(window_name: string, window_width, window_height: i32, opengl_version_major, opengl_version_minor: i32) {
	glfw_size_callback :: proc"c"(main_window: glfw.Window_Handle, w, h: i32) {
		current_window_width = w;
		current_window_height = h;
		current_aspect_ratio = cast(f32)w / cast(f32)h;

		top    : f32 =  1;
		bottom : f32 = -1;
		left   : f32 = -1 * current_aspect_ratio;
		right  : f32 =  1 * current_aspect_ratio;

		ortho_matrix  = ortho3d(left, right, bottom, top, -1, 1);

		gl.Viewport(0, 0, w, h);
	}

	glfw_scroll_callback :: proc"c"(main_window: glfw.Window_Handle, x, y: f64) {
		camera_size -= cast(f32)y * camera_size * 0.1;
	}

	glfw_error_callback :: proc"c"(error: i32, desc: ^u8) {
		fmt.printf("Error code %d:\n    %s\n", error, strings.to_odin_string(desc));
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

	glfw.SetWindowSizeCallback(main_window, glfw_size_callback);

	glfw.SetKeyCallback(main_window, _glfw_key_callback);

	// setup opengl
	gl.load_up_to(cast(int)opengl_version_major, cast(int)opengl_version_minor,
		proc(p: rawptr, name: string) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
		});

	// Set initial size of window
	glfw_size_callback(main_window, window_width, window_height);

	// Setup glfw callbacks
	glfw.SetScrollCallback(main_window, glfw_scroll_callback);
}

vao: gl.VAO;
vbo: gl.VBO;

Vertex :: struct {
	vertex_position: Vec2,
	tex_coord: Vec2,
	color: Vec4,
}

init_opengl :: proc() {
	vao = gl.gen_vao();
	gl.bind_vao(vao);

	vbo = gl.gen_buffer();
	gl.bind_buffer(vbo);

	gl.set_vertex_format(Vertex);

	gl.ClearColor(0.5, 0.1, 0.2, 1.0);
	gl.Enable(gl.BLEND);
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
}

Quad :: [6]Vertex;

all_quads: [dynamic]Quad;

Sprite :: struct {
	uvs: [4]Vec2,
	width: i32,
	height: i32,
}

WHITE := Vec4{1, 1, 1, 1};
BLACK := Vec4{0, 0, 0, 1};
RED   := Vec4{1, 0, 0, 1};
GREEN := Vec4{0, 1, 0, 1};
BLUE  := Vec4{0, 0, 1, 1};

draw_quad :: proc(p0, p1, p2, p3: Vec2, sprite: Sprite, color: Vec4) {
	v0 := Vertex{p0, sprite.uvs[0], color};
	v1 := Vertex{p1, sprite.uvs[1], color};
	v2 := Vertex{p2, sprite.uvs[2], color};
	v3 := Vertex{p3, sprite.uvs[3], color};

	quad := Quad{v0, v1, v2, v2, v3, v0};
	append(&all_quads, quad);
}

/*
draw_sprite :: proc(sprite: Sprite, position, scale: Vec2) {
	make_vertex :: proc(corner, position, scale: Vec2, sprite: Sprite, index: int) -> Vertex {
		vpos := corner;
		vpos *= scale * Vec2{cast(f32)sprite.width, cast(f32)sprite.height} / 2;
		vpos += position;

		vertex := Vertex{vpos, sprite.uvs[index], WHITE};

		return vertex;
	}

	v0 := make_vertex(Vec2{-1, -1}, position, scale, sprite, 0);
	v1 := make_vertex(Vec2{-1,  1}, position, scale, sprite, 1);
	v2 := make_vertex(Vec2{ 1,  1}, position, scale, sprite, 2);
	v3 := make_vertex(Vec2{ 1, -1}, position, scale, sprite, 3);
	quad := Quad{v0, v1, v2, v2, v3, v0};

	append(&all_quads, quad);
}
*/

draw_flush :: proc() {
	if len(all_quads) == 0 do return;

	program := gl.get_current_shader();

	gl.uniform_matrix4fv(program, "transform", 1, false, &transform_matrix[0][0]);

	gl.bind_buffer(vbo);
	gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex) * len(all_quads) * 6, &all_quads[0], gl.STATIC_DRAW);

	gl.uniform(program, "atlas_texture", 0);
	gl.bind_texture2d(atlas_texture);

	gl.DrawArrays(gl.TRIANGLES, 0, cast(i32)len(all_quads) * 6);

	clear(&all_quads);
}

get_string_width :: proc(str: string, font: []stbtt.Baked_Char) -> f32 {
	total_pixel_width: f32;
	for c in str {
		pixel_width, _, _ := stbtt.get_baked_quad(font, FONT_PIXEL_WIDTH, FONT_PIXEL_HEIGHT, cast(int)c, true);
		total_pixel_width += pixel_width;
	}

	total_width := total_pixel_width / cast(f32)current_window_width;
	return total_width;
}

// todo(josh): make this not be a draw call per call to draw_string()
draw_string :: proc(str: string, font: []stbtt.Baked_Char, position: Vec2, color: Vec4) {
	cur_x := position.x;
	for c in str {
		pixel_width, _, quad := stbtt.get_baked_quad(font, FONT_PIXEL_WIDTH, FONT_PIXEL_HEIGHT, cast(int)c, true);
		total_width := mul(pixel_matrix, Vec4{pixel_width, 0, 0, 0}).x;

		start  := mul(pixel_matrix, Vec4{quad.x0, 0, 0, 0}).x;
		yoff   := mul(pixel_matrix, Vec4{0, quad.y1, 0, 0}).y;
		height := abs(mul(pixel_matrix, Vec4{0, (quad.y1 - quad.y0), 0, 0}).y);

		xpad_before := pixel_width - (pixel_width - quad.x0);
		xpad_after := pixel_width - quad.x1;
		char_width := mul(pixel_matrix, Vec4{(pixel_width - xpad_after - xpad_before), 0, 0, 0}).x;

		uv0 := Vec2{quad.s0, quad.t1};
		uv1 := Vec2{quad.s0, quad.t0};
		uv2 := Vec2{quad.s1, quad.t0};
		uv3 := Vec2{quad.s1, quad.t1};
		sprite := Sprite{{uv0, uv1, uv2, uv3}, 0, 0};

		x0 := cur_x + start;
		y0 := position.y - yoff;
		x1 := cur_x + start + char_width;
		y1 := position.y - yoff + height;
		draw_quad(Vec2{x0, y0}, Vec2{x0, y1}, Vec2{x1, y1}, Vec2{x1, y0}, sprite, color);
		cur_x += total_width;
	}

	program := gl.get_current_shader();
	gl.uniform_matrix4fv(program, "transform", 1, false, &transform_matrix[0][0]);

	gl.bind_buffer(vbo);
	gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex) * len(all_quads) * 6, &all_quads[0], gl.STATIC_DRAW);

	gl.uniform(program, "atlas_texture", 0);
	gl.bind_texture2d(font_texture);

	gl.DrawArrays(gl.TRIANGLES, 0, cast(i32)len(all_quads) * 6);

	clear(&all_quads);
}

FONT_PIXEL_WIDTH  :: 1024;
FONT_PIXEL_HEIGHT :: 1024;
font_texture: gl.Texture;

load_font :: proc(path: string, size: f32) -> []stbtt.Baked_Char {
	data, ok := os.read_entire_file(path);
	assert(ok);
	defer free(data);

	pixels := make([]u8, FONT_PIXEL_WIDTH * FONT_PIXEL_HEIGHT);
	chars, ret := stbtt.bake_font_bitmap(data, 0, size, pixels, FONT_PIXEL_WIDTH, FONT_PIXEL_HEIGHT, 0, 128);
	// todo(josh): error checking to make sure all the characters fit in the buffer

	stbiw.write_png("font.png", FONT_PIXEL_WIDTH, FONT_PIXEL_HEIGHT, 1, pixels, 0);

	font_texture = gl.gen_texture();
	gl.bind_texture2d(font_texture);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, FONT_PIXEL_WIDTH, FONT_PIXEL_HEIGHT, 0, gl.RED, gl.UNSIGNED_BYTE, &pixels[0]);

	return chars;
}

atlas_texture: gl.Texture;
atlas_loaded: bool;

atlas_x: i32;
atlas_y: i32;
biggest_height: i32;

ATLAS_DIM :: 2048;

load_sprite :: proc(filepath: string) -> Sprite {
	// todo(josh): Handle multiple texture atlases
	if !atlas_loaded {
		atlas_loaded = true;

		atlas_texture = gl.gen_texture();
		gl.bind_texture2d(atlas_texture);
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, ATLAS_DIM, ATLAS_DIM, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil);
	}

	stbi.set_flip_vertically_on_load(1);
	sprite_width, sprite_height, channels: i32;
	texture_data := stbi.load(&filepath[0], &sprite_width, &sprite_height, &channels, 0);
	assert(texture_data != nil);

	gl.bind_texture2d(atlas_texture);

	if atlas_x + sprite_width > ATLAS_DIM {
		atlas_y += biggest_height;
		biggest_height = 0;
		atlas_x = 0;
	}

	if sprite_height > biggest_height do biggest_height = sprite_height;
	gl.TexSubImage2D(gl.TEXTURE_2D, 0, atlas_x, atlas_y, sprite_width, sprite_height, gl.RGBA, gl.UNSIGNED_BYTE, texture_data);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.MIRRORED_REPEAT);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
	bottom_left_x := cast(f32)atlas_x / ATLAS_DIM;
	bottom_left_y := cast(f32)atlas_y / ATLAS_DIM;

	width_fraction  := cast(f32)sprite_width / ATLAS_DIM;
	height_fraction := cast(f32)sprite_height / ATLAS_DIM;

	coords := [4]Vec2 {
		{bottom_left_x,                  bottom_left_y},
		{bottom_left_x,                  bottom_left_y + height_fraction},
		{bottom_left_x + width_fraction, bottom_left_y + height_fraction},
		{bottom_left_x + width_fraction, bottom_left_y},
	};

	atlas_x += sprite_height;

	sprite := Sprite{coords, sprite_width, sprite_height};
	return sprite;
}

//
// Input stuff
//

_held := make([dynamic]glfw.Key, 0, 5);
_down := make([dynamic]glfw.Key, 0, 5);
_up   := make([dynamic]glfw.Key, 0, 5);

_held_mid_frame := make([dynamic]glfw.Key, 0, 5);
_down_mid_frame := make([dynamic]glfw.Key, 0, 5);
_up_mid_frame   := make([dynamic]glfw.Key, 0, 5);

update_input :: proc() {
	glfw.PollEvents();
	clear(&_held);
	clear(&_down);
	clear(&_up);

	for held in _held_mid_frame {
		append(&_held, held);
	}
	for down in _down_mid_frame {
		append(&_down, down);
	}
	for up in _up_mid_frame {
		append(&_up, up);
	}

	clear(&_down_mid_frame);
	clear(&_up_mid_frame);
}

// this callback CAN be called during a frame, outside of the glfw.PollEvents() call, on some platforms
// so we need to save presses in a separate buffer and copy them over to have consistent behaviour
_glfw_key_callback :: proc"c"(window: glfw.Window_Handle, key: glfw.Key, scancode: i32, action: glfw.Action, mods: i32) {
	when false {
		fmt.println("cap of held", cap(_held), cap(_held_mid_frame));
		fmt.println("cap of up",   cap(_up),   cap(_up_mid_frame));
		fmt.println("cap of down", cap(_down), cap(_down_mid_frame));
	}

	switch action {
		case glfw.Action.Press: {
			append(&_held_mid_frame, key);
			append(&_down_mid_frame, key);
		}
		case glfw.Action.Release: {
			remove_all(&_held_mid_frame, key);
			append(&_up_mid_frame, key);
		}
	}
}

get_key :: proc(key: glfw.Key) -> bool {
	for held in _held {
		if held == key {
			return true;
		}
	}
	return false;
}

get_key_down :: proc(key: glfw.Key) -> bool {
	for down in _down {
		if down == key {
			return true;
		}
	}
	return false;
}

get_key_up :: proc(key: glfw.Key) -> bool {
	for up in _up {
		if up == key {
			return true;
		}
	}
	return false;
}

//
// Time
//

delta_time: f32;
last_frame_time: f32;

update_time :: proc() {
	// show fps in window title
	glfw.calculate_frame_timings(main_window);
	time := cast(f32)glfw.GetTime();
	delta_time = time - last_frame_time;
	last_frame_time = time;
}
