using import       "core:fmt.odin"
      import       "core:strings.odin"
      import       "core:mem.odin"
      import       "core:os.odin"
      import win32 "core:sys/windows.odin"

      import stbi  "stb_image.odin"
      import stbiw "stb_image_write.odin"
      import stbtt "stb_truetype.odin"

      import       "glfw.odin"

      export       "gl.odin"
      export       "input.odin"
      export       "types.odin"
      export       "collision.odin"
      export       "math.odin"
      export       "basic.odin"
      export       "logging.odin"

DEVELOPER :: true;

pixel_to_world_matrix: Mat4;

ortho_matrix:     Mat4;
transform_matrix: Mat4;
pixel_matrix:     Mat4;

main_window: glfw.Window_Handle;

camera_size: f32 = 1;
camera_position: Vec2;

current_window_width:  i32;
current_window_height: i32;
current_aspect_ratio:  f32;

cursor_screen_position: Vec2;

rendering_world_space :: proc(location := #caller_location) {
	draw_flush();

	transform_matrix = mul(identity(Mat4), ortho_matrix);
	transform_matrix = scale(transform_matrix, 1.0 / camera_size);

	cam_offset := to_vec3(mul(transform_matrix, to_vec4(camera_position)));
	transform_matrix = translate(transform_matrix, -cam_offset);

	pixel_matrix = identity(Mat4);
	pixel_matrix = scale(pixel_matrix, 1.0 / PIXELS_PER_WORLD_UNIT);
}

rendering_unit_space :: proc(location := #caller_location) {
	draw_flush();

	transform_matrix = identity(Mat4);
	transform_matrix = translate(transform_matrix, Vec3{-1, -1, 0});
	transform_matrix = scale(transform_matrix, 2);

	pixel_matrix = identity(Mat4);
	pixel_matrix = scale(pixel_matrix, Vec3{1.0 / cast(f32)current_window_width, 1.0 / cast(f32)current_window_height, 0});
}

rendering_pixel_space :: proc(location := #caller_location) {
	draw_flush();

	transform_matrix = identity(Mat4);
	transform_matrix = scale(transform_matrix, to_vec3(Vec2{1.0 / cast(f32)current_window_width, 1.0 / cast(f32)current_window_height}));
	transform_matrix = translate(transform_matrix, Vec3{-1, -1, 0});
	transform_matrix = scale(transform_matrix, 2);

	pixel_matrix = identity(Mat4);
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

	pos.y = 1.0 - pos.y;

	camera_size_x := camera_size * current_aspect_ratio;
	camera_size_y := camera_size;

	pos.x *= camera_size_x * 2.0;
	pos.y *= camera_size_y * 2.0;

	pos.x -= camera_size_x;
	pos.y -= camera_size_y;

	pos += camera_position;

	return pos;
}

cursor_world_position :: inline proc() -> Vec2 {
	return screen_to_world(cursor_screen_position);
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

		Viewport(0, 0, w, h);
	}

	glfw_cursor_callback :: proc"c"(main_window: glfw.Window_Handle, x, y: f64) {
		cursor_screen_position = Vec2{cast(f32)x, cast(f32)current_window_height - cast(f32)y};
	}

	glfw_scroll_callback :: proc"c"(main_window: glfw.Window_Handle, x, y: f64) {
		camera_size -= cast(f32)y * camera_size * 0.1;
	}

	glfw_error_callback :: proc"c"(error: i32, desc: ^u8) {
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
	load_up_to(cast(int)opengl_version_major, cast(int)opengl_version_minor,
		proc(p: rawptr, name: cstring) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(cast(^u8)name));
		});

	// Set initial size of window
	glfw_size_callback(main_window, window_width, window_height);

	// Setup glfw callbacks
	glfw.SetScrollCallback(main_window, glfw_scroll_callback);
}

vao: VAO;
vbo: VBO;

init_opengl :: proc() {
	vao = gen_vao();
	bind_vao(vao);

	vbo = gen_buffer();
	bind_buffer(vbo);

	set_vertex_format(Vertex_Type);

	ClearColor(0.2, 0.5, 0.8, 1.0);
	Enable(BLEND);
	BlendFunc(SRC_ALPHA, ONE_MINUS_SRC_ALPHA);
}

queued_for_drawing: [dynamic]Vertex_Type;
debug_lines:        [dynamic]Line_Segment;

Vertex_Type :: struct {
	vertex_position: Vec2,
	tex_coord: Vec2,
	color: Colorf,
}

Line_Segment :: struct {
	a, b: Vec2,
	color: Colorf,
}

draw_line :: inline proc(a, b: Vec2, color: Colorf) {
	append(&debug_lines, Line_Segment{a, b, color});
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

push_quad :: proc[push_quad_min_max_color, push_quad_min_max_sprite, push_quad_min_max_sprite_color,
                  push_quad_points_color,  push_quad_points_sprite,  push_quad_points_sprite_color];

push_quad_min_max_color :: inline proc(shader: Shader_Program, min, max: Vec2, color: Colorf) {
	_push_quad(shader, min, Vec2{min.x, max.y}, max, Vec2{max.x, min.y}, Sprite{}, color);
}
push_quad_min_max_sprite :: inline proc(shader: Shader_Program, min, max: Vec2, sprite: Sprite) {
	_push_quad(shader, min, Vec2{min.x, max.y}, max, Vec2{max.x, min.y}, sprite, COLOR_WHITE);
}
push_quad_min_max_sprite_color :: inline proc(shader: Shader_Program, min, max: Vec2, sprite: Sprite, color: Colorf) {
	_push_quad(shader, min, Vec2{min.x, max.y}, max, Vec2{max.x, min.y}, sprite, color);
}

push_quad_points_color :: inline proc(shader: Shader_Program, p0, p1, p2, p3: Vec2, color: Colorf) {
	_push_quad(shader, p0, p1, p2, p3, Sprite{}, color);
}
push_quad_points_sprite :: inline proc(shader: Shader_Program, p0, p1, p2, p3: Vec2, sprite: Sprite) {
	_push_quad(shader, p0, p1, p2, p3, sprite, COLOR_WHITE);
}
push_quad_points_sprite_color :: inline proc(shader: Shader_Program, p0, p1, p2, p3: Vec2, sprite: Sprite, color: Colorf) {
	_push_quad(shader, p0, p1, p2, p3, sprite, color);
}

_push_quad :: inline proc(shader: Shader_Program, p0, p1, p2, p3: Vec2, sprite: Sprite, color: Colorf) {
	push_vertex(shader, sprite.id, p0, sprite.uvs[0], color);
	push_vertex(shader, sprite.id, p1, sprite.uvs[1], color);
	push_vertex(shader, sprite.id, p2, sprite.uvs[2], color);
	push_vertex(shader, sprite.id, p2, sprite.uvs[2], color);
	push_vertex(shader, sprite.id, p3, sprite.uvs[3], color);
	push_vertex(shader, sprite.id, p0, sprite.uvs[0], color);
}

shader_rgba:    Shader_Program;
shader_text:    Shader_Program;
shader_texture: Shader_Program;

current_shader: Shader_Program;
current_texture: Texture;

push_vertex :: inline proc(shader: Shader_Program, texture: Texture, position: Vec2, tex_coord: Vec2, color: Colorf) {
	assert(shader != 0);

	shader_mismatch  := shader != current_shader;
	texture_mismatch := texture != current_texture;
	if shader_mismatch || texture_mismatch {
		draw_flush();
	}

	if shader_mismatch  do set_shader(shader);
	if texture_mismatch do set_texture(texture);

	vertex := Vertex_Type{position, tex_coord, color};
	append(&queued_for_drawing, vertex);
}

swap_buffers :: inline proc() {
	glfw.SwapBuffers(main_window);
}

_get_size_ratio_for_font :: inline proc(font: ^Font, _size: f32) -> f32 {
	size := _size / 2; // not sure why this is necessary but the text was being drawn twice as big as it should be
	pixel_size := mul(transform_matrix, Vec4{0, size, 0, 0}).y;
	pixel_size *= cast(f32)current_window_height;
	size_ratio := pixel_size / font.size;
	return size_ratio;
}

get_string_width :: proc(str: string, font: ^Font, size: f32) -> f32 {
	size_ratio := _get_size_ratio_for_font(font, size);
	cur_width : f32 = 0;
	for c in str {
		pixel_width, _, quad := stbtt.get_baked_quad(font.chars, font.dim, font.dim, cast(int)c, true);
		pixel_width *= size_ratio;
		cur_width += (pixel_width * pixel_matrix[0][0]);
	}

	return cur_width;
}

draw_string :: proc(font: ^Font, str: string, position: Vec2, color: Colorf, size: f32) -> f32 {
	size_ratio := _get_size_ratio_for_font(font, size);
	cur_x := position.x;
	for c in str {
		pixel_width, _, quad := stbtt.get_baked_quad(font.chars, font.dim, font.dim, cast(int)c, true);
		pixel_width *= size_ratio;

		offset := mul(pixel_matrix, Vec4{quad.x0, quad.y1, 0, 0}) * size_ratio;
		start  := offset.x;
		yoff   := offset.y;

		left_padding := pixel_width - (pixel_width - quad.x0);
		right_padding := pixel_width - quad.x1;

		size   := mul(pixel_matrix, Vec4{(pixel_width - right_padding - left_padding), (quad.y1 - quad.y0), 0, 0}) * size_ratio;
		width  := size.x;
		height := abs(size.y);

		uv0 := Vec2{quad.s0, quad.t1};
		uv1 := Vec2{quad.s0, quad.t0};
		uv2 := Vec2{quad.s1, quad.t0};
		uv3 := Vec2{quad.s1, quad.t1};
		sprite := Sprite{{uv0, uv1, uv2, uv3}, 0, 0, font.id};

		x0 := cur_x + start;
		y0 := position.y - yoff;
		x1 := cur_x + start + width;
		y1 := position.y - yoff + height;
		bl := Vec2{x0, y0};
		tr := Vec2{x1, y1};

		push_quad(shader_text, bl, tr, sprite, color);

		cur_x += (pixel_width * pixel_matrix[0][0]);
	}

	width := cur_x - position.x;
	return width;
}

flush_debug_lines :: inline proc() {
	for line in debug_lines {
		push_vertex(shader_rgba, 0, line.a, Vec2{}, line.color);
		push_vertex(shader_rgba, 0, line.b, Vec2{}, line.color);
	}

	draw_flush(LINES);
	clear(&debug_lines);
}

draw_flush :: proc(mode : u32 = TRIANGLES, loc := #caller_location) {
	if len(queued_for_drawing) == 0 {
		return;
	}

	program := get_current_shader();
	uniform_matrix4fv(program, "transform", 1, false, &transform_matrix[0][0]);

	// don't need this?
	// bind_buffer(vbo);

	// TODO: investigate STATIC_DRAW vs others
	BufferData(ARRAY_BUFFER, size_of(Vertex_Type) * len(queued_for_drawing), &queued_for_drawing[0], STATIC_DRAW);

	uniform(program, "atlas_texture", 0);

	DrawArrays(mode, 0, cast(i32)len(queued_for_drawing));

	clear(&queued_for_drawing);
}

//
// Game loop stuff
//

DT : f32 = 1.0 / 60;

frame_count: u64;
time: f32;
last_delta_time: f32;
fps_to_draw: f32;

start_game_loop :: proc(update: proc(f32) -> bool, render: proc()) {
	acc: f32;

	game_loop:
	for !window_should_close(main_window) {
		frame_start := win32.time_get_time();

		last_time := time;
		time = cast(f32)glfw.GetTime();
		last_delta_time = time - last_time;

		acc += last_delta_time;
		for acc >= DT {
			frame_count += 1;
			acc -= DT;
			update_input();
			if !update(DT) do break game_loop;
		}

		Clear(COLOR_BUFFER_BIT);
		render();
		draw_flush();

		flush_debug_lines();

		frame_end := win32.time_get_time();
		glfw.SwapBuffers(main_window);
		log_gl_errors("after SwapBuffers()");
	}
}

STARTING_FONT_PIXEL_DIM :: 256;

Font :: struct {
	dim: int,
	size: f32,
	chars: []stbtt.Baked_Char,
	id: Texture,
}

load_font :: proc(path: string, size: f32) -> (^Font, bool) {
	data, ok := os.read_entire_file(path);
	if !ok {
		logln("Couldn't open font: ", path);
		return nil, false;
	}
	defer free(data);

	pixels: []u8;
	chars:  []stbtt.Baked_Char;
	dim := STARTING_FONT_PIXEL_DIM;

	// @InfiniteLoop
	for {
		pixels = make([]u8, dim * dim);
		ret: int;
		chars, ret = stbtt.bake_font_bitmap(data, 0, size, pixels, dim, dim, 0, 128);
		if ret < 0 {
			free(pixels);
			dim *= 2;
		}
		else {
			break;
		}
	}

	texture := gen_texture();
	set_texture(texture);
    TexParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, LINEAR);
    TexParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, LINEAR);
	TexImage2D(TEXTURE_2D, 0, RGBA, cast(i32)dim, cast(i32)dim, 0, RED, UNSIGNED_BYTE, &pixels[0]);

	font := new_clone(Font{dim, size, chars, texture});
	return font, true;
}

destroy_font :: inline proc(font: ^Font) {
	free(font.chars);
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
	TexImage2D(TEXTURE_2D, 0, RGBA, ATLAS_DIM, ATLAS_DIM, 0, RGBA, UNSIGNED_BYTE, nil);

	data := new_clone(Texture_Atlas{texture, 0, 0, 0});

	return data;
}

destroy_atlas :: inline proc(atlas: ^Texture_Atlas) {
	delete_texture(atlas.id);
	free(atlas);
}

load_sprite :: proc(filepath: string, texture: ^Texture_Atlas) -> (Sprite, bool) {
	stbi.set_flip_vertically_on_load(1);
	sprite_width, sprite_height, channels: i32;
	pixel_data := stbi.load(&filepath[0], &sprite_width, &sprite_height, &channels, 0);
	if pixel_data == nil {
		logln("Couldn't load sprite: ", filepath);
		return Sprite{}, false;
	}

	defer stbi.image_free(pixel_data);

	set_texture(texture.id);

	if texture.atlas_x + sprite_width > ATLAS_DIM {
		texture.atlas_y += texture.biggest_height;
		texture.biggest_height = 0;
		texture.atlas_x = 0;
	}

	if sprite_height > texture.biggest_height do texture.biggest_height = sprite_height;
	TexSubImage2D(TEXTURE_2D, 0, texture.atlas_x, texture.atlas_y, sprite_width, sprite_height, RGBA, UNSIGNED_BYTE, pixel_data);
	TexParameteri(TEXTURE_2D, TEXTURE_WRAP_S, MIRRORED_REPEAT);
	TexParameteri(TEXTURE_2D, TEXTURE_WRAP_T, MIRRORED_REPEAT);
	TexParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, NEAREST);
	TexParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, NEAREST);
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

	texture.atlas_x += sprite_height;

	sprite := Sprite{coords, cast(f32)sprite_width / PIXELS_PER_WORLD_UNIT, cast(f32)sprite_height / PIXELS_PER_WORLD_UNIT, texture.id};
	return sprite, true;
}

main :: proc() {

}