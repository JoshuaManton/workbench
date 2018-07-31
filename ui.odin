package workbench

using import "core:math"

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
	current_rect: Pixel_Rect;
	if len(ui_rect_stack) == 0 {
		current_rect = Pixel_Rect{0, 0, current_window_width, current_window_height};
	}
	else {
		current_rect = ui_current_rect_pixels;
	}

	cur_w := current_rect.x2 - current_rect.x1;
	cur_h := current_rect.y2 - current_rect.y1;

	new_x1 := current_rect.x1 + cast(int)(cast(f32)cur_w * x1) + left;
	new_y1 := current_rect.y1 + cast(int)(cast(f32)cur_h * y1) + bottom;

	new_x2 := current_rect.x2 - cast(int)(cast(f32)cur_w*(1-x2)) - right;
	new_y2 := current_rect.y2 - cast(int)(cast(f32)cur_h*(1-y2)) - top;

	ui_current_rect_pixels = Pixel_Rect{new_x1, new_y1, new_x2, new_y2};
	cww := current_window_width;
	cwh := current_window_height;
	ui_current_rect_unit = Unit_Rect{cast(f32)ui_current_rect_pixels.x1 / cast(f32)cww, cast(f32)ui_current_rect_pixels.y1 / cast(f32)cwh, cast(f32)ui_current_rect_pixels.x2 / cast(f32)cww, cast(f32)ui_current_rect_pixels.y2 / cast(f32)cwh};

	append(&ui_rect_stack, UI_Rect{ui_current_rect_pixels, ui_current_rect_unit});
}

ui_pop_rect :: inline proc() {
	pop(&ui_rect_stack);
	rect := ui_rect_stack[len(ui_rect_stack)-1];
	ui_current_rect_pixels = rect.pixel_rect;
	ui_current_rect_unit = rect.unit_rect;
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
	on_click: proc(button: ^Button_Data),
	on_release: proc(button: ^Button_Data),

	color: Colorf,
	clicked: u64,
}

button_default_data := Button_Data{0, 0, 1, 1, 0, 0, 0, 0, button_default_hover, button_default_click, button_default_release, Colorf{0, 0, 0, 0}, 0};
button_default_hover :: proc(button: ^Button_Data) {

}
button_default_click :: proc(button: ^Button_Data) {
	tween(&button.x1, 0.05, 0.25, ease_out_quart);
	tween(&button.y1, 0.05, 0.25, ease_out_quart);
	tween(&button.x2, 0.95, 0.25, ease_out_quart);
	tween(&button.y2, 0.95, 0.25, ease_out_quart);
}
button_default_release :: proc(button: ^Button_Data) {
	tween(&button.x1, 0, 0.25, ease_out_back);
	tween(&button.y1, 0, 0.25, ease_out_back);
	tween(&button.x2, 1, 0.25, ease_out_back);
	tween(&button.y2, 1, 0.25, ease_out_back);
}

ui_button :: proc(using button: ^Button_Data) -> bool {
	ui_push_rect(x1, y1, x2, y2, top, right, bottom, left);
	defer ui_pop_rect();

	ui_draw_colored_quad(color);

	if button.clicked != frame_count && !(cursor_unit_position.y < ui_current_rect_unit.y2 &&
		cursor_unit_position.y > ui_current_rect_unit.y1 &&
		cursor_unit_position.x < ui_current_rect_unit.x2 &&
		cursor_unit_position.x > ui_current_rect_unit.x1) {
		return false;
	}

	if button.clicked == frame_count || get_mouse_up(Mouse.Left) {
		if button.on_release != nil {
			button.on_release(button);
		}
		return true;
	}

	if get_mouse_down(Mouse.Left) {
		if button.on_click != nil {
			button.on_click(button);
		}
	}

	return false;
}

ui_click :: inline proc(using button: ^Button_Data) {
	clicked = frame_count;
}

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