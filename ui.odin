package workbench

using import "core:math"

button :: proc(font: ^Font, text: string, text_size: f32, text_color: Colorf, min, max: Vec2, button_color: Colorf, render_order: int, scale: f32 = 1, alpha: f32 = 1) -> bool {
	rendering_unit_space();

	text_color.a   = alpha;
	button_color.a = alpha;

	half_width  := (max.x - min.x) / 2;
	half_height := (max.y - min.y) / 2;
	middle := min + ((max-min) / 2);

	p0 := middle + (Vec2{-half_width, -half_height} * scale);
	p1 := middle + (Vec2{-half_width,  half_height} * scale);
	p2 := middle + (Vec2{ half_width,  half_height} * scale);
	p3 := middle + (Vec2{ half_width, -half_height} * scale);

	push_quad(shader_rgba, p0, p1, p2, p3, button_color, render_order);
	baseline := get_centered_baseline(font, text, text_size * scale, p0, p2);
	draw_string(font, text, baseline, text_color, text_size * scale, render_order+1);

	assert(current_render_mode == rendering_unit_space);
	mouse_pos := cursor_unit_position;
	if get_mouse_up(Mouse.Left) && mouse_pos.x >= min.x && mouse_pos.y >= min.y && mouse_pos.x <= max.x && mouse_pos.y <= max.y {
		return true;
	}

	return false;
}