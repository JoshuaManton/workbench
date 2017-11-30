import "core:fmt.odin"
import "core:strings.odin"
import "shared:odin-glfw/glfw.odin"
import "shared:odin-gl/gl.odin"
import "shared:stb/image.odin"

using import "shared:sd_math.odin"

setup_window :: proc() -> glfw.Window_Handle {
	// setup glfw
	error_callback :: proc"c"(error: i32, desc: ^u8) {
		fmt.printf("Error code %d:\n    %s\n", error, strings.to_odin_string(desc));
	}
	glfw.SetErrorCallback(error_callback);

	if glfw.Init() == 0 do return nil;

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3);
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3);
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

	resx, resy : i32 = 1600, 900;
	window := glfw.CreateWindow(resx, resy, "Odin Triangle Example Rendering", nil, nil);
	if window == nil do return nil;

	glfw.MakeContextCurrent(window);
	glfw.SwapInterval(1);

	// setup opengl
	set_proc_address :: proc(p: rawptr, name: string) {
		(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
	}
	gl.load_up_to(3, 3, set_proc_address);

	return window;
}

main :: proc() {
	window := setup_window();

	// load shaders
	program, shader_success := gl.load_shaders("vertex.glsl", "fragment.glsl");
	defer gl.DeleteProgram(program);

	// setup vao
	vao: u32;
	gl.GenVertexArrays(1, &vao);
	defer gl.DeleteVertexArrays(1, &vao);
	gl.BindVertexArray(vao);

	// setup vbo
	vertex_data := [...]f32 {
		-1, -1, 0, 0,
		-1,  1, 0, 1,
		 1,  1, 1, 1,
		 1, -1, 1, 0,
	};

	indices := [...]u8 {
		0, 1, 2,
		2, 3, 0
	};

	vbo: u32;
	gl.GenBuffers(1, &vbo);
	defer gl.DeleteBuffers(1, &vbo);

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertex_data), &vertex_data[0], gl.STATIC_DRAW);

	generate_texture :: proc(filepath_c: string) -> u32 {
		w, h, channels: i32;
		image.set_flip_vertically_on_load(1);
		texture_data := image.load(&filepath_c[0], &w, &h, &channels, 0);

		texture: u32;
		gl.GenTextures(1, &texture);
		gl.BindTexture(gl.TEXTURE_2D, texture);
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, texture_data);
		gl.GenerateMipmap(gl.TEXTURE_2D);

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.MIRRORED_REPEAT);
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

		gl.Enable(gl.BLEND);
		gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

		return texture;
	}

	texture := generate_texture("guy.png\x00");

	stride : i32 = size_of(f32)*4;

	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, stride, nil);
	gl.EnableVertexAttribArray(0);

	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, stride, rawptr(uintptr(2*size_of(f32))));
	gl.EnableVertexAttribArray(1);

	ortho := ortho3d(-800, 800, -450, 450, -1, 1);

	// main loop
	gl.ClearColor(0.5, 0.1, 0.2, 1.0);
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

		// setup shader program and uniforms
		gl.UseProgram(program);

		matrix_from_scale :: proc(scale: Vec2) -> Mat4 {
			scale_matrix := mat4_identity();
			scale_matrix[0][0] = scale[0];
			scale_matrix[1][1] = scale[1];

			return scale_matrix;
		}

		position_to_translation :: proc(position: Vec2, proj: Mat4) -> Mat4 {
			position4 := mul(proj, Vec4{position[0], position[1], 0, 0});
			return mat4_translate(Vec3{position4[0], position4[1], position4[2]});
		}

		scale := Vec2{200, 200};
		position := Vec2{0, 0};

		transform := position_to_translation(position, ortho);
		transform = mul(transform, ortho);
		transform = mul(transform, matrix_from_scale(scale));

		gl.UniformMatrix4fv(get_uniform_location(program, "transform\x00"), 1, gl.FALSE, &transform[0][0]);

		// draw stuff
		gl.BindVertexArray(vao);
		gl.BindTexture(gl.TEXTURE_2D, texture);

		gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_BYTE, &indices[0]);

		glfw.SwapBuffers(window);
	}
}

// wrapper to use GetUniformLocation with an Odin string
// NOTE: str has to be zero-terminated, so add a \x00 at the end
get_uniform_location :: proc(program: u32, str: string) -> i32 {
	return gl.GetUniformLocation(program, &str[0]);
}
