      import       "core:fmt.odin"
      import       "core:strings.odin"
      import       "core:mem.odin"
      import       "core:os.odin"

      import stbi  "shared:odin-stb/stb_image.odin"
      import stbiw "shared:odin-stb/stb_image_write.odin"
      import stbtt "shared:odin-stb/stb_truetype.odin"

      import       "glfw.odin"

      export       "types.odin"
      export       "collision.odin"
      export       "gl.odin"
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

when DEVELOPER {
	unflushed_draws_warning :: proc(procedure: string, location: Source_Code_Location) {
		log("WARNING: Call to ", procedure, "() at ", file_from_path(location.file_path), ":", location.line, " but there are unflushed draws.");
	}
}

rendering_world_space :: proc(location := #caller_location) {
	when DEVELOPER {
		if len(queued_for_drawing) > 0 do unflushed_draws_warning(#procedure, location);
	}

	transform_matrix = mul(identity(Mat4), ortho_matrix);
	transform_matrix = scale(transform_matrix, 1.0 / camera_size);

	cam_offset := to_vec3(mul(transform_matrix, to_vec4(camera_position)));
	transform_matrix = translate(transform_matrix, -cam_offset);

	pixel_matrix = identity(Mat4);
	pixel_matrix = scale(pixel_matrix, 1.0 / PPU);
}

rendering_unit_space :: proc(location := #caller_location) {
	when DEVELOPER {
		if len(queued_for_drawing) > 0 do unflushed_draws_warning(#procedure, location);
	}

	transform_matrix = identity(Mat4);
	transform_matrix = translate(transform_matrix, Vec3{-1, -1, 0});
	transform_matrix = scale(transform_matrix, 2);

	pixel_matrix = identity(Mat4);
	pixel_matrix = scale(pixel_matrix, Vec3{1.0 / cast(f32)current_window_width, 1.0 / cast(f32)current_window_height, 0});
}

rendering_pixel_space :: proc(location := #caller_location) {
	when DEVELOPER {
		if len(queued_for_drawing) > 0 do unflushed_draws_warning(#procedure, location);
	}

	transform_matrix = identity(Mat4);
	transform_matrix = scale(transform_matrix, to_vec3(Vec2{1.0 / cast(f32)current_window_width, 1.0 / cast(f32)current_window_height}));
	transform_matrix = translate(transform_matrix, Vec3{-1, -1, 0});
	transform_matrix = scale(transform_matrix, 2);

	pixel_matrix = identity(Mat4);
}

set_shader :: inline proc(program: Shader_Program, location := #caller_location) {
	when DEVELOPER {
		if len(queued_for_drawing) > 0 do unflushed_draws_warning(#procedure, location);
	}

	use_program(program);
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
		cursor_screen_position = Vec2{cast(f32)x, cast(f32)y};
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

	// setup opengl
	load_up_to(cast(int)opengl_version_major, cast(int)opengl_version_minor,
		proc(p: rawptr, name: string) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
		});

	// Set initial size of window
	glfw_size_callback(main_window, window_width, window_height);

	// Setup glfw callbacks
	glfw.SetScrollCallback(main_window, glfw_scroll_callback);
}

vao: VAO;
vbo: VBO;

Vertex :: struct {
	vertex_position: Vec2,
	tex_coord: Vec2,
	color: Colorf,
}

init_opengl :: proc() {
	vao = gen_vao();
	bind_vao(vao);

	vbo = gen_buffer();
	bind_buffer(vbo);

	set_vertex_format(Vertex);

	ClearColor(0.2, 0.5, 0.8, 1.0);
	Enable(BLEND);
	BlendFunc(SRC_ALPHA, ONE_MINUS_SRC_ALPHA);
}

Quad :: [6]Vertex;

queued_for_drawing: [dynamic]Vertex;

Sprite :: struct {
	uvs: [4]Vec2,
	width: i32,
	height: i32,
}

COLOR_WHITE := Colorf{1, 1, 1, 1};
COLOR_BLACK := Colorf{0, 0, 0, 1};
COLOR_RED   := Colorf{1, 0, 0, 1};
COLOR_GREEN := Colorf{0, 1, 0, 1};
COLOR_BLUE  := Colorf{0, 0, 1, 1};

draw_quad :: proc[draw_quad_min_max_color, draw_quad_min_max_sprite, draw_quad_min_max_sprite_color,
                  draw_quad_points_color,  draw_quad_points_sprite,  draw_quad_points_sprite_color];

draw_quad_min_max_color :: inline proc(min, max: Vec2, color: Colorf) {
	_draw_quad(min, Vec2{min.x, max.y}, max, Vec2{max.x, min.y}, Sprite{}, color);
}
draw_quad_min_max_sprite :: inline proc(min, max: Vec2, sprite: Sprite) {
	_draw_quad(min, Vec2{min.x, max.y}, max, Vec2{max.x, min.y}, sprite, COLOR_WHITE);
}
draw_quad_min_max_sprite_color :: inline proc(min, max: Vec2, sprite: Sprite, color: Colorf) {
	_draw_quad(min, Vec2{min.x, max.y}, max, Vec2{max.x, min.y}, sprite, color);
}

draw_quad_points_color :: inline proc(p0, p1, p2, p3: Vec2, color: Colorf) {
	_draw_quad(p0, p1, p2, p3, Sprite{}, color);
}
draw_quad_points_sprite :: inline proc(p0, p1, p2, p3: Vec2, sprite: Sprite) {
	_draw_quad(p0, p1, p2, p3, sprite, COLOR_WHITE);
}
draw_quad_points_sprite_color :: inline proc(p0, p1, p2, p3: Vec2, sprite: Sprite, color: Colorf) {
	_draw_quad(p0, p1, p2, p3, sprite, color);
}

_draw_quad :: proc(p0, p1, p2, p3: Vec2, sprite: Sprite, color: Colorf) {
	v0 := Vertex{p0, sprite.uvs[0], color};
	v1 := Vertex{p1, sprite.uvs[1], color};
	v2 := Vertex{p2, sprite.uvs[2], color};
	v3 := Vertex{p3, sprite.uvs[3], color};
	append(&queued_for_drawing, v0);
	append(&queued_for_drawing, v1);
	append(&queued_for_drawing, v2);
	append(&queued_for_drawing, v2);
	append(&queued_for_drawing, v3);
	append(&queued_for_drawing, v0);
}

draw_vertex :: proc(position: Vec2, color: Colorf) {
	vertex := Vertex{position, Vec2{}, color};
	append(&queued_for_drawing, vertex);
}

draw_flush :: proc() {
	if len(queued_for_drawing) == 0 do return;

	_draw_flush_with_texture(atlas_texture);
}

swap_buffers :: inline proc() {
	glfw.SwapBuffers(main_window);
}

get_size_ratio_for_font :: inline proc(font: Font, _size: f32) -> f32 {
	size := _size / 2; // not sure why this is necessary but the text was being drawn twice as big as it should be
	pixel_size := mul(transform_matrix, Vec4{0, size, 0, 0}).y;
	pixel_size *= cast(f32)current_window_height;
	size_ratio := pixel_size / font.size;
	return size_ratio;
}

get_string_width :: proc(str: string, font: Font, size: f32) -> f32 {
	size_ratio := get_size_ratio_for_font(font, size);
	cur_width : f32 = 0;
	for c in str {
		pixel_width, _, quad := stbtt.get_baked_quad(font.chars, font.dim, font.dim, cast(int)c, true);
		pixel_width *= size_ratio;
		cur_width += (pixel_width * pixel_matrix[0][0]);
	}

	return cur_width;
}

// todo(josh): make this not be a draw call per call to draw_string()
draw_string :: proc(str: string, font: Font, position: Vec2, color: Colorf, size: f32, silent := false) -> f32 {
	size_ratio := get_size_ratio_for_font(font, size);
	cur_x := position.x;
	for c in str {
		pixel_width, _, quad := stbtt.get_baked_quad(font.chars, font.dim, font.dim, cast(int)c, true);
		pixel_width *= size_ratio;

		if !silent {
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
			sprite := Sprite{{uv0, uv1, uv2, uv3}, 0, 0};

			x0 := cur_x + start;
			y0 := position.y - yoff;
			x1 := cur_x + start + width;
			y1 := position.y - yoff + height;
			bl := Vec2{x0, y0};
			tr := Vec2{x1, y1};

			draw_quad(bl, tr, sprite, color);
		}

		cur_x += (pixel_width * pixel_matrix[0][0]);
	}

	if !silent {
		_draw_flush_with_texture(font.texture);
	}

	width := cur_x - position.x;
	return width;
}

_draw_flush_with_texture :: proc(texture: Texture) {
	program := get_current_shader();
	uniform_matrix4fv(program, "transform", 1, false, &transform_matrix[0][0]);

	bind_buffer(vbo);
	BufferData(ARRAY_BUFFER, size_of(Vertex) * len(queued_for_drawing), &queued_for_drawing[0], STATIC_DRAW);

	uniform(program, "atlas_texture", 0);
	bind_texture2d(texture);

	DrawArrays(TRIANGLES, 0, cast(i32)len(queued_for_drawing));

	clear(&queued_for_drawing);
}

STARTING_FONT_PIXEL_DIM :: 256;

Font :: struct {
	dim: int,
	size: f32,
	chars: []stbtt.Baked_Char,
	texture: Texture,
}

load_font :: proc(path: string, size: f32) -> (Font, bool) {
	data, ok := os.read_entire_file(path);
	if !ok {
		log("Couldn't open font: ", path);
		return Font{}, false;
	}
	defer free(data);

	pixels: []u8;
	chars:  []stbtt.Baked_Char;
	dim := STARTING_FONT_PIXEL_DIM;
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
	bind_texture2d(texture);
    TexParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, LINEAR);
    TexParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, LINEAR);
	TexImage2D(TEXTURE_2D, 0, RGBA, cast(i32)dim, cast(i32)dim, 0, RED, UNSIGNED_BYTE, &pixels[0]);

	return Font{dim, size, chars, texture}, true;
}

atlas_texture: Texture;
atlas_loaded: bool;

atlas_x: i32;
atlas_y: i32;
biggest_height: i32;

ATLAS_DIM :: 2048;

PPU :: 64;

load_sprite :: proc(filepath: string) -> (Sprite, bool) {
	// todo(josh): Handle multiple texture atlases
	if !atlas_loaded {
		atlas_loaded = true;

		atlas_texture = gen_texture();
		bind_texture2d(atlas_texture);
		TexImage2D(TEXTURE_2D, 0, RGBA, ATLAS_DIM, ATLAS_DIM, 0, RGBA, UNSIGNED_BYTE, nil);
	}

	stbi.set_flip_vertically_on_load(1);
	sprite_width, sprite_height, channels: i32;
	texture_data := stbi.load(&filepath[0], &sprite_width, &sprite_height, &channels, 0);
	if texture_data == nil {
		log("Couldn't load sprite: ", filepath);
		return Sprite{}, false;
	}

	bind_texture2d(atlas_texture);

	if atlas_x + sprite_width > ATLAS_DIM {
		atlas_y += biggest_height;
		biggest_height = 0;
		atlas_x = 0;
	}

	if sprite_height > biggest_height do biggest_height = sprite_height;
	TexSubImage2D(TEXTURE_2D, 0, atlas_x, atlas_y, sprite_width, sprite_height, RGBA, UNSIGNED_BYTE, texture_data);
	TexParameteri(TEXTURE_2D, TEXTURE_WRAP_S, MIRRORED_REPEAT);
	TexParameteri(TEXTURE_2D, TEXTURE_WRAP_T, MIRRORED_REPEAT);
	TexParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, NEAREST);
	TexParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, NEAREST);
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

	sprite := Sprite{coords, sprite_width / PPU, sprite_height / PPU};
	return sprite, true;
}

//
// Input stuff
//

Key_Press :: struct {
	input: union { glfw.Key, glfw.Mouse },
	time: f64,
}

_held := make([dynamic]Key_Press, 0, 5);
_down := make([dynamic]Key_Press, 0, 5);
_up   := make([dynamic]Key_Press, 0, 5);

_held_mid_frame := make([dynamic]Key_Press, 0, 5);
_down_mid_frame := make([dynamic]Key_Press, 0, 5);
_up_mid_frame   := make([dynamic]Key_Press, 0, 5);

_mouse_held := make([dynamic]Key_Press, 0, 5);
_mouse_down := make([dynamic]Key_Press, 0, 5);
_mouse_up   := make([dynamic]Key_Press, 0, 5);

_mouse_held_mid_frame := make([dynamic]Key_Press, 0, 5);
_mouse_down_mid_frame := make([dynamic]Key_Press, 0, 5);
_mouse_up_mid_frame   := make([dynamic]Key_Press, 0, 5);

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


	clear(&_mouse_held);
	clear(&_mouse_down);
	clear(&_mouse_up);

	for held in _mouse_held_mid_frame {
		append(&_mouse_held, held);
	}
	for down in _mouse_down_mid_frame {
		append(&_mouse_down, down);
	}
	for up in _mouse_up_mid_frame {
		append(&_mouse_up, up);
	}

	clear(&_mouse_down_mid_frame);
	clear(&_mouse_up_mid_frame);
}


// this callback CAN be called during a frame, outside of the glfw.PollEvents() call, on some platforms
// so we need to save presses in a separate buffer and copy them over to have consistent behaviour
_glfw_key_callback :: proc"c"(window: glfw.Window_Handle, key: glfw.Key, scancode: i32, action: glfw.Action, mods: i32) {
	when false
	{
		fmt.println("------------------------------");
		fmt.println("len of held", len(_held), len(_held_mid_frame));
		fmt.println("len of up",   len(_up),   len(_up_mid_frame));
		fmt.println("len of down", len(_down), len(_down_mid_frame));

		fmt.println("cap of held", cap(_held), cap(_held_mid_frame));
		fmt.println("cap of up",   cap(_up),   cap(_up_mid_frame));
		fmt.println("cap of down", cap(_down), cap(_down_mid_frame));
	}

	switch action {
		case glfw.Action.Press: {
			append(&_held_mid_frame, Key_Press{key, glfw.GetTime()});
			append(&_down_mid_frame, Key_Press{key, glfw.GetTime()});
		}
		case glfw.Action.Release: {
			idx := -1;
			for held, i in _held_mid_frame {
				if held.input.(glfw.Key) == key {
					idx = i;
					break;
				}
			}
			assert(idx != -1);
			remove_by_index(&_held_mid_frame, idx);
			append(&_up_mid_frame, Key_Press{key, glfw.GetTime()});
		}
	}
}

_glfw_mouse_button_callback :: proc"c"(window: glfw.Window_Handle, button: glfw.Mouse, action: glfw.Action, mods: i32) {
	switch action {
		case glfw.Action.Press: {
			append(&_mouse_held_mid_frame, Key_Press{button, glfw.GetTime()});
			append(&_mouse_down_mid_frame, Key_Press{button, glfw.GetTime()});
		}
		case glfw.Action.Release: {
			idx := -1;
			for held, i in _mouse_held_mid_frame {
				if held.input.(glfw.Mouse) == button {
					idx = i;
					break;
				}
			}
			assert(idx != -1);
			remove_by_index(&_mouse_held_mid_frame, idx);
			append(&_mouse_up_mid_frame, Key_Press{button, glfw.GetTime()});
		}
	}
}

get_mouse :: proc(mouse: glfw.Mouse) -> bool {
	for mouse_held in _mouse_held {
		if mouse_held.input.(glfw.Mouse) == mouse {
			return true;
		}
	}
	return false;
}

get_mouse_down :: proc(mouse: glfw.Mouse) -> bool {
	for mouse_down in _mouse_down {
		if mouse_down.input.(glfw.Mouse) == mouse {
			return true;
		}
	}
	return false;
}

get_mouse_up :: proc(mouse: glfw.Mouse) -> bool {
	for mouse_up in _mouse_up {
		if mouse_up.input.(glfw.Mouse) == mouse {
			return true;
		}
	}
	return false;
}

get_key :: proc(key: glfw.Key) -> bool {
	for held in _held {
		if held.input.(glfw.Key) == key {
			return true;
		}
	}
	return false;
}

get_key_down :: proc(key: glfw.Key) -> bool {
	for down in _down {
		if down.input.(glfw.Key) == key {
			return true;
		}
	}
	return false;
}

get_key_up :: proc(key: glfw.Key) -> bool {
	for up in _up {
		if up.input.(glfw.Key) == key {
			return true;
		}
	}
	return false;
}

main :: proc() {

}