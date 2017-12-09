import "core:fmt.odin"
import "core:strings.odin"
import "shared:odin-glfw/glfw.odin"
import "shared:odin-gl/gl.odin"
import "shared:stb/image.odin"
import "core:mem.odin"

using import "shared:sd/math.odin"
using import "shared:sd/basic.odin"

using import "rendering.odin"

ortho: Mat4;
transform: Mat4;
transform_buffer: u32;
instanced_shader_program: u32;

window: glfw.Window_Handle;

vao, vbo: u32;

sprite_vbo := [...]f32 {
	-1, -1, 0, 0,
	-1,  1, 0, 1,
	 1,  1, 1, 1,
	 1,  1, 1, 1,
	 1, -1, 1, 0,
	-1, -1, 0, 0,
};

Engine_Config :: struct {
	init_proc: proc(),
	update_proc: proc(),

	window_name := "WindowName",
	window_width, window_height: i32,

	opengl_version_major := cast(i32)3,
	opengl_version_minor := cast(i32)3,

	camera_size := 10,
}

camera_size : i32 = 10;

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
		left := i32(cast(f32)-camera_size * aspect);
		right := i32(cast(f32)camera_size * aspect);
		ortho = ortho3d(cast(f32)left, cast(f32)right, cast(f32)bottom, cast(f32)top, -100, 100);

		transform = mat4_identity();
		transform = mul(transform, ortho);

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

	stride : i32 = size_of(f32)*4;

	// Position
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, stride, nil);
	gl.EnableVertexAttribArray(0);

	// Texcoord
	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, stride, rawptr(uintptr(2*size_of(f32))));
	gl.EnableVertexAttribArray(1);

	gl.GenBuffers(1, &transform_buffer);
	gl.BindBuffer(gl.ARRAY_BUFFER, transform_buffer);

	// Center position
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, size_of(Sprite_Data), rawptr(uintptr(offset_of(Sprite_Data, position))));
	gl.EnableVertexAttribArray(2);

	// Scale
	gl.VertexAttribPointer(3, 2, gl.FLOAT, gl.FALSE, size_of(Sprite_Data), rawptr(uintptr(offset_of(Sprite_Data, scale))));
	gl.EnableVertexAttribArray(3);

	// Texture index
	gl.VertexAttribPointer(4, 2, gl.FLOAT, gl.FALSE, size_of(Sprite_Data), rawptr(uintptr(offset_of(Sprite_Data, scale))));
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

Sprite :: u32;
sprites: [dynamic]Sprite_Data;

Sprite_Data :: struct {
	position: math.Vector2,
	scale: math.Vector2,
}

submit_sprite :: proc(sprite: Sprite, position, scale: math.Vector2) {
	append(&sprites, Sprite_Data{position, scale});
}

flush_sprites :: proc() {
	gl.UseProgram(instanced_shader_program);;
	gl.UniformMatrix4fv(get_uniform_location(instanced_shader_program, "transform\x00"), 1, gl.FALSE, &transform[0][0]);

	gl.BindBuffer(gl.ARRAY_BUFFER, transform_buffer);
	gl.BufferData(gl.ARRAY_BUFFER, size_of(Sprite_Data) * len(sprites), &sprites[0], gl.STATIC_DRAW);

	gl.VertexAttribDivisor(2, 1);
	gl.VertexAttribDivisor(3, 1);

	num_sprites := cast(i32)len(sprites);
	gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, num_sprites);

	glfw.SwapBuffers(window);
}

load_sprite :: proc(filepath: string) -> Sprite {
	MAX_PATH_LENGTH :: 1024;

	assert(len(filepath) <= MAX_PATH_LENGTH - 1);
	filepath_c: [MAX_PATH_LENGTH]byte;
	mem.copy(&filepath_c[0], &filepath[0], len(filepath));
	filepath_c[len(filepath)] = 0;

	image.set_flip_vertically_on_load(1);
	w, h, channels: i32;
	texture_data := image.load(&filepath_c[0], &w, &h, &channels, 0);

	texture_id: u32;
	gl.GenTextures(1, &texture_id);
	gl.BindTexture(gl.TEXTURE_2D, texture_id);
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, texture_data);
	gl.GenerateMipmap(gl.TEXTURE_2D);

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.MIRRORED_REPEAT);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

	return cast(Sprite)texture_id;
}

get_uniform_location :: inline proc(program: u32, str: string) -> i32 {
	return gl.GetUniformLocation(program, &str[0]);
}