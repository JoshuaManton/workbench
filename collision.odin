      import "core:fmt.odin"

using import "basic.odin"
using import "math.odin"

closest_point_on_line :: proc(origin: Vec2, p1, p2: Vec2) -> Vec2 {
	direction := p2 - p1;
	square_length := sqr_magnitude(direction);
	if (square_length == 0.0) {
		// p1 == p2
		dir_from_point := p1 - origin;
		return p1;
	}

	dot := dot(origin - p1, p2 - p1) / square_length;
	t := _max(_min(dot, 1), 0);
	projection := p1 + t * (p2 - p1);
	return projection;
}

// todo(josh): there is currently an assertion failure in the compiler related
// to the builtin min() and max() procs. remove these when that is fixed
_min :: inline proc(a, b: $T) -> T {
	if a < b do return a;
	return b;
}

_max :: inline proc(a, b: $T) -> T {
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

	// todo(josh)
	// normal0: Vec2,
	// normal1: Vec2,
}

cast_box_box :: proc(b1min, b1max: Vec2, box_direction: Vec2, b2min, b2max: Vec2) -> (Hit_Info, bool) {
	half_size := (b1max - b1min) / 2.0;
	b2min -= half_size;
	b2max += half_size;
	return cast_line_box(b1min + half_size, box_direction, b2min, b2max);
}

cast_box_circle :: proc(box_min, box_max: Vec2, box_direction: Vec2, circle_position: Vec2, circle_radius: f32) -> (Hit_Info, bool) {
	// todo(josh): this sounds like a nightmare
	assert(false);
	return Hit_Info{}, false;
}

cast_circle_box :: proc(circle_origin, circle_direction: Vec2, circle_radius: f32, box_min, box_max: Vec2) -> (Hit_Info, bool) {
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
			info, hit := cast_line_circle(circle_origin, circle_direction, pos, circle_radius);
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

		info0, hit0 := cast_line_box(circle_origin, circle_direction, box0_min, box0_max);
		if hit0 {
			did_hit = true;
			compare_hits(&final_hit_info, info0);
		}

		info1, hit1 := cast_line_box(circle_origin, circle_direction, box1_min, box1_max);
		if hit1 {
			did_hit = true;
			compare_hits(&final_hit_info, info1);
		}
	}

	return final_hit_info, did_hit;
}

cast_line_circle :: proc(line_origin, line_direction: Vec2, circle_center: Vec2, circle_radius: f32) -> (Hit_Info, bool) {
	direction := line_origin - circle_center;
	a := dot(line_direction, line_direction);
	b := dot(direction, line_direction);
	c := dot(direction, direction) - circle_radius * circle_radius;

	disc := b * b - a * c;
	if (disc < 0) {
		return Hit_Info{}, false;
	}

	sqrt_disc := sqrt(disc);
	invA: f32 = 1.0 / a;

	tmin := (-b - sqrt_disc) * invA;
	tmax := (-b + sqrt_disc) * invA;
	tmax = _min(tmax, 1);

	inv_radius: f32 = 1.0 / circle_radius;

	pmin := line_origin + tmin * line_direction;
	// normal := (pmin - circle_center) * inv_radius;

	pmax := line_origin + tmax * line_direction;
	// normal[i] = (point[i] - circle_center) * invRadius;

	info := Hit_Info{tmin, tmax, pmin, pmax};

	return info, true;
}

cast_line_box :: proc(line_origin, line_direction: Vec2, box_min, box_max: Vec2) -> (Hit_Info, bool) {
	inverse := Vec2{1.0/line_direction.x, 1.0/line_direction.y};

	tx1 := (box_min.x - line_origin.x)*inverse.x;
	tx2 := (box_max.x - line_origin.x)*inverse.x;

	tmin := _min(tx1, tx2);
	tmax := _max(tx1, tx2);

	ty1 := (box_min.y - line_origin.y)*inverse.y;
	ty2 := (box_max.y - line_origin.y)*inverse.y;

	tmin = _max(tmin, _min(ty1, ty2));
	tmax = _min(tmax, _max(ty1, ty2));
	tmax = _min(tmax, 1);

	p0 := line_origin + (line_direction * tmin);
	info := Hit_Info{tmin, tmax, line_origin + (line_direction * tmin), line_origin + (line_direction * tmax)};

	return info, tmax >= tmin && tmax <= 1.0 && tmax >= 0.0 && tmin <= 1.0 && tmin >= 0.0;
}

overlap_point_box :: inline proc(origin: Vec2, box_min, box_max: Vec2) -> bool {
	return origin.x < box_max.x
		&& origin.x > box_min.x
		&& origin.y < box_max.y
		&& origin.y > box_min.y;
}

overlap_point_circle :: inline proc(origin: Vec2, circle_position: Vec2, circle_radius: f32) -> bool {
	return sqr_magnitude(origin - circle_position) < sqr(circle_radius);
}
