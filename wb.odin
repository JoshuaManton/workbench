import "core:fmt.odin"
import "core:strings.odin"
import "core:mem.odin"
using import "core:math.odin"

import "shared:odin-glfw/glfw.odin"
import "shared:stb/image.odin"

import "gl.odin"
using import "basic.odin"

ortho:     Mat4;
transform: Mat4;

main_window: glfw.Window_Handle;

Engine_Config :: struct {
	init_proc:   proc(),
	update_proc: proc(),
	render_proc: proc(),

	window_name := "WindowName",
	window_width, window_height: i32,

	opengl_version_major: i32,
	opengl_version_minor: i32,

	camera_size: f32,
}

camera_size: f32;
camera_position: Vec2;
current_window_width: i32;
current_window_height: i32;

rendering_world_space :: proc() {
	transform = mul(identity(Mat4), ortho);
	transform = scale(transform, 1 / camera_size);

	cam_offset := to_vec3(mul(transform, to_vec4(camera_position)));
	transform = translate(transform, -cam_offset);
}

_size_callback :: proc"c"(main_window: glfw.Window_Handle, w, h: i32) {
	current_window_width = w;
	current_window_height = h;

	aspect := cast(f32)w / cast(f32)h;
	top    : f32 =  1;
	bottom : f32 = -1;
	left   : f32 = -1 * aspect;
	right  : f32 =  1 * aspect;

	ortho  = ortho3d(left, right, bottom, top, -1, 1);

	transform = mul(identity(Mat4), ortho);

	gl.Viewport(0, 0, w, h);
}

start :: proc(config: Engine_Config) {
	// setup glfw
	glfw.SetErrorCallback(error_callback);
	error_callback :: proc"c"(error: i32, desc: ^u8) {
		fmt.printf("Error code %d:\n    %s\n", error, strings.to_odin_string(desc));
	}

	if glfw.Init() == 0 do return;
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, config.opengl_version_major);
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, config.opengl_version_minor);
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
	main_window = glfw.CreateWindow(config.window_width, config.window_height, config.window_name, nil, nil);
	if main_window == nil do return;

	video_mode := glfw.GetVideoMode(glfw.GetPrimaryMonitor());
	glfw.SetWindowPos(main_window, video_mode.width / 2 - config.window_width / 2, video_mode.height / 2 - config.window_height / 2);

	glfw.MakeContextCurrent(main_window);
	glfw.SwapInterval(1);

	glfw.SetWindowSizeCallback(main_window, _size_callback);

	glfw.SetKeyCallback(main_window, _glfw_key_callback);

	// setup opengl
	gl.load_up_to(3, 3,
		proc(p: rawptr, name: string) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
		});

	// Set initial size of window
	current_window_width = config.window_width;
	current_window_height = config.window_height;
	_size_callback(main_window, current_window_width, current_window_height);
	camera_size = config.camera_size;

	// Setup glfw callbacks
	glfw.SetScrollCallback(main_window,
		proc"c"(main_window: glfw.Window_Handle, x, y: f64) {
			camera_size -= cast(f32)y * camera_size * 0.1;
		});

	// setup vao
	vao = gl.gen_vao();
	gl.bind_vao(vao);

	vbo = gl.gen_buffer();
	gl.bind_buffer(vbo);

	gl.set_vertex_format(Vertex);

	gl.ClearColor(0.5, 0.1, 0.2, 1.0);
	gl.Enable(gl.BLEND);
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

	config.init_proc();

	for glfw.WindowShouldClose(main_window) == glfw.FALSE {
		_update_time();

		// listen to input
		_update_input();

		if get_key(glfw.Key.Escape) {
			glfw.SetWindowShouldClose(main_window, true);
		}

		// clear screen
		gl.Clear(gl.COLOR_BUFFER_BIT);

		config.update_proc();
		config.render_proc();
		log_gl_errors("after render_proc()");
	}
}

vao: gl.VAO;
vbo: gl.VBO;

Vertex :: struct {
	vertex_position: Vec2,
	tex_coord: Vec2,
}

Quad :: [6]Vertex;

all_quads: [dynamic]Quad;

Sprite :: struct {
	uvs: [4]Vec2,
	width: i32,
	height: i32,
}

draw_quad :: proc(p0, p1, p2, p3: Vec2, sprite: Sprite) {
	v0 := Vertex{p0, sprite.uvs[0]};
	v1 := Vertex{p1, sprite.uvs[1]};
	v2 := Vertex{p2, sprite.uvs[2]};
	v3 := Vertex{p3, sprite.uvs[3]};

	quad := Quad{v0, v1, v2, v2, v3, v0};
	append(&all_quads, quad);
}

draw_sprite :: proc(sprite: Sprite, position, scale: Vec2) {
	make_vertex :: proc(corner, position, scale: Vec2, sprite: Sprite, index: int) -> Vertex {
		vpos := corner;
		vpos *= scale * Vec2{cast(f32)sprite.width, cast(f32)sprite.height} / 2;
		vpos += position;

		vertex := Vertex{vpos, sprite.uvs[index]};

		return vertex;
	}

	v0 := make_vertex(Vec2{-1, -1}, position, scale, sprite, 0);
	v1 := make_vertex(Vec2{-1,  1}, position, scale, sprite, 1);
	v2 := make_vertex(Vec2{ 1,  1}, position, scale, sprite, 2);
	v3 := make_vertex(Vec2{ 1, -1}, position, scale, sprite, 3);
	quad := Quad{v0, v1, v2, v2, v3, v0};

	append(&all_quads, quad);
}

draw_flush :: proc() {
	program := gl.get_current_shader();
	gl.uniform_matrix4fv(program, "transform", 1, false, &transform[0][0]);

	gl.bind_buffer(vbo);
	gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex) * len(all_quads) * 6, &all_quads[0], gl.STATIC_DRAW);

	gl.uniform(program, "atlas_texture", 0);
	gl.bind_texture2d(atlas_texture);

	gl.DrawArrays(gl.TRIANGLES, 0, cast(i32)len(all_quads) * 6);

	clear(&all_quads);
	glfw.SwapBuffers(main_window);
}

atlas_texture: gl.Texture;
atlas_loaded: bool;

atlas_x: i32;
atlas_y: i32;
biggest_height: i32;

ATLAS_DIM :: 2048;

load_sprite :: proc(filepath: string) -> Sprite {
	// todo(josh): Handle multiple texture atlases?
	if !atlas_loaded {
		atlas_loaded = true;

		atlas_texture = gl.gen_texture();
		gl.bind_texture2d(atlas_texture);
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, ATLAS_DIM, ATLAS_DIM, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil);
	}

	filepath_c := to_c_string(filepath);
	image.set_flip_vertically_on_load(1);
	sprite_width, sprite_height, channels: i32;
	texture_data := image.load(&filepath_c[0], &sprite_width, &sprite_height, &channels, 0);
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

log_gl_errors :: proc(caller_context: string, location := #caller_location) {
	for {
		err := gl.GetError();
		if err == 0 {
			break;
		}

		file := location.file_path;
		idx, ok := find_from_right(location.file_path, '\\');
		if ok {
			file = location.file_path[idx+1..len(location.file_path)];
		}

		fmt.printf("[%s] OpenGL Error at <%s:%d>: %d\n", caller_context, file, location.line, err);
	}
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

_update_input :: proc() {
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

_update_time :: proc() {
	// show fps in window title
	glfw.calculate_frame_timings(main_window);
	time := cast(f32)glfw.GetTime();
	delta_time = time - last_frame_time;
	last_frame_time = time;
}
