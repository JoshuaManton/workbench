package collision

import rt "core:runtime"

import "core:fmt"
import "../math"
import "../logging"
import "../basic"

import "core:sort"

main :: proc() {

}

//
// Collision Scene API
//

Collider :: struct {
	userdata: rawptr,
	position: Vec3,
	scale: Vec3,
	info: Collider_Info,
}

Collider_Info :: struct {
	offset: Vec3,
	kind: union {
		Box,
	},
}

Box :: struct {
	size: Vec3,
}

Collision_Scene :: struct {
	colliders: [dynamic]^Collider,
}

Hit_Info :: struct {
	userdata: rawptr,

	// Fraction (0..1) of the distance that the ray started intersecting
	fraction0: f32,
	// Fraction (0..1) of the distance that the ray stopped intersecting
	fraction1: f32,

	// Point that the ray started intersecting
	point0: Vec3,
	// Point that the ray stopped intersecting
	point1: Vec3,

	// todo(josh)
	// normal0: Vec3,
	// normal1: Vec3,
}

add_collider_to_scene :: proc(using scene: ^Collision_Scene, position, scale: Vec3, info: Collider_Info, userdata: rawptr = nil) -> ^Collider {
	assert(info.kind != nil);
	collider := new_clone(Collider{userdata, position, scale, info});
	append(&colliders, collider);
	return collider;
}

update_collider :: proc(collider: ^Collider, position, scale: Vec3, info: Collider_Info, userdata: rawptr = nil) {
	assert(info.kind != nil);
	collider^ = Collider{userdata, position, scale, info};
}

delete_collider :: proc(using scene: ^Collision_Scene, collider: ^Collider) {
	for coll, idx in colliders {
		if coll == collider {
			unordered_remove(&colliders, idx);
			break;
		}
	}
	free(collider);
}

delete_collision_scene :: proc(using scene: ^Collision_Scene) {
	for coll in colliders {
		free(coll);
	}
	delete(colliders);
}



linecast :: proc(using scene: ^Collision_Scene, origin: Vec3, velocity: Vec3, out_hits: ^[dynamic]Hit_Info) {
	clear(out_hits);
	for collider in colliders {
		info: Hit_Info;
		ok: bool;
		switch kind in collider.info.kind {
			case Box: info, ok = cast_line_box(origin, velocity, collider.position + collider.info.offset, kind.size * collider.scale);
			case: panic(fmt.tprint(kind));
		}
		info.userdata = collider.userdata;
		if ok do append(out_hits, info);
	}
	// sort so the outputs are in order of closest -> farthest
	sort.quick_sort_proc(out_hits[:], proc(a, b: Hit_Info) -> int {
		if a.fraction0 < b.fraction0 do return -1;
		return 1;
	});
}

// todo(josh): test this, not sure if it works
boxcast :: proc(using scene: ^Collision_Scene, origin, size, velocity: Vec3, out_hits: ^[dynamic]Hit_Info) {
	clear(out_hits);
	for collider in colliders {
		info: Hit_Info;
		ok: bool;
		switch kind in collider.info.kind {
			case Box: info, ok = cast_box_box(origin, size, velocity, collider.position + collider.info.offset, kind.size * collider.scale);
			case: panic(fmt.tprint(kind));
		}
		info.userdata = collider.userdata;
		if ok do append(out_hits, info);
	}
	// sort so the outputs are in order of closest -> farthest
	sort.quick_sort_proc(out_hits[:], proc(a, b: Hit_Info) -> int {
		if a.fraction0 < b.fraction0 do return -1;
		return 1;
	});
}

overlap_point :: proc(using scene: ^Collision_Scene, origin: Vec3, out_hits: ^[dynamic]Hit_Info) {
	clear(out_hits);
	collider_loop: for collider in colliders {
		// note(josh): all cases in this switch should `continue collider_loop;` if they detect a hit didn't happen so we can assume a hit did happen if execution continues passed the switch
		// note(josh): all cases in this switch should `continue collider_loop;` if they detect a hit didn't happen so we can assume a hit did happen if execution continues passed the switch
		// note(josh): all cases in this switch should `continue collider_loop;` if they detect a hit didn't happen so we can assume a hit did happen if execution continues passed the switch
		switch kind in collider.info.kind {
			case Box: {
				min := (collider.position + collider.info.offset) - (kind.size * collider.scale * 0.5);
				max := (collider.position + collider.info.offset) + (kind.size * collider.scale * 0.5);

				if origin.x < min.x || origin.x > max.x do continue collider_loop;
				if origin.y < min.y || origin.y > max.y do continue collider_loop;
				if origin.z < min.z || origin.z > max.z do continue collider_loop;
			}
			case: panic(fmt.tprint(kind));
		}

		info := Hit_Info{collider.userdata, 0, 0, origin, origin};
		append(out_hits, info);
	}
	sort.quick_sort_proc(out_hits[:], proc(a, b: Hit_Info) -> int {
		if a.fraction0 < b.fraction0 do return -1;
		return 1;
	});
}



//
// raw stuff
//

sqr_magnitude :: inline proc(a: Vec3) -> f32 do return math.dot(a, a);

closest_point_on_line :: proc(origin: Vec3, p1, p2: Vec3) -> Vec3 {
	direction := p2 - p1;
	square_length := sqr_magnitude(direction);
	if (square_length == 0.0) {
		// p1 == p2
		dir_from_point := p1 - origin;
		return p1;
	}

	dot := math.dot(origin - p1, p2 - p1) / square_length;
	t := max(min(dot, 1), 0);
	projection := p1 + t * (p2 - p1);
	return projection;
}

cast_box_box :: proc(b1pos, b1size: Vec3, box_direction: Vec3, b2pos, _b2size: Vec3) -> (Hit_Info, bool) {
	b2size := _b2size;
	b2size += b1size;
	return cast_line_box(b1pos, box_direction, b2pos, b2size);
}

cast_line_box :: proc(line_origin, line_velocity: Vec3, boxpos, boxsize: Vec3) -> (Hit_Info, bool) {
	inverse := Vec3{
		1/line_velocity.x,
		1/line_velocity.y,
		1/line_velocity.z,
	};

	lb := boxpos - boxsize * 0.5;
	rt := boxpos + boxsize * 0.5;

	t1 := (lb.x - line_origin.x)*inverse.x;
	t2 := (rt.x - line_origin.x)*inverse.x;
	t3 := (lb.y - line_origin.y)*inverse.y;
	t4 := (rt.y - line_origin.y)*inverse.y;
	t5 := (lb.z - line_origin.z)*inverse.z;
	t6 := (rt.z - line_origin.z)*inverse.z;

	tmin := max(max(min(t1, t2), min(t3, t4)), min(t5, t6));
	tmax := min(min(max(t1, t2), max(t3, t4)), max(t5, t6));

	// if tmax < 0, ray (line) is intersecting AABB, but the whole AABB is behind us
	if tmax < 0 do return {}, false;

	// if tmin > tmax, ray doesn't intersect AABB
	if tmin > tmax do return {}, false;

	info := Hit_Info{nil, tmin, tmax, line_origin + (line_velocity * tmin), line_origin + (line_velocity * tmax)};
	return info, true;
}

@(deprecated="Not yet implemented")
cast_box_circle :: proc(box_min, box_max: Vec3, box_direction: Vec3, circle_position: Vec3, circle_radius: f32) -> (Hit_Info, bool) {
	// todo(josh): this sounds like a nightmare
	assert(false);
	return Hit_Info{}, false;
}

// todo(josh): test this, not sure if it works
cast_line_circle :: proc(line_origin, line_velocity: Vec3, circle_center: Vec3, circle_radius: f32) -> (Hit_Info, bool) {
	direction := line_origin - circle_center;
	a := math.dot(line_velocity, line_velocity);
	b := math.dot(direction, line_velocity);
	c := math.dot(direction, direction) - circle_radius * circle_radius;

	disc := b * b - a * c;
	if (disc < 0) {
		return Hit_Info{}, false;
	}

	sqrt_disc := math.sqrt(disc);
	invA: f32 = 1.0 / a;

	tmin := (-b - sqrt_disc) * invA;
	tmax := (-b + sqrt_disc) * invA;
	tmax = min(tmax, 1);

	inv_radius: f32 = 1.0 / circle_radius;

	pmin := line_origin + tmin * line_velocity;
	// normal := (pmin - circle_center) * inv_radius;

	pmax := line_origin + tmax * line_velocity;
	// normal[i] = (point[i] - circle_center) * invRadius;

	info := Hit_Info{nil, tmin, tmax, pmin, pmax};

	return info, true;
}

overlap_point_box :: inline proc(origin: Vec3, box_min, box_max: Vec3) -> bool {
	return origin.x < box_max.x
		&& origin.x > box_min.x
		&& origin.y < box_max.y
		&& origin.y > box_min.y
		&& origin.z < box_max.z
		&& origin.z > box_min.z;
}

overlap_point_circle :: inline proc(origin: Vec3, circle_position: Vec3, circle_radius: f32) -> bool {
	return sqr_magnitude(origin - circle_position) < (circle_radius * circle_radius);
}

overlap_box_box_2d :: proc(min1, max1: Vec2, min2, max2: Vec2) -> bool {
	if min1.x > max2.x || min1.y > max2.y || max1.x < min2.x || max1.y < min2.y {
		return false;
	}
	return true;
}



logln :: logging.logln;
logf :: logging.logf;

Vec2 :: math.Vec2;
Vec3 :: math.Vec3;
Vec4 :: math.Vec4;
