import "core:fmt.odin"
import "core:strings.odin"
import "core:mem.odin"
import "core:math.odin"

import "shared:odin-glfw/glfw.odin"
import "shared:stb/image.odin"

import "gl.odin"
import "basic.odin"

transform: math.Mat4;
transform_buffer: gl.VBO;
the_shader_program: gl.Shader_Program;

window: glfw.Window_Handle;

vao: gl.VAO;
vbo: gl.VBO;

sprite_vbo := [...]math.Vec2 {
	{-1, -1},
	{-1,  1},
	{ 1,  1},
	{ 1,  1},
	{ 1, -1},
	{-1, -1},
};

Engine_Config :: struct {
	init_proc: proc(),
	update_proc: proc(),

	window_name := "WindowName",
	window_width, window_height: i32,

	opengl_version_major: i32,
	opengl_version_minor: i32,

	camera_size: f32,
}

camera_size: f32;
camera_position: math.Vec2;
current_window_width: i32;
current_window_height: i32;

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
	window = glfw.CreateWindow(config.window_width, config.window_height, config.window_name, nil, nil);
	if window == nil do return;

	video_mode := glfw.GetVideoMode(glfw.GetPrimaryMonitor());
	glfw.SetWindowPos(window, video_mode.width / 2 - config.window_width / 2, video_mode.height / 2 - config.window_height / 2);

	glfw.MakeContextCurrent(window);
	glfw.SwapInterval(1);

	glfw.SetWindowSizeCallback(window, size_callback);
	size_callback :: proc"c"(window: glfw.Window_Handle, w, h: i32) {
		current_window_width = w;
		current_window_height = h;

		aspect := cast(f32)w / cast(f32)h;
		top := camera_size;
		bottom := -camera_size;
		left := -camera_size * aspect;
		right := camera_size * aspect;
		ortho := math.ortho3d(left, right, bottom, top, -1, 1);

		transform = math.mul(math.identity(math.Mat4), ortho);

		gl.Viewport(0, 0, w, h);
	}

	// setup opengl
	gl.load_up_to(3, 3,
		proc(p: rawptr, name: string) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
		});

	// Set initial size of window
	camera_size = config.camera_size;
	size_callback(window, config.window_width, config.window_height);

	// Setup glfw callbacks
	glfw.SetScrollCallback(window,
		proc"c"(window: glfw.Window_Handle, x, y: f64) {
			camera_size -= cast(f32)y * camera_size * 0.1;
			size_callback(window, current_window_width, current_window_height);
		});

	glfw.SetKeyCallback(window,
		proc"c"(window: glfw.Window_Handle, key, scancode, action, mods: i32) {
			if action == glfw.REPEAT || action == glfw.PRESS
			{
				if key == glfw.KEY_LEFT {
					camera_position.x -= 12.8;
				}
				if key == glfw.KEY_RIGHT {
					camera_position.x += 12.8;
				}
				if key == glfw.KEY_UP {
					camera_position.y += 12.8;
				}
				if key == glfw.KEY_DOWN {
					camera_position.y -= 12.8;
				}
			}
		});

	// load shaders
	shader_success: bool;
	the_shader_program, shader_success = gl.load_shader_files("vertex.glsl", "fragment.glsl");
	assert(shader_success);

	// setup vao
	vao = gl.gen_vao();
	defer gl.delete_vao(vao);
	gl.bind_vao(vao);

	vbo = gl.gen_buffer();
	gl.bind_buffer(vbo);
	gl.BufferData(gl.ARRAY_BUFFER, size_of(sprite_vbo), &sprite_vbo[0], gl.STATIC_DRAW);

	// Position
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, size_of(math.Vec2), nil);
	gl.EnableVertexAttribArray(0);

	transform_buffer = gl.gen_buffer();
	gl.bind_buffer(transform_buffer);

	// Center position
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, size_of(Sprite_Data), rawptr(uintptr(offset_of(Sprite_Data, position))));
	gl.EnableVertexAttribArray(2);

	// Scale
	gl.VertexAttribPointer(3, 2, gl.FLOAT, gl.FALSE, size_of(Sprite_Data), rawptr(uintptr(offset_of(Sprite_Data, scale))));
	gl.EnableVertexAttribArray(3);

	// Sprite index
	gl.VertexAttribIPointer(4, 1, gl.INT, size_of(Sprite_Data), rawptr(uintptr(offset_of(Sprite_Data, index))));
	gl.EnableVertexAttribArray(4);

	// Sprite width
	gl.VertexAttribIPointer(5, 1, gl.INT, size_of(Sprite_Data), rawptr(uintptr(offset_of(Sprite_Data, width))));
	gl.EnableVertexAttribArray(5);

	// Sprite height
	gl.VertexAttribIPointer(6, 1, gl.INT, size_of(Sprite_Data), rawptr(uintptr(offset_of(Sprite_Data, height))));
	gl.EnableVertexAttribArray(6);

	sprites = make([dynamic]Sprite_Data, 0, 4);

	gl.ClearColor(0.5, 0.1, 0.2, 1.0);
	gl.Enable(gl.BLEND);
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

	config.init_proc();

	for glfw.WindowShouldClose(window) == glfw.FALSE {
		// show fps in window title
		glfw.calculate_frame_timings(window);

		// listen to input
		glfw.PollEvents();

		if glfw.GetKey(window, glfw.KEY_ESCAPE) {
			glfw.SetWindowShouldClose(window, true);
		}

		// clear screen
		gl.Clear(gl.COLOR_BUFFER_BIT);

		clear(&sprites);
		config.update_proc();
	}
}

sprites: [dynamic]Sprite_Data;

Sprite :: struct {
	index: i32,
	width: i32,
	height: i32,
}

Sprite_Data :: struct {
	using sprite: Sprite,
	position: math.Vec2,
	scale: math.Vec2,
}

submit_sprite :: proc(sprite: Sprite, position, scale: math.Vec2) {
	data := Sprite_Data{sprite, position, scale};
	append(&sprites, data);
}

flush_sprites :: proc() {
	gl.use_program(the_shader_program);
	gl.uniform_matrix4fv(the_shader_program, "transform", 1, false, &transform[0][0]);
	gl.uniform(the_shader_program, "camera_position", camera_position.x, camera_position.y);
	gl.uniform(the_shader_program, "atlas_dim", cast(f32)ATLAS_DIM);

	gl.bind_buffer(transform_buffer);
	gl.BufferData(gl.ARRAY_BUFFER, size_of(Sprite_Data) * len(sprites), &sprites[0], gl.STATIC_DRAW);

	gl.uniform(the_shader_program, "atlas_texture", 0);
	gl.uniform(the_shader_program, "metadata_texture", 1);

	gl.active_texture0();
	gl.bind_texture2d(atlas_texture);

	gl.active_texture1();
	gl.bind_texture1d(metadata_texture);

	gl.VertexAttribDivisor(2, 1);
	gl.VertexAttribDivisor(3, 1);
	gl.VertexAttribDivisor(4, 1);
	gl.VertexAttribDivisor(5, 1);
	gl.VertexAttribDivisor(6, 1);

	num_sprites := cast(i32)len(sprites);
	gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, num_sprites);

	glfw.SwapBuffers(window);
}

metadata_texture: gl.Texture;
atlas_texture: gl.Texture;
atlas_loaded: bool;

atlas_x: i32;
atlas_y: i32;
biggest_height: i32;
sprite_index: i32;

ATLAS_DIM :: 2048;

load_sprite :: proc(filepath: string) -> Sprite {
	if !atlas_loaded {
		atlas_loaded = true;

		metadata_texture = gl.gen_texture();
		gl.bind_texture1d(metadata_texture);
		gl.TexImage1D(gl.TEXTURE_1D, 0, gl.RG32F, 4096, 0, gl.RG, gl.FLOAT, nil);
		gl.TexParameteri(gl.TEXTURE_1D, gl.TEXTURE_MAX_LEVEL, 0);

		atlas_texture = gl.gen_texture();
		gl.bind_texture2d(atlas_texture);
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, ATLAS_DIM, ATLAS_DIM, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil);
	}

	MAX_PATH_LENGTH :: 1024;
	assert(len(filepath) <= MAX_PATH_LENGTH - 1);
	filepath_c: [MAX_PATH_LENGTH]byte;
	mem.copy(&filepath_c[0], &filepath[0], len(filepath));
	filepath_c[len(filepath)] = 0;

	image.set_flip_vertically_on_load(1);
	sprite_width, sprite_height, channels: i32;
	texture_data := image.load(&filepath_c[0], &sprite_width, &sprite_height, &channels, 0);

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

	x01 := cast(f32)atlas_x / 2048;
	y01 := cast(f32)atlas_y / 2048;

	w01 := cast(f32)sprite_width / 2048;
	h01 := cast(f32)sprite_height / 2048;

	Metadata_Texture_Entry :: struct {
		uv: math.Vec2,
	}

	coords := [...]Metadata_Texture_Entry {
		{{x01,       y01}},
		{{x01,       y01 + h01}},
		{{x01 + w01, y01 + h01}},
		{{x01 + w01, y01 + h01}},
		{{x01 + w01, y01}},
		{{x01,       y01}},
	};

	gl.bind_texture1d(metadata_texture);
	gl.TexSubImage1D(gl.TEXTURE_1D, 0, sprite_index * len(coords), len(coords), gl.RG, gl.FLOAT, &coords[0]);
	print_errors();

	sprite: Sprite;
	sprite.index = sprite_index;
	sprite.width = sprite_width;
	sprite.height = sprite_height;

	atlas_x += sprite_height;
	sprite_index += 1;

	return sprite;
}

print_errors :: proc(location := #caller_location) {
	for {
		err := gl.GetError();
		if err == 0 {
			break;
		}

		fmt.println(location, err);
	}
}