import "core:fmt.odin"
import "core:strings.odin"
import "shared:odin-glfw/glfw.odin"
import "shared:odin-gl/gl.odin"
import "shared:stb/image.odin"
import "core:mem.odin"

using import "shared:sd/math.odin"
using import "shared:sd/basic.odin"

using import "rendering.odin"

transform: Mat4;
transform_buffer: u32;
instanced_shader_program: u32;

window: glfw.Window_Handle;

vao, vbo: u32;

Vertex :: struct {
	position: math.Vector2,
}

sprite_vbo := [...]Vertex {
	Vertex{math.Vector2{-1, -1}},
	Vertex{math.Vector2{-1,  1}},
	Vertex{math.Vector2{ 1,  1}},
	Vertex{math.Vector2{ 1,  1}},
	Vertex{math.Vector2{ 1, -1}},
	Vertex{math.Vector2{-1, -1}},
};

Engine_Config :: struct {
	init_proc: proc(),
	update_proc: proc(),

	window_name := "WindowName",
	window_width, window_height: i32,

	opengl_version_major := cast(i32)3,
	opengl_version_minor := cast(i32)3,
}

camera_size : f32 = 10;

start :: proc(using config: Engine_Config) {
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
		aspect := cast(f32)w / cast(f32)h;
		top := camera_size;
		bottom := -camera_size;
		left := -camera_size * aspect;
		right := camera_size * aspect;
		ortho := ortho3d(left, right, bottom, top, -1, 1);

		transform = mul(mat4_identity(), ortho);

		gl.Viewport(0, 0, w, h);
	}

	// setup opengl
	set_proc_address :: proc(p: rawptr, name: string) {
		(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
	}
	gl.load_up_to(3, 3, set_proc_address);
	size_callback(window, config.window_width, config.window_height);

	// load shaders
	shader_success: bool;
	instanced_shader_program, shader_success = gl.load_shaders("instanced_vertex.glsl", "fragment.glsl");

	// setup vao
	gl.GenVertexArrays(1, &vao);
	defer gl.DeleteVertexArrays(1, &vao);
	gl.BindVertexArray(vao);

	gl.GenBuffers(1, &vbo);
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
	gl.BufferData(gl.ARRAY_BUFFER, size_of(sprite_vbo), &sprite_vbo[0], gl.STATIC_DRAW);

	// Position
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), nil);
	gl.EnableVertexAttribArray(0);

	gl.GenBuffers(1, &transform_buffer);
	gl.BindBuffer(gl.ARRAY_BUFFER, transform_buffer);

	// Center position
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, size_of(Sprite_Data), rawptr(uintptr(offset_of(Sprite_Data, position))));
	gl.EnableVertexAttribArray(2);

	// Scale
	gl.VertexAttribPointer(3, 2, gl.FLOAT, gl.FALSE, size_of(Sprite_Data), rawptr(uintptr(offset_of(Sprite_Data, scale))));
	gl.EnableVertexAttribArray(3);

	// Texture index
	gl.VertexAttribIPointer(4, 1, gl.INT, size_of(Sprite_Data), rawptr(uintptr(offset_of(Sprite_Data, texture_index))));
	gl.EnableVertexAttribArray(4);

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

Sprite :: i32;
sprites: [dynamic]Sprite_Data;

Sprite_Data :: struct {
	position: math.Vector2,
	scale: math.Vector2,
	texture_index: i32,
}

submit_sprite :: proc(sprite: Sprite, position, scale: math.Vector2) {
	append(&sprites, Sprite_Data{position, scale, cast(i32)sprite});
}

flush_sprites :: proc() {
	print_errors();
	gl.UseProgram(instanced_shader_program);
	gl.UniformMatrix4fv(get_uniform_location(instanced_shader_program, "transform\x00"), 1, gl.FALSE, &transform[0][0]);

	gl.BindBuffer(gl.ARRAY_BUFFER, transform_buffer);
	gl.BufferData(gl.ARRAY_BUFFER, size_of(Sprite_Data) * len(sprites), &sprites[0], gl.STATIC_DRAW);

	name: string;
	location: i32;
	name = "atlas_texture\x00";
	location = gl.GetUniformLocation(instanced_shader_program, &name[0]);
	gl.Uniform1i(location, 0);

	name = "metadata_texture\x00";
	location = gl.GetUniformLocation(instanced_shader_program, &name[0]);
	gl.Uniform1i(location, 1);

	gl.ActiveTexture(gl.TEXTURE0);
	gl.BindTexture(gl.TEXTURE_2D, atlas_texture);

	gl.ActiveTexture(gl.TEXTURE1);
	gl.BindTexture(gl.TEXTURE_1D, metadata_texture);

	gl.VertexAttribDivisor(2, 1);
	gl.VertexAttribDivisor(3, 1);
	gl.VertexAttribDivisor(4, 1);

	num_sprites := cast(i32)len(sprites);
	gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, num_sprites);

	glfw.SwapBuffers(window);
}

metadata_texture: u32;
atlas_texture: u32;
atlas_loaded: bool;

atlas_x: i32;
atlas_index: i32;

load_sprite :: proc(filepath: string) -> Sprite {
	if !atlas_loaded {
		atlas_loaded = true;

		gl.GenTextures(1, &metadata_texture);
		gl.BindTexture(gl.TEXTURE_1D, metadata_texture);
		gl.TexImage1D(gl.TEXTURE_1D, 0, gl.RG32F, 2048, 0, gl.RG, gl.FLOAT, nil);
		gl.TexParameteri(gl.TEXTURE_1D, gl.TEXTURE_MAX_LEVEL, 0);

		gl.GenTextures(1, &atlas_texture);
		gl.BindTexture(gl.TEXTURE_2D, atlas_texture);
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 2048, 2048, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil);
	}

	MAX_PATH_LENGTH :: 1024;
	assert(len(filepath) <= MAX_PATH_LENGTH - 1);
	filepath_c: [MAX_PATH_LENGTH]byte;
	mem.copy(&filepath_c[0], &filepath[0], len(filepath));
	filepath_c[len(filepath)] = 0;

	image.set_flip_vertically_on_load(1);
	w, h, channels: i32;
	texture_data := image.load(&filepath_c[0], &w, &h, &channels, 0);

	gl.BindTexture(gl.TEXTURE_2D, atlas_texture);
	gl.TexSubImage2D(gl.TEXTURE_2D, 0, atlas_x, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, texture_data);

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.MIRRORED_REPEAT);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

	x01 := cast(f32)atlas_x / 2048;
	y01 := cast(f32)0 / 2048;

	w01 := cast(f32)w / 2048;
	h01 := cast(f32)h / 2048;

	fmt.println(x01, y01, w01, h01);

	coords := [...]f32 {
		x01,       y01,
		x01,       y01 + h01,
		x01 + w01, y01 + h01,
		x01 + w01, y01 + h01,
		x01 + w01, y01,
		x01,       y01,
	};

	gl.BindTexture(gl.TEXTURE_1D, metadata_texture);
	gl.TexSubImage1D(gl.TEXTURE_1D, 0, atlas_index * 6, 6, gl.RG, gl.FLOAT, &coords[0]);
	print_errors();

	atlas_x += w;
	atlas_index += 1;

	return cast(Sprite)atlas_index-1;
}

print_errors :: proc(location := #caller_location) {
	for {
		err := gl.GetError();
		if err == 0 {
			break;
		}

		fmt.println(err);
	}
}

get_uniform_location :: inline proc(program: u32, str: string) -> i32 {
	return gl.GetUniformLocation(program, &str[0]);
}