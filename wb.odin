import "core:fmt.odin"
import "core:strings.odin"
import "core:mem.odin"
using import "core:math.odin"

import "shared:odin-glfw/glfw.odin"
import "shared:stb/image.odin"

import "gl.odin"
import "basic.odin"

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

set_camera_size :: proc(size: f32) {
	camera_size = size;
	_size_callback(main_window, current_window_width, current_window_height);
}

_size_callback :: proc"c"(main_window: glfw.Window_Handle, w, h: i32) {
	current_window_width = w;
	current_window_height = h;

	aspect := cast(f32)w / cast(f32)h;
	top := camera_size;
	bottom := -camera_size;
	left := -camera_size * aspect;
	right := camera_size * aspect;
	ortho := ortho3d(left, right, bottom, top, -1, 1);

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
	set_camera_size(config.camera_size);

	// Setup glfw callbacks
	glfw.SetScrollCallback(main_window,
		proc"c"(main_window: glfw.Window_Handle, x, y: f64) {
			set_camera_size(camera_size - cast(f32)y * camera_size * 0.1);
		});

	// setup vao
	vao = gl.gen_vao();
	gl.bind_vao(vao);

	vbo = gl.gen_buffer();
	gl.bind_buffer(vbo);

	// Position
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), nil);
	gl.EnableVertexAttribArray(0);

	// tex_coord
	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), rawptr(uintptr(offset_of(Vertex, tex_coord))));
	gl.EnableVertexAttribArray(1);

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
	v0 := Vertex{p0 - camera_position, sprite.uvs[0]};
	v1 := Vertex{p1 - camera_position, sprite.uvs[1]};
	v2 := Vertex{p2 - camera_position, sprite.uvs[2]};
	v3 := Vertex{p3 - camera_position, sprite.uvs[3]};

	quad := Quad{v0, v1, v2, v2, v3, v0};
	append(&all_quads, quad);
}

draw_sprite :: proc(sprite: Sprite, position, scale: Vec2) {
	make_vertex :: proc(corner, position, scale: Vec2, sprite: Sprite, index: int) -> Vertex {
		vpos := corner;
		vpos *= scale * Vec2{cast(f32)sprite.width, cast(f32)sprite.height} / 2;
		vpos -= camera_position;
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
	// TODO(josh): Handle multiple texture atlases?
	if !atlas_loaded {
		atlas_loaded = true;

		atlas_texture = gl.gen_texture();
		gl.bind_texture2d(atlas_texture);
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, ATLAS_DIM, ATLAS_DIM, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil);
	}

	filepath_c := basic.to_c_string(filepath);
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
		idx, ok := basic.find_from_right(location.file_path, '\\');
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
		fmt.println("cap of up", cap(_up), cap(_up_mid_frame));
		fmt.println("cap of down", cap(_down), cap(_down_mid_frame));
	}

	switch action {
		case glfw.Action.Press: {
			append(&_held_mid_frame, key);
			append(&_down_mid_frame, key);
		}
		case glfw.Action.Release: {
			basic.remove_all(&_held_mid_frame, key);
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

//
// Collision
//

closest_point_on_line :: proc(origin: Vec2, p1, p2: Vec2) -> Vec2 {
	direction := p2 - p1;
	square_length := basic.sqr_magnitude(direction);
	if (square_length == 0.0) {
		// p1 == p2
		dir_from_point := p1 - origin;
		return p1;
	}

	dot := dot(origin - p1, p2 - p1) / square_length;
	t := max(min(dot, 1), 0);
	projection := p1 + t * (p2 - p1);
	return projection;
}

// todo(josh): there is currently an assertion failure in the compiler related
// to the builtin min() and max() procs. remove these when that is fixed
min :: inline proc(a, b: $T) -> T {
	if a < b do return a;
	return b;
}

max :: inline proc(a, b: $T) -> T {
	if a > b do return a;
	return b;
}

Hit_Info :: struct {
	// Fraction (0..1) of the distance that the ray started intersecting
	fraction0: f32,
	// Fraction (0..1) of the distance that the ray stopped intersecting
	fraction1: f32,

	// Point that the ray started intersecting
	point0: Vec2,
	// Point that the ray stopped intersecting
	point1: Vec2,

	// todo(josh): add normals
}

cast_box_circle :: proc(box_min, box_max: Vec2, box_direction: Vec2, circle_position: Vec2, circle_radius: f32) -> (bool, Hit_Info) {
	// todo(josh)
	return false, Hit_Info{};
}

cast_circle_box :: proc(circle_origin, circle_direction: Vec2, circle_radius: f32, box_min, box_max: Vec2) -> (bool, Hit_Info) {
	compare_hits :: proc(source: ^Hit_Info, other: Hit_Info) {
		if other.fraction0 < source.fraction0 {
			source.fraction0 = other.fraction0;
			source.point0    = other.point0;
		}

		if other.fraction1 > source.fraction1 {
			source.fraction1 = other.fraction1;
			source.point1    = other.point1;
		}
	}

	tl := Vec2{box_min.x, box_max.y};
	tr := Vec2{box_max.x, box_max.y};
	br := Vec2{box_max.x, box_min.y};
	bl := Vec2{box_min.x, box_min.y};

	// Init with fraction fields at extremes for comparisons
	final_hit_info: Hit_Info;
	final_hit_info.fraction0 = 1;
	final_hit_info.fraction1 = 0;

	did_hit := false;

	// Corner circle checks
	{
		circle_positions := [4]Vec2{tl, tr, br, bl};
		for pos in circle_positions {
			hit, info := cast_line_circle(circle_origin, circle_direction, pos, circle_radius);
			if hit {
				did_hit = true;
				compare_hits(&final_hit_info, info);
			}
		}
	}

	// Center box checks
	{
		// box0 is tall box, box1 is wide box
		box0_min := box_min - Vec2{0, circle_radius};
		box0_max := box_max + Vec2{0, circle_radius};

		box1_min := box_min - Vec2{circle_radius, 0};
		box1_max := box_max + Vec2{circle_radius, 0};

		hit0, info0 := cast_line_box(circle_origin, circle_direction, box0_min, box0_max);
		if hit0 {
			did_hit = true;
			compare_hits(&final_hit_info, info0);
		}

		hit1, info1 := cast_line_box(circle_origin, circle_direction, box1_min, box1_max);
		if hit1 {
			did_hit = true;
			compare_hits(&final_hit_info, info1);
		}
	}

	return did_hit, final_hit_info;
}

cast_line_circle :: proc(line_origin, line_direction: Vec2, circle_center: Vec2, circle_radius: f32) -> (bool, Hit_Info) {
	direction := line_origin - circle_center;
	a := dot(line_direction, line_direction);
	b := dot(direction, line_direction);
	c := dot(direction, direction) - circle_radius * circle_radius;

	disc := b * b - a * c;
	if (disc < 0) {
		return false, Hit_Info{};
	}

	sqrt_disc := sqrt(disc);
	invA: f32 = 1.0 / a;

	tmin := (-b - sqrt_disc) * invA;
	tmax := (-b + sqrt_disc) * invA;
	tmax = min(tmax, 1);

	inv_radius: f32 = 1.0 / circle_radius;

	pmin := line_origin + tmin * line_direction;
	// normal[i] = (point[i] - circle_center) * invRadius;

	pmax := line_origin + tmax * line_direction;
	// normal[i] = (point[i] - circle_center) * invRadius;

	info := Hit_Info{tmin, tmax, pmin, pmax};

	return true, info;
}

cast_line_box :: proc(line_origin, line_direction: Vec2, box_min, box_max: Vec2) -> (bool, Hit_Info) {
	inverse := Vec2{1.0/line_direction.x, 1.0/line_direction.y};

	tx1 := (box_min.x - line_origin.x)*inverse.x;
	tx2 := (box_max.x - line_origin.x)*inverse.x;

	tmin := min(tx1, tx2);
	tmax := max(tx1, tx2);

	ty1 := (box_min.y - line_origin.y)*inverse.y;
	ty2 := (box_max.y - line_origin.y)*inverse.y;

	tmin = max(tmin, min(ty1, ty2));
	tmax = min(tmax, max(ty1, ty2));
	tmax = min(tmax, 1);

	info := Hit_Info{tmin, tmax, line_origin + (line_direction * tmin), line_origin + (line_direction * tmax)};

	return tmax >= tmin, info;
}

overlap_point_box :: inline proc(origin: Vec2, box_min, box_max: Vec2) -> bool {
	return origin.x < box_max.x
		&& origin.x > box_min.x
		&& origin.y < box_max.y
		&& origin.y > box_min.y;
}

overlap_point_circle :: inline proc(origin: Vec2, circle_position: Vec2, circle_radius: f32) -> bool {
	return basic.sqr_magnitude(origin - circle_position) < basic.sqr(circle_radius);
}
