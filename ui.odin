package workbench

using import "core:runtime"
using import "core:math"
using import "core:fmt"
      import "core:mem"

//
// IMGUI Controls
//
hot:  IMGUI_ID = -1;
warm: IMGUI_ID = -1;

IMGUI_ID :: int;

id_counts: map[string]int;

all_imgui_mappings: [dynamic]Location_ID_Mapping;

Location_ID_Mapping :: struct {
	id: IMGUI_ID,
	using loc: Source_Code_Location,
	index: int,
}

update_ui :: proc(dt: f32) {
	clear(&id_counts);
}

get_id_from_location :: proc(loc: Source_Code_Location) -> IMGUI_ID {
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
		if val.line != loc.line do continue;
		if val.column != loc.column do continue;
		if val.index != count do continue;
		if val.file_path != loc.file_path do continue;
		return val.id;
	}

	id := len(all_imgui_mappings);
	mapping := Location_ID_Mapping{id, loc, count};
	append(&all_imgui_mappings, mapping);
	return id;
}

//
// Positioning
//
Rect :: struct(kind: type) {
	x1, y1, x2, y2: kind,
}

Pixel_Rect :: Rect(int);
Unit_Rect  :: Rect(f32);

UI_Rect :: struct {
	pixel_rect: Pixel_Rect,
	unit_rect: Unit_Rect,
}

ui_rect_stack: [dynamic]UI_Rect;
ui_current_rect_unit:   Unit_Rect;
ui_current_rect_pixels: Pixel_Rect;

ui_push_rect :: inline proc(x1, y1, x2, y2: f32, top := 0, right := 0, bottom := 0, left := 0) {
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
	cww := current_window_width;
	cwh := current_window_height;
	ui_current_rect_pixels = Pixel_Rect{cast(int)(ui_current_rect_unit.x1 * cast(f32)cww), cast(int)(ui_current_rect_unit.y1 * cast(f32)cwh), cast(int)(ui_current_rect_unit.x2 * cast(f32)cww), cast(int)(ui_current_rect_unit.y2 * cast(f32)cwh)};

	append(&ui_rect_stack, UI_Rect{ui_current_rect_pixels, ui_current_rect_unit});
}

ui_pop_rect :: inline proc() {
	pop(&ui_rect_stack);
	rect := ui_rect_stack[len(ui_rect_stack)-1];
	ui_current_rect_pixels = rect.pixel_rect;
	ui_current_rect_unit = rect.unit_rect;
}

// todo(josh): not sure if the grow_forever_on_* feature is worth the complexity
ui_fit_to_aspect :: inline proc(ww, hh: f32, grow_forever_on_x := false, grow_forever_on_y := false) {
	assert((grow_forever_on_x == false || grow_forever_on_y == false), "Cannot have grow_forever_on_y and grow_forever_on_x both be true.");

	current_rect_width  := (cast(f32)ui_current_rect_pixels.x2 - cast(f32)ui_current_rect_pixels.x1);
	current_rect_height := (cast(f32)ui_current_rect_pixels.y2 - cast(f32)ui_current_rect_pixels.y1);

	assert(current_rect_height != 0);
	current_rect_aspect : f32 = cast(f32)(ui_current_rect_pixels.y2 - ui_current_rect_pixels.y1) / cast(f32)(ui_current_rect_pixels.x2 - ui_current_rect_pixels.x1);

	aspect := hh / ww;
	width:  f32;
	height: f32;
	if grow_forever_on_y || (!grow_forever_on_x && aspect < current_rect_aspect) {
		width  = current_rect_width;
		height = current_rect_width * aspect;
	}
	else if grow_forever_on_x || aspect >= current_rect_aspect {
		aspect = ww / hh;
		height = current_rect_height;
		width  = current_rect_height * aspect;
	}

	h_width  := cast(int)round(width  / 2);
	h_height := cast(int)round(height / 2);

	ui_push_rect(0.5, 0.5, 0.5, 0.5, -h_height, -h_width, -h_height, -h_width);
}

ui_end_fit_to_aspect :: inline proc() {
	ui_pop_rect();
}

//
// Grids
//

Grid_Layout :: struct {
	w, h: int,
	cur_x, cur_y: int,

	// pixel padding, per element
	top, right, bottom, left: int,
}

grid_start :: inline proc(grid: ^Grid_Layout) {
	ui_push_rect(0, 0, 1, 1); // doesn't matter, gets popped immediately

	grid.cur_x = 0;
	grid.cur_y = grid.h;

	grid_next(grid);
}

grid_next :: inline proc(grid: ^Grid_Layout) {
	grid.cur_y -= 1;
	if grid.cur_y == -1 {
		grid.cur_x += 1; // (grid.cur_x + 1) % grid.w;
		grid.cur_y = grid.h-1;
	}

	ui_pop_rect();
	x1 := cast(f32)grid.cur_x / cast(f32)grid.w;
	y1 := cast(f32)grid.cur_y / cast(f32)grid.h;
	ui_push_rect(x1, y1, x1 + 1.0 / cast(f32)grid.w, y1 + 1.0 / cast(f32)grid.h, grid.top, grid.right, grid.bottom, grid.left);
}

grid_end :: inline proc() {
	ui_pop_rect();
}

//
// Drawing
//

ui_draw_colored_quad :: proc[ui_draw_colored_quad_current, ui_draw_colored_quad_push];
ui_draw_colored_quad_current :: inline proc(color: Colorf) {
	rendering_pixel_space();
	rect := ui_current_rect_pixels;

	min := Vec2{cast(f32)rect.x1, cast(f32)rect.y1};
	max := Vec2{cast(f32)rect.x2, cast(f32)rect.y2};

	push_quad(shader_rgba, min, max, color);
}
ui_draw_colored_quad_push :: inline proc(color: Colorf, x1, y1, x2, y2: f32, top := 0, right := 0, bottom := 0, left := 0) {
	ui_push_rect(x1, y1, x2, y2, top, right, bottom, left);
	ui_draw_colored_quad(color);
	ui_pop_rect();
}

//
// Buttons
//

Button_Data :: struct {
	x1, y1, x2, y2: f32,
	top, right, bottom, left: int,

	on_hover: proc(button: ^Button_Data),
	on_pressed: proc(button: ^Button_Data),
	on_released: proc(button: ^Button_Data),
	on_clicked: proc(button: ^Button_Data),

	color: Colorf,
	clicked: u64,
}

default_button_data := Button_Data{0, 0, 1, 1, 0, 0, 0, 0, default_button_hover, default_button_pressed, default_button_released, nil, Colorf{0, 0, 0, 0}, 0};
default_button_hover :: proc(button: ^Button_Data) {

}
default_button_pressed :: proc(button: ^Button_Data) {
	tween(&button.x1, 0.05, 0.25, ease_out_quart);
	tween(&button.y1, 0.05, 0.25, ease_out_quart);
	tween(&button.x2, 0.95, 0.25, ease_out_quart);
	tween(&button.y2, 0.95, 0.25, ease_out_quart);
}
default_button_released :: proc(button: ^Button_Data) {
	tween(&button.x1, 0, 0.25, ease_out_back);
	tween(&button.y1, 0, 0.25, ease_out_back);
	tween(&button.x2, 1, 0.25, ease_out_back);
	tween(&button.y2, 1, 0.25, ease_out_back);
}

ui_button :: proc(using button: ^Button_Data, loc := #caller_location) -> bool {
	clicked_this_frame := button.clicked == frame_count;
	if clicked_this_frame {
		if button.on_clicked != nil {
			button.on_clicked(button);
		}
		return true;
	}

	// todo(josh): not sure about this, since the rect ends up being _much_ larger most of the time, maybe?
	full_button_rect_unit := ui_current_rect_unit;

	ui_push_rect(x1, y1, x2, y2, top, right, bottom, left);
	defer ui_pop_rect();

	ui_draw_colored_quad(color);

	id := get_id_from_location(loc);
	cursor_in_rect := cursor_unit_position.y < full_button_rect_unit.y2 && cursor_unit_position.y > full_button_rect_unit.y1 && cursor_unit_position.x < full_button_rect_unit.x2 && cursor_unit_position.x > full_button_rect_unit.x1;

	if cursor_in_rect {
		if warm != id && hot == id {
			if button.on_pressed != nil {
				button.on_pressed(button);
			}
		}
		warm = id;
		if get_mouse_down(Mouse.Left) {
			if button.on_pressed != nil {
				button.on_pressed(button);
			}
			hot = id;
		}
	}
	else {
		if warm == id || hot == id {
			if button.on_released != nil {
				button.on_released(button);
			}
			warm = -1;
		}
	}

	if get_mouse_up(Mouse.Left) {
		if hot == id {
			hot = -1;
			if warm == id {
				if button.on_released != nil {
					button.on_released(button);
				}
				if button.on_clicked != nil {
					button.on_clicked(button);
				}
				return true;
			}
		}
	}

	return false;
}

ui_click :: inline proc(using button: ^Button_Data) {
	clicked = frame_count;
}

ui_text :: proc(font: ^Font, str: string, size: f32, color: Colorf, center_vertically := true, center_horizontally := true, x1 := cast(f32)0, y1 := cast(f32)0, x2 := cast(f32)1, y2 := cast(f32)1, top := 0, right := 0, bottom := 0, left := 0) {
	ui_push_rect(x1, y1, x2, y2, top, right, bottom, left);
	defer ui_pop_rect();

/*

	min := Vec2{cast(f32)ui_current_rect_pixels.x1, cast(f32)ui_current_rect_pixels.y1};
	max := Vec2{cast(f32)ui_current_rect_pixels.x2, cast(f32)ui_current_rect_pixels.y2};
	center_of_rect := min + ((max - min) / 2);
	size := cast(f32)(ui_current_rect_pixels.y2 - ui_current_rect_pixels.y1);
	string_width : f32 = cast(f32)get_string_width(font, str, size);

	position := Vec2{center_of_rect.x - (string_width / 2), cast(f32)ui_current_rect_pixels.y1};
	*/

	// min := Vec2{ui_current_rect_unit.x1, ui_current_rect_unit.y1};
	// max := Vec2{ui_current_rect_unit.x2, ui_current_rect_unit.y2};
	// center_of_rect := min + ((max - min) / 2);
	// height := ui_current_rect_unit.y2 - ui_current_rect_unit.y1;
	// string_width : f32 = cast(f32)get_string_width(font, str, height);
	// logln(string_width);
	// position := Vec2{center_of_rect.x - (string_width / 2), ui_current_rect_unit.y1};
	position := Vec2{cast(f32)ui_current_rect_unit.x1, cast(f32)ui_current_rect_unit.y1};
	height := (ui_current_rect_unit.y2 - ui_current_rect_unit.y1) * cast(f32)current_window_height / font.size;
	rendering_unit_space();
	draw_string(font, str, position, color, height * size, 0);
}

// draw_string :: proc(font: ^Font, str: string, position: Vec2, color: Colorf, _size: f32, layer: int) -> f32 {
// 	start := position;
// 	for c in str {
// 		min, max: Vec2;
// 		quad: stb.Aligned_Quad;
// 		{
// 			//
// 			size_pixels: Vec2;
// 			// NOTE!!!!!!!!!!! quad x0 y0 is TOP LEFT and x1 y1 is BOTTOM RIGHT. // I think?!!!!???!!!!
// 			quad = stb.get_baked_quad(font.chars, font.dim, font.dim, cast(int)c, &size_pixels.x, &size_pixels.y, true);
// 			size_pixels.y = abs(quad.y1 - quad.y0);

// 			ww := cast(f32)current_window_width;
// 			hh := cast(f32)current_window_height;
// 			min = position + (Vec2{quad.x0, -quad.y1} / font.size * _size * Vec2{hh/ww, 1});
// 			max = position + (Vec2{quad.x1, -quad.y0} / font.size * _size * Vec2{hh/ww, 1});
// 		}

// 		sprite: Sprite;
// 		{
// 			uv0 := Vec2{quad.s0, quad.t1};
// 			uv1 := Vec2{quad.s0, quad.t0};
// 			uv2 := Vec2{quad.s1, quad.t0};
// 			uv3 := Vec2{quad.s1, quad.t1};
// 			sprite = Sprite{{uv0, uv1, uv2, uv3}, 0, 0, font.id};
// 		}

// 		push_quad(shader_text, min, max, sprite, color, layer);
// 		position.x += max.x - min.x;
// 	}

// 	width := position.x - start.x;
// 	return width;
// }

// button :: proc(font: ^Font, text: string, text_size: f32, text_color: Colorf, min, max: Vec2, button_color: Colorf, render_order: int, scale: f32 = 1, alpha: f32 = 1) -> bool {
// 	rendering_unit_space();

// 	text_color.a   = alpha;
// 	button_color.a = alpha;

// 	half_width  := (max.x - min.x) / 2;
// 	half_height := (max.y - min.y) / 2;
// 	middle := min + ((max-min) / 2);

// 	p0 := middle + (Vec2{-half_width, -half_height} * scale);
// 	p1 := middle + (Vec2{-half_width,  half_height} * scale);
// 	p2 := middle + (Vec2{ half_width,  half_height} * scale);
// 	p3 := middle + (Vec2{ half_width, -half_height} * scale);

// 	push_quad(shader_rgba, p0, p1, p2, p3, button_color, render_order);
// 	baseline := get_centered_baseline(font, text, text_size * scale, p0, p2);
// 	draw_string(font, text, baseline, text_color, text_size * scale, render_order+1);

// 	assert(current_render_mode == rendering_unit_space);
// 	mouse_pos := cursor_unit_position;
// 	if get_mouse_up(Mouse.Left) && mouse_pos.x >= min.x && mouse_pos.y >= min.y && mouse_pos.x <= max.x && mouse_pos.y <= max.y {
// 		return true;
// 	}

// 	return false;
// }