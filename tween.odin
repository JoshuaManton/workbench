package workbench

using import "math"
using import "basic"

Tweener :: struct {
	addr: rawptr,

	ptr: union {
		^f32,
		^Vec2,
		^Vec3,
		^Vec4,
	},

	start: union {
		Vec2,
		f32,
		Vec3,
		Vec4,
	},

	target: union {
		Vec2,
		f32,
		Vec3,
		Vec4,
	},

	cur_time: f32,
	duration: f32,

	ease_proc: proc(f32) -> f32,

	start_time: f32,
	loop: bool,

	active: bool,

	callback: proc(rawptr),
	callback_data: rawptr,

	queued_tween: ^Tweener,
}

tweeners: [dynamic]^Tweener;
updating_tweens: bool;

Tween_Params :: struct {
	delay: f32,
	loop: bool,
	callback: proc(rawptr),
}

tween_destroy :: proc(ptr: rawptr) {
	for _, i in tweeners {
		tweener := tweeners[i];
		if tweeners[i].addr == ptr {
			tween_destroy_index(i);
			break;
		}
	}
}

tween_destroy_index :: inline proc(idx: int) {
	tweener := tweeners[idx];
	unordered_remove(&tweeners, idx);
	free(tweener);
}

tween :: proc(ptr: ^$T, target: T, duration: f32, ease: proc(f32) -> f32 = ease_out_quart, delay : f32 = 0) -> ^Tweener {
	assert(!updating_tweens);

	tween_destroy(ptr);
	new_tweener := tween_make(ptr, target, duration, ease, delay);
	new_tweener.active = true;
	return new_tweener;
}

tween_make :: inline proc(ptr: ^$T, target: T, duration: f32, ease: proc(f32) -> f32 = ease_out_quart, delay : f32 = 0) -> ^Tweener {
	new_tweener := new_clone(Tweener{ptr, ptr, ptr^, target, 0, duration, ease, time + delay, false, false, nil, nil, nil}); // @Alloc
	append(&tweeners, new_tweener);
	return new_tweener;
}

tween_callback :: inline proc(a: ^Tweener, userdata: ^$T, callback: proc(^T)) {
	a.callback = auto_cast callback;
	a.callback_data = userdata;
}

tween_queue :: inline proc(a, b: ^Tweener) {
	b.active = false;
	a.queued_tween = b;
}

update_tween :: proc(dt: f32) {
	tweener_idx := len(tweeners)-1;
	updating_tweens = true;
	defer updating_tweens = false;
	for tweener_idx >= 0 {
		defer tweener_idx -= 1;

		tweener := tweeners[tweener_idx];
		assert(tweener.duration != 0);

		if !tweener.active do continue;
		if time < tweener.start_time do continue;

		switch kind in tweener.ptr {
			case ^f32:  kind^ = _update_one_tweener(f32,  tweener, dt);
			case ^Vec2: kind^ = _update_one_tweener(Vec2, tweener, dt);
			case ^Vec3: kind^ = _update_one_tweener(Vec3, tweener, dt);
			case ^Vec4: kind^ = _update_one_tweener(Vec4, tweener, dt);
		}

		if !tweener.loop && tweener.cur_time >= tweener.duration {
			if tweener.callback != nil {
				tweener.callback(tweener.callback_data);
			}
			if tweener.queued_tween != nil {
				tweener.queued_tween.active = true;
				switch kind in tweener.queued_tween.ptr {
					case ^f32:  tweener.queued_tween.start = kind^;
					case ^Vec2: tweener.queued_tween.start = kind^;
					case ^Vec3: tweener.queued_tween.start = kind^;
					case ^Vec4: tweener.queued_tween.start = kind^;
				}
			}
			tween_destroy_index(tweener_idx);
		}
	}
}

_update_one_tweener :: proc($kind: typeid, tweener: ^Tweener, dt: f32) -> kind {
	tweener.cur_time += dt;
	assert(tweener.cur_time != 0);

	for tweener.cur_time >= tweener.duration {
		if !tweener.loop do return tweener.target.(kind);

		tweener.cur_time -= tweener.duration;

		start := tweener.start.(kind);
		tweener.start = tweener.target;
		tweener.target = start;
	}

	t := tweener.cur_time / tweener.duration;
	t  = tweener.ease_proc(t);

	a := tweener.start.(kind);
	b := tweener.target.(kind);
	result := lerp(a, b, t);
	return result;
}

ease_linear :: proc(_t: f32) -> f32 {
	t := _t;
	return t;
}

ease_in_sine :: proc(_t: f32) -> f32 {
	t := _t;
	t -= 1;
	return 1 + sin(1.5707963 * t);
}

ease_out_sine :: proc(_t: f32) -> f32 {
	t := _t;
	return sin(1.5707963 * t);
}

ease_in_out_sine :: proc(_t: f32) -> f32 {
	t := _t;
	return 0.5 * (1 + sin(3.1415926 * (t - 0.5)));
}

ease_in_quad :: proc(_t: f32) -> f32 {
	t := _t;
    return t * t;
}

ease_out_quad ::  proc(_t: f32) -> f32 {
	t := _t;
	return t * (2 - t);
}

ease_in_out_quad :: proc(_t: f32) -> f32 {
	t := _t;
	if t < 0.5 {
		return 2 * t * t;
	}
	else {
		return t * (4 - 2 * t) - 1;
	}
}

ease_in_cubic :: proc(_t: f32) -> f32 {
	t := _t;
    return t * t * t;
}

ease_out_cubic :: proc(_t: f32) -> f32 {
	t := _t;
	t -= 1;
    return 1 + t * t * t;
}

ease_in_out_cubic :: proc(_t: f32) -> f32 {
	t := _t;
	if t < 0.5 {
		return 4 * t * t * t;
	}
	else {
		t -= 1;
		return 1 + t * (2 * t) * (2 * t);
	}
}

ease_in_quart :: proc(_t: f32) -> f32 {
	t := _t;
    t *= t;
    return t * t;
}

ease_out_quart :: proc(_t: f32) -> f32 {
	t := _t;
	t -= 1;
    t = t * t;
    return 1 - t * t;
}

ease_in_out_quart :: proc(_t: f32) -> f32 {
	t := _t;
    if t < 0.5 {
        t *= t;
        return 8 * t * t;
    }
    else {
    	t -= 1;
        t = t * t;
        return 1 - 8 * t * t;
    }
}

ease_in_quint :: proc(_t: f32) -> f32 {
	t := _t;
    t2 := t * t;
    return t * t2 * t2;
}

ease_out_quint :: proc(_t: f32) -> f32 {
	t := _t;
	t -= 1;
    t2 := t * t;
    return 1 + t * t2 * t2;
}

ease_in_out_quint :: proc(_t: f32) -> f32 {
	t := _t;
    if t < 0.5 {
        t2 := t * t;
        return 16 * t * t2 * t2;
    }
    else {
    	t -= 1;
        t2 := t * t;
        return 1 + 16 * t * t2 * t2;
    }
}

ease_in_expo :: proc(_t: f32) -> f32 {
	t := _t;
    return (pow(2, 8 * t) - 1) / 255;
}

ease_out_expo :: proc(_t: f32) -> f32 {
	t := _t;
    return 1 - pow(2, -8 * t);
}

ease_in_out_expo :: proc(_t: f32) -> f32 {
	t := _t;
    if t < 0.5 {
        return (pow(2, 16 * t) - 1) / 510;
    }
    else {
        return 1 - 0.5 * pow(2, -16 * (t - 0.5));
    }
}

ease_in_circ :: proc(_t: f32) -> f32 {
	t := _t;
    return 1 - sqrt(1 - t);
}

ease_out_circ :: proc(_t: f32) -> f32 {
	t := _t;
    return sqrt(t);
}

ease_in_out_circ :: proc(_t: f32) -> f32 {
	t := _t;
    if t < 0.5 {
        return (1 - sqrt(1 - 2 * t)) * 0.5;
    }
    else {
        return (1 + sqrt(2 * t - 1)) * 0.5;
    }
}

ease_in_back :: proc(_t: f32) -> f32 {
	t := _t;
    return t * t * (2.70158 * t - 1.70158);
}

ease_out_back :: proc(_t: f32) -> f32 {
	t := _t;
	t -= 1;
    return 1 + t * t * (2.70158 * t + 1.70158);
}

ease_in_out_back :: proc(_t: f32) -> f32 {
	t := _t;
    if t < 0.5 {
        return t * t * (7 * t - 2.5) * 2;
    }
    else {
    	t -= 1;
        return 1 + t * t * 2 * (7 * t + 2.5);
    }
}

ease_in_elastic :: proc(_t: f32) -> f32 {
	t := _t;
    t2 := t * t;
    return t2 * t2 * sin(t * PI * 4.5);
}

ease_out_elastic :: proc(_t: f32) -> f32 {
	t := _t;
    t2 := (t - 1) * (t - 1);
    return 1 - t2 * t2 * cos(t * PI * 4.5);
}

ease_in_out_elastic :: proc(_t: f32) -> f32 {
	t := _t;
    if t < 0.45 {
        t2 := t * t;
        return 8 * t2 * t2 * sin(t * PI * 9);
    }
    else if t < 0.55 {
        return 0.5 + 0.75 * sin(t * PI * 4);
    }
    else {
        t2 := (t - 1) * (t - 1);
        return 1 - 8 * t2 * t2 * sin(t * PI * 9);
    }
}

ease_in_bounce :: proc(_t: f32) -> f32 {
	t := _t;
    return pow(2, 6 * (t - 1)) * abs(sin(t * PI * 3.5));
}

ease_out_bounce :: proc(_t: f32) -> f32 {
	t := _t;
    return 1 - pow(2, -6 * t) * abs(cos(t * PI * 3.5));
}

ease_in_out_bounce :: proc(_t: f32) -> f32 {
	t := _t;
    if t < 0.5 {
        return 8 * pow(2, 8 * (t - 1)) * abs(sin(t * PI * 7));
    }
    else {
        return 1 - 8 * pow(2, -8 * t) * abs(sin(t * PI * 7));
    }
}
