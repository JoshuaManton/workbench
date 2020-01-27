package bezier
import "../math"

Curve :: struct(Dimensions: int) {
	points: [dynamic]Curve_Point(Dimensions),
}

Curve_Point :: struct(Dimensions: int) {
	position: [Dimensions]f32,
	tangent0: [Dimensions]f32,
	tangent1: [Dimensions]f32,
}

add_point :: proc(c: ^Curve($N), val: [N]f32) -> ^Curve_Point(N) {
	append(&c.points, Curve_Point(N){val, val, val});
	return &c.points[len(c.points)-1];
}

sample_curve :: proc(c: Curve($N), t: f32) -> [N]f32 {
	if len(c.points) == 0 do return 0;

	@static curve_solve_buffer: [dynamic][N]f32;
	@static curve_solve_buffer_2: [dynamic][N]f32;
	clear(&curve_solve_buffer);
	clear(&curve_solve_buffer_2);
	for p, idx in c.points {
		if idx != 0 {
			append(&curve_solve_buffer, p.tangent0);
		}
		append(&curve_solve_buffer, p.position);
		if idx < len(c.points)-1 {
			append(&curve_solve_buffer, p.tangent1);
		}
	}
	buf := &curve_solve_buffer;
	other_buf := &curve_solve_buffer_2;

	for len(buf) > 1 {
		clear(other_buf);
		for pidx := 0; pidx < len(buf)-1; pidx += 1 {
			new_pos := math.lerp(buf[pidx], buf[pidx+1], t);
			append(other_buf, new_pos);
		}
		b := buf;
		buf = other_buf;
		other_buf = b;
	}
	return buf[0];
}

delete_animation_curve :: proc(curve: Curve($N)) {
	delete(curve.points);
}