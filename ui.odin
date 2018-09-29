package workbench

using import "core:runtime"
using import "core:math"
using import "core:fmt"
      import "core:mem"
      import "core:strings"
      import "core:os"

      import odingl "shared:odin-gl"
      import imgui "shared:odin-imgui"

//
// UI state
//

IMGUI_ID :: int;
id_counts: map[string]int;

hot:     IMGUI_ID = -1;
warm:    IMGUI_ID = -1;
previously_hot:  IMGUI_ID = -1;
previously_warm: IMGUI_ID = -1;
cursor_pixel_position_on_clicked: Vec2;

_update_ui :: proc() {
	mouse_in_rect :: inline proc(unit_rect: Rect(f32)) -> bool {
		cursor_in_rect := cursor_unit_position.y < unit_rect.y2 &&
		                  cursor_unit_position.y > unit_rect.y1 &&
		                  cursor_unit_position.x < unit_rect.x2 &&
		                  cursor_unit_position.x > unit_rect.x1;
		return cursor_in_rect;
	}

	previously_hot = -1;
	if get_mouse_up(Mouse.Left) {
		if hot != -1 {
			previously_hot = hot;
			hot = -1;
		}
	}

	previously_warm = -1;
	old_warm := warm;
	warm = -1;
	i := len(all_imgui_rects)-1;
	for i >= 0 {
		can_be_hot_or_warm :: inline proc(kind: IMGUI_Rect_Kind) -> bool {
			using IMGUI_Rect_Kind;
			switch kind {
				case  Button, Scroll_View: return true;
				case  Push_Rect, Text, Draw_Colored_Quad, Draw_Sprite, Fit_To_Aspect: return false;
				case: panic(tprint("Unsupported kind: ", kind));
			}
			return false;
		}

		defer i -= 1;
		rect := &all_imgui_rects[i];

		if can_be_hot_or_warm(rect.kind) {
			if warm == -1 {
				if mouse_in_rect(rect.unit_rect) {
					warm = rect.imgui_id;
				}
			}

			if warm == rect.imgui_id {
				if get_mouse_down(Mouse.Left) {
					hot = rect.imgui_id;
					cursor_pixel_position_on_clicked = cursor_screen_position;
				}
			}
		}
	}

	if warm != old_warm {
		previously_warm = old_warm;
	}

	// rendering_unit_space();
	// push_quad(shader_rgba, Vec2{0.1, 0.1}, Vec2{0.2, 0.2}, COLOR_BLUE, 100);

	clear(&id_counts);
	assert(len(ui_rect_stack) == 0 || len(ui_rect_stack) == 1);
	clear(&ui_rect_stack);
	clear(&new_imgui_rects);
	ui_current_rect_pixels = Pixel_Rect{};
	ui_current_rect_unit = Unit_Rect{};

	ui_push_rect(0, 0, 1, 1, 0, 0, 0, 0);
	// ui_push_rect(0.3, 0.3, 0.7, 0.7, 0, 0, 0, 0);
}

_late_update_ui :: proc() {
	all_imgui_rects, new_imgui_rects = new_imgui_rects, all_imgui_rects;
	clear(&new_imgui_rects);

	if debugging_ui {
		if imgui.begin("UI System") {
			defer imgui.end();

			if len(all_imgui_rects) > 0 {
				UI_Debug_Info :: struct {
					pushed_rects: i32,
				}

				debug := UI_Debug_Info{cast(i32)len(all_imgui_rects)};
				imgui_struct(&debug, "ui_debug_info");
				rect := all_imgui_rects[ui_debug_cur_idx];
				assert(rect.code_line == "");
				text, ok := ui_debug_get_file_line(rect.location.file_path, rect.location.line);
				rect.code_line = trim_whitespace(text);

				imgui_struct(&rect, "ui_element");

				for rect, i in all_imgui_rects {
					if ui_debug_cur_idx == i {
						imgui.bullet();
					}
					if imgui.small_button(tprintf("%s##%d", pretty_location(rect.location), i)) {
						ui_debug_cur_idx = i;
					}

					if ui_debug_cur_idx == i {
						min := Vec2{cast(f32)rect.pixel_rect.x1, cast(f32)rect.pixel_rect.y1};
						max := Vec2{cast(f32)rect.pixel_rect.x2, cast(f32)rect.pixel_rect.y2};
						draw_debug_box(pixel_to_viewport, to_vec3(min), to_vec3(max), COLOR_GREEN);

						ui_push_rect(0, 0.05, 1, 0.15);
						defer ui_pop_rect();
					}
				}
			}
		}
	}
}

Location_ID_Mapping :: struct {
	id: IMGUI_ID,
	using loc: Source_Code_Location,
	index: int,
}

all_imgui_mappings: [dynamic]Location_ID_Mapping;

get_imgui_id_from_location :: proc(loc: Source_Code_Location, loc2 := #caller_location) -> IMGUI_ID {
	count, ok := id_counts[loc.file_path];
	if !ok {
		id_counts[loc.file_path] = 0;
		count = 0;
	}
	else {
		count += 1;
		id_counts[loc.file_path] = count;
	}

	for val, idx in all_imgui_mappings {
		if val.line      != loc.line      do continue;
		if val.column    != loc.column    do continue;
		if val.index     != count         do continue;
		if val.file_path != loc.file_path do continue;
		return val.id;
	}

	id := len(all_imgui_mappings);
	mapping := Location_ID_Mapping{id, loc, count};
	append(&all_imgui_mappings, mapping);
	return mapping.id;
}

//
// Positioning
//

Rect :: struct(kind: typeid) {
	x1, y1, x2, y2: kind,
}

Pixel_Rect :: Rect(int);
Unit_Rect  :: Rect(f32);

IMGUI_Rect_Kind :: enum {
	Push_Rect,
	Draw_Colored_Quad,
	Draw_Sprite,
	Button,
	Fit_To_Aspect,
	Scroll_View,
	Text,
}

IMGUI_Rect :: struct {
	imgui_id:  IMGUI_ID,
	kind: IMGUI_Rect_Kind,
	code_line: string, // note(josh): not set for items in the system, only set right before drawing the UI debug window
	location: Source_Code_Location,

	pixel_rect: Pixel_Rect,
	unit_rect: Unit_Rect,
}

ui_rect_stack:   [dynamic]IMGUI_Rect;
all_imgui_rects: [dynamic]IMGUI_Rect;
new_imgui_rects: [dynamic]IMGUI_Rect;
ui_current_rect_unit:   Unit_Rect;
ui_current_rect_pixels: Pixel_Rect;

ui_push_rect :: inline proc(x1, y1, x2, y2: f32, top := 0, right := 0, bottom := 0, left := 0, rect_kind := IMGUI_Rect_Kind.Push_Rect, loc := #caller_location, pivot := Vec2{0.5, 0.5}) -> IMGUI_Rect {
	current_rect: Unit_Rect;
	if len(ui_rect_stack) == 0 {
		current_rect = Unit_Rect{0, 0, 1, 1};
	}
	else {
		current_rect = ui_current_rect_unit;
	}

	cur_w := current_rect.x2 - current_rect.x1;
	cur_h := current_rect.y2 - current_rect.y1;

	new_x1 := current_rect.x1 + (cur_w * x1) + ((cast(f32)left / cast(f32)current_window_width));
	new_y1 := current_rect.y1 + (cur_h * y1) + ((cast(f32)bottom / cast(f32)current_window_height));

	new_x2 := current_rect.x2 - cast(f32)cur_w * (1-x2) - ((cast(f32)right / cast(f32)current_window_width));
	new_y2 := current_rect.y2 - cast(f32)cur_h * (1-y2) - ((cast(f32)top / cast(f32)current_window_height));

	ui_current_rect_unit = Unit_Rect{new_x1, new_y1, new_x2, new_y2};
	if ui_current_rect_unit.x1 > 10000 {
		// logln(ui_current_rect_uniloc);
	}
	cww := current_window_width;
	cwh := current_window_height;
	ui_current_rect_pixels = Pixel_Rect{cast(int)(ui_current_rect_unit.x1 * cast(f32)cww), cast(int)(ui_current_rect_unit.y1 * cast(f32)cwh), cast(int)(ui_current_rect_unit.x2 * cast(f32)cww), cast(int)(ui_current_rect_unit.y2 * cast(f32)cwh)};

	rect := IMGUI_Rect{get_imgui_id_from_location(loc), rect_kind, "", loc, ui_current_rect_pixels, ui_current_rect_unit};
	append(&ui_rect_stack, rect);
	append(&new_imgui_rects, rect);
	return rect;
}

ui_pop_rect :: inline proc(loc := #caller_location) -> IMGUI_Rect {
	popped_rect := pop(&ui_rect_stack);
	rect := ui_rect_stack[len(ui_rect_stack)-1];
	ui_current_rect_pixels = rect.pixel_rect;
	ui_current_rect_unit = rect.unit_rect;
	return popped_rect;
}

//
// Drawing
//

ui_draw_colored_quad :: proc[ui_draw_colored_quad_current, ui_draw_colored_quad_push];
ui_draw_colored_quad_current :: inline proc(color: Colorf) {
	rect := ui_current_rect_pixels;
	min := Vec2{cast(f32)rect.x1, cast(f32)rect.y1};
	max := Vec2{cast(f32)rect.x2, cast(f32)rect.y2};
	push_quad(pixel_to_viewport, shader_rgba, to_vec3(min), to_vec3(max), color);
}
ui_draw_colored_quad_push :: inline proc(color: Colorf, x1, y1, x2, y2: f32, top := 0, right := 0, bottom := 0, left := 0, loc := #caller_location) {
	ui_push_rect(x1, y1, x2, y2, top, right, bottom, left, IMGUI_Rect_Kind.Draw_Colored_Quad, loc);
	ui_draw_colored_quad(color);
	ui_pop_rect(loc);
}

ui_draw_sprite :: proc[ui_draw_sprite_current, ui_draw_sprite_push];
ui_draw_sprite_current :: proc(sprite: Sprite, loc := #caller_location) {
	rect := ui_current_rect_pixels;
	min := Vec2{cast(f32)rect.x1, cast(f32)rect.y1};
	max := Vec2{cast(f32)rect.x2, cast(f32)rect.y2};
	push_quad(pixel_to_viewport, shader_texture, to_vec3(min), to_vec3(max), sprite);
}
ui_draw_sprite_push :: inline proc(sprite: Sprite, x1, y1, x2, y2: f32, top := 0, right := 0, bottom := 0, left := 0, loc := #caller_location) {
	ui_push_rect(x1, y1, x2, y2, top, right, bottom, left, IMGUI_Rect_Kind.Draw_Sprite, loc);
	ui_draw_sprite_current(sprite, loc);
	ui_pop_rect(loc);
}

//
// Text
//

Text_Data :: struct {
	font: ^Font,
	size: f32,
	color: Colorf,

	using shadow_params: struct {
		shadow: int, // in pixels, 0 for none
		shadow_color: Colorf,
	},

	center: bool,

	x1, y1, x2, y2: f32,
	top, right, bottom, left: int,
}

ui_text :: proc[ui_text_data, ui_text_args];
ui_text_data :: proc(str: string, using data: ^Text_Data, loc := #caller_location) {
	assert(font != nil, tprint(loc));

	ui_push_rect(x1, y1, x2, y2, top, right, bottom, left, IMGUI_Rect_Kind.Text, loc);
	defer ui_pop_rect(loc);

	position := Vec2{ui_current_rect_unit.x1, ui_current_rect_unit.y1};
	height := (ui_current_rect_unit.y2 - ui_current_rect_unit.y1) * current_window_height / font.size * size;

	if center {
		ww := get_string_width(font, str, height);
		rect_width  := (ui_current_rect_unit.x2 - ui_current_rect_unit.x1);
		rect_height := (ui_current_rect_unit.y2 - ui_current_rect_unit.y1);

		// text_size_to_rect := (font.size * size / (rect_height * current_window_height));
		// logln(text_size_to_rect);

		position = Vec2{ui_current_rect_unit.x1 + (rect_width  / 2) - ww/2,
						// ui_current_rect_unit.y1 + (rect_height / 2) - (text_size_to_rect)};
						ui_current_rect_unit.y1};
	}

	if shadow != 0 {
		draw_string(unit_to_viewport, font, str, position+Vec2{cast(f32)shadow/current_window_width, cast(f32)-shadow/current_window_width}, shadow_color, height, current_render_layer); // todo(josh): @TextRenderOrder: proper render order on text
	}

	draw_string(unit_to_viewport, font, str, position, color, height, current_render_layer); // todo(josh): @TextRenderOrder: proper render order on text
}
ui_text_args :: proc(font: ^Font, str: string, size: f32, color: Colorf, x1 := cast(f32)0, y1 := cast(f32)0, x2 := cast(f32)1, y2 := cast(f32)1, top := 0, right := 0, bottom := 0, left := 0, loc := #caller_location) {
	assert(font != nil);

	ui_push_rect(x1, y1, x2, y2, top, right, bottom, left, IMGUI_Rect_Kind.Text, loc);
	defer ui_pop_rect(loc);

	position := Vec2{cast(f32)ui_current_rect_unit.x1, cast(f32)ui_current_rect_unit.y1};
	height := (ui_current_rect_unit.y2 - ui_current_rect_unit.y1) * cast(f32)current_window_height / font.size;
	draw_string(unit_to_viewport, font, str, position, color, height * size, current_render_layer); // todo(josh): @TextRenderOrder: proper render order on text
}

//
// Buttons
//

Button_Data :: struct {
	x1, y1, x2, y2: f32,
	top, right, bottom, left: int,

	on_hover:    proc(button: ^Button_Data),
	on_pressed:  proc(button: ^Button_Data),
	on_released: proc(button: ^Button_Data),
	on_clicked:  proc(button: ^Button_Data),

	color: Colorf,
	clicked: u64,
}

default_button_data := Button_Data{0, 0, 1, 1, 0, 0, 0, 0, default_button_hover, default_button_pressed, default_button_released, nil, Colorf{0, 0, 0, 0}, 0};
default_button_hover :: proc(button: ^Button_Data) {

}
default_button_pressed :: proc(button: ^Button_Data) {
	TARGET_SIZE : f32 : 0.8;
	tween(&button.x1, (1-TARGET_SIZE)/2, 0.1, ease_out_quart);
	tween(&button.y1, (1-TARGET_SIZE)/2, 0.1, ease_out_quart);
	tween(&button.x2, 1-(1-TARGET_SIZE)/2, 0.1, ease_out_quart);
	tween(&button.y2, 1-(1-TARGET_SIZE)/2, 0.1, ease_out_quart);
}
default_button_released :: proc(button: ^Button_Data) {
	tween(&button.x1, 0, 0.25, ease_out_back);
	tween(&button.y1, 0, 0.25, ease_out_back);
	tween(&button.x2, 1, 0.25, ease_out_back);
	tween(&button.y2, 1, 0.25, ease_out_back);
}

ui_button :: proc(using button: ^Button_Data, str: string = "", text_data: ^Text_Data = nil, loc := #caller_location) -> bool {
	result: bool;

	clicked_this_frame := button.clicked == frame_count;
	if clicked_this_frame {
		if button.on_clicked != nil {
			button.on_clicked(button);
		}
		return true;
	}

	rect := ui_push_rect(x1, y1, x2, y2, top, right, bottom, left, IMGUI_Rect_Kind.Button, loc);
	defer ui_pop_rect(loc);

	// Draw button stuff
	ui_draw_colored_quad(color);

	// Draw text stuff
	if text_data != nil {
		if str == "" {
			panic(tprint(loc));
		}
		ui_text(str, text_data, loc);
	}

	if previously_hot == rect.imgui_id || (hot == rect.imgui_id && previously_warm == rect.imgui_id) {
		if button.on_released != nil do button.on_released(button);
	}

	if previously_hot == rect.imgui_id && warm == rect.imgui_id {
		result = true;
		if button.on_released != nil do button.on_released(button);
		if button.on_clicked  != nil do button.on_clicked(button);
	}

	if (hot == rect.imgui_id && get_mouse_down(Mouse.Left)) || (hot == rect.imgui_id && previously_warm != rect.imgui_id && warm == rect.imgui_id) {
		if button.on_pressed != nil do button.on_pressed(button);
	}

	return result;
}

ui_click :: inline proc(using button: ^Button_Data) {
	clicked = frame_count;
}

//
// Aspect Ratio Fitter
//

// todo(josh): not sure if the grow_forever_on_* feature is worth the complexity
ui_fit_to_aspect :: inline proc(ww, hh: f32, grow_forever_on_x := false, grow_forever_on_y := false, loc := #caller_location) {
	assert((grow_forever_on_x == false || grow_forever_on_y == false), "Cannot have grow_forever_on_y and grow_forever_on_x both be true.");

	current_rect_width_unit  := (ui_current_rect_unit.x2 - ui_current_rect_unit.x1);
	current_rect_height_unit := (ui_current_rect_unit.y2 - ui_current_rect_unit.y1);

	assert(current_rect_height_unit != 0);
	current_rect_aspect : f32 = (current_rect_height_unit * current_window_height) / (current_rect_width_unit * current_window_width);

	aspect := hh / ww;
	width:  f32;
	height: f32;
	if grow_forever_on_y || (!grow_forever_on_x && aspect < current_rect_aspect) {
		width  = current_rect_width_unit;
		height = current_rect_width_unit * aspect;
	}
	else if grow_forever_on_x || aspect >= current_rect_aspect {
		aspect = ww / hh;
		height = current_rect_height_unit;
		width  = current_rect_height_unit * aspect;
	}

	h_width  := cast(int)round(current_window_height * width  / 2);
	h_height := cast(int)round(current_window_height * height / 2);

	ui_push_rect(0.5, 0.5, 0.5, 0.5, -h_height, -h_width, -h_height, -h_width, IMGUI_Rect_Kind.Fit_To_Aspect, loc);
}

ui_end_fit_to_aspect :: inline proc(loc := #caller_location) {
	ui_pop_rect(loc);
}

//
// Scroll View
//

Scroll_View :: struct {
	min, max: f32,

	using _: struct { // runtime values
		cur_scroll_target: f32,
		cur_scroll_lerped: f32,
		scroll_at_pressed_position: f32,
	}
}

scroll_views: [dynamic]bool;
in_scroll_view: bool;

ui_scroll_view :: proc(sv: ^Scroll_View, x1: f32 = 0, y1: f32 = 0, x2: f32 = 1, y2: f32 = 1, top := 0, right := 0, bottom := 0, left := 0, loc := #caller_location) {
	append(&scroll_views, true);
	in_scroll_view = true;

	rect := ui_push_rect(x1, y1, x2, y2, top - cast(int)sv.cur_scroll_lerped, right, bottom + cast(int)sv.cur_scroll_lerped, left, IMGUI_Rect_Kind.Scroll_View, loc);
	id := rect.imgui_id;

	if hot == id {
		if get_mouse_down(Mouse.Left) {
			sv.scroll_at_pressed_position = sv.cur_scroll_target;
		}

		// if get_mouse(Mouse.Left) {
		// 	if abs(cursor_screen_position.y - cursor_pixel_position_on_clicked.y) > 0.005 {
		// 		hot = id;
		// 	}
		// }
		sv.cur_scroll_target = sv.scroll_at_pressed_position - (cursor_pixel_position_on_clicked.y - cursor_screen_position.y);
	}

	sv.cur_scroll_target = clamp(sv.cur_scroll_target, sv.min, sv.max);
	if warm == id {
		sv.cur_scroll_target -= cursor_scroll * 10;
	}
	sv.cur_scroll_lerped = lerp(sv.cur_scroll_lerped, sv.cur_scroll_target, 20 * client_target_delta_time);
}

ui_end_scroll_view :: proc(loc := #caller_location) {
	ui_pop_rect(loc);
	pop(&scroll_views);
	if len(scroll_views) > 0 {
		in_scroll_view = last(scroll_views)^;
	}
	else {
		in_scroll_view = false;
	}
}

//
// Directional Layout Groups
//

// Directional_Layout_Group :: struct {
// 	x1, y1, x2, y2: f32,
// 	origin: Vec2,
// 	direction: Vec2,
// 	using _: struct { // runtime fields
// 		num_items_so_far: int,
// 	},
// }

// direction_layout_group_next :: proc(dlg: ^Directional_Layout_Group) {
// 	rect := ui_pop_rect();
// }

//
// Grids
//

// Grid_Layout :: struct {
// 	w, h: int,

// 	using _: struct { // runtime fields
// 		cur_x, cur_y: int,
// 		// pixel padding, per element
// 		top, right, bottom, left: int,
// 	},
// }

// grid_start :: proc(ww, hh: int, x1, y1, x2, y2: f32, top := 0, right := 0, bottom := 0, left := 0) -> Grid_Layout {
// 	assert(ww == -1 || hh == -1 && ww != hh, "Can only pass a width _or_ a height, since we grow forever.");

// 	grid := Grid_Layout{ww, hh, {}};
// 	if grid.w == -1 {

// 	}
// 	else {
// 		assert(grid.h == -1, "???? We're supposed to protect against this in grid_start()");
// 	}
// 	return grid;
// }

// grid_next :: proc(grid: ^Grid_Layout) {
// 	if grid.w == -1 {
// 		grid.cur_h
// 	}
// 	else {
// 		assert(grid.h == -1, "???? We're supposed to protect against this in grid_start()");
// 	}
// }

// grid_start :: inline proc(grid: ^Grid_Layout) {
// 	ui_push_rect(0, 0, 1, 1); // doesn't matter, gets popped immediately

// 	grid.cur_x = 0;
// 	grid.cur_y = grid.h;

// 	grid_next(grid);
// }

// grid_next :: inline proc(grid: ^Grid_Layout) {
// 	grid.cur_y -= 1;
// 	if grid.cur_y == -1 {
// 		grid.cur_x += 1; // (grid.cur_x + 1) % grid.w;
// 		grid.cur_y = grid.h-1;
// 	}

// 	ui_pop_rect();
// 	x1 := cast(f32)grid.cur_x / cast(f32)grid.w;
// 	y1 := cast(f32)grid.cur_y / cast(f32)grid.h;
// 	ui_push_rect(x1, y1, x1 + 1.0 / cast(f32)grid.w, y1 + 1.0 / cast(f32)grid.h, grid.top, grid.right, grid.bottom, grid.left);
// }

// grid_end :: inline proc(grid: ^Grid_Layout) {
// 	ui_pop_rect();
// }

//
// UI debug information
//


ui_debug_cur_idx: int;
debugging_ui: bool;

UI_Debug_File_Line :: struct {
	file_path: string,
	line: int,
	text: string,
}

all_ui_debug_file_lines: [dynamic]UI_Debug_File_Line;

ui_debug_get_file_line :: proc(file_path: string, line: int) -> (string, bool) {
	for fl in all_ui_debug_file_lines {
		if fl.line == line && fl.file_path == file_path do return fl.text, true;
	}
	data, ok := os.read_entire_file(file_path);
	if !ok {
		return "", false;
	}
	defer delete(data);

	cur_line := 1;
	line_start := -1;
	for b, i in data {
		if b == '\n' {
			cur_line += 1;
			if cur_line == line {
				line_start = i;
			}
			else if cur_line == line + 1 {
				text := strings.new_string(cast(string)data[line_start:i]);
				fl := UI_Debug_File_Line{file_path, line, text};
				append(&all_ui_debug_file_lines, fl);
				return text, true;
			}
		}
	}
	return "", false;
}