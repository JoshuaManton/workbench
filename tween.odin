package workbench

using import "core:math"

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

	callback: Tween_Callback,
	start_time: f32,
	loop: bool,
}

tweeners: [dynamic]Tweener;
updating_tweens: bool;

Tween_Callback :: struct {
	procedure: proc(rawptr),
	data: rawptr,
}

Tween_Params :: struct {
	callback: Tween_Callback,
	delay: f32,
	loop: bool,
	allow_duplicates: bool,
}

tween_kill :: proc(ptr: rawptr) {
	for _, i in tweeners {
		if tweeners[i].addr == ptr {
			remove_at(&tweeners, i);
			break;
		}
	}
}

tween_kill_index :: proc(idx: int) {
	remove_at(&tweeners, idx);
}

tween :: proc(ptr: ^$T, target: T, duration: f32, ease: proc(f32) -> f32 = ease_out_quart, tween_params: Tween_Params = {}) -> ^Tweener {
	if !tween_params.allow_duplicates {
		tween_kill(ptr);
	}

	new_tweener := Tweener{ptr, ptr, ptr^, target, 0, duration, ease, tween_params.callback, time + tween_params.delay, tween_params.loop};
	idx := len(tweeners);
	append(&tweeners, new_tweener);
	return &tweeners[idx];
}

_update_tween :: proc(dt: f32) {
	tweener_idx := len(tweeners)-1;
	updating_tweens = true;
	defer updating_tweens = false;
	for tweener_idx >= 0 {
		defer tweener_idx -= 1;

		tweener := &tweeners[tweener_idx];
		assert(tweener.duration != 0);

		if time < tweener.start_time do continue;

		switch kind in tweener.ptr {
			case ^f32: {
				kind^ = _update_one_tweener(f32, tweener, dt);
			}
			case ^Vec2: {
				kind^ = _update_one_tweener(Vec2, tweener, dt);
			}
			case ^Vec3: {
				kind^ = _update_one_tweener(Vec3, tweener, dt);
			}
			case ^Vec4: {
				kind^ = _update_one_tweener(Vec4, tweener, dt);
			}
		}

		if !tweener.loop && tweener.cur_time >= tweener.duration {
			if tweener.callback.procedure != nil {
				tweener.callback.procedure(tweener.callback.data);
			}
			tween_kill_index(tweener_idx);
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

ease_linear :: proc(t: f32) -> f32 {
	return t;
}

ease_in_sine :: proc(t: f32) -> f32 {
	t -= 1;
	return 1 + sin(1.5707963 * t);
}

ease_out_sine :: proc(t: f32) -> f32 {
	return sin(1.5707963 * t);
}

ease_in_out_sine :: proc(t: f32) -> f32 {
	return 0.5 * (1 + sin(3.1415926 * (t - 0.5)));
}

ease_in_quad :: proc(t: f32) -> f32 {
    return t * t;
}

ease_out_quad ::  proc(t: f32) -> f32 {
	return t * (2 - t);
}

ease_in_out_quad :: proc(t: f32) -> f32 {
	if t < 0.5 {
		return 2 * t * t;
	}
	else {
		return t * (4 - 2 * t) - 1;
	}
}

ease_in_cubic :: proc(t: f32) -> f32 {
    return t * t * t;
}

ease_out_cubic :: proc(t: f32) -> f32 {
	t -= 1;
    return 1 + t * t * t;
}

ease_in_out_cubic :: proc(t: f32) -> f32 {
	if t < 0.5 {
		return 4 * t * t * t;
	}
	else {
		t -= 1;
		return 1 + t * (2 * t) * (2 * t);
	}
}

ease_in_quart :: proc(t: f32) -> f32 {
    t *= t;
    return t * t;
}

ease_out_quart :: proc(t: f32) -> f32 {
	t -= 1;
    t = t * t;
    return 1 - t * t;
}

ease_in_out_quart :: proc(t: f32) -> f32 {
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

ease_in_quint :: proc(t: f32) -> f32 {
    t2 := t * t;
    return t * t2 * t2;
}

ease_out_quint :: proc(t: f32) -> f32 {
	t -= 1;
    t2 := t * t;
    return 1 + t * t2 * t2;
}

ease_in_out_quint :: proc(t: f32) -> f32 {
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

ease_in_expo :: proc(t: f32) -> f32 {
    return (pow(2, 8 * t) - 1) / 255;
}

ease_out_expo :: proc(t: f32) -> f32 {
    return 1 - pow(2, -8 * t);
}

ease_in_out_expo :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return (pow(2, 16 * t) - 1) / 510;
    }
    else {
        return 1 - 0.5 * pow(2, -16 * (t - 0.5));
    }
}

ease_in_circ :: proc(t: f32) -> f32 {
    return 1 - sqrt(1 - t);
}

ease_out_circ :: proc(t: f32) -> f32 {
    return sqrt(t);
}

ease_in_out_circ :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return (1 - sqrt(1 - 2 * t)) * 0.5;
    }
    else {
        return (1 + sqrt(2 * t - 1)) * 0.5;
    }
}

ease_in_back :: proc(t: f32) -> f32 {
    return t * t * (2.70158 * t - 1.70158);
}

ease_out_back :: proc(t: f32) -> f32 {
	t -= 1;
    return 1 + t * t * (2.70158 * t + 1.70158);
}

ease_in_out_back :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return t * t * (7 * t - 2.5) * 2;
    }
    else {
    	t -= 1;
        return 1 + t * t * 2 * (7 * t + 2.5);
    }
}

ease_in_elastic :: proc(t: f32) -> f32 {
    t2 := t * t;
    return t2 * t2 * sin(t * PI * 4.5);
}

ease_out_elastic :: proc(t: f32) -> f32 {
    t2 := (t - 1) * (t - 1);
    return 1 - t2 * t2 * cos(t * PI * 4.5);
}

ease_in_out_elastic :: proc(t: f32) -> f32 {
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

ease_in_bounce :: proc(t: f32) -> f32 {
    return pow(2, 6 * (t - 1)) * abs(sin(t * PI * 3.5));
}

ease_out_bounce :: proc(t: f32) -> f32 {
    return 1 - pow(2, -6 * t) * abs(cos(t * PI * 3.5));
}

ease_in_out_bounce :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return 8 * pow(2, 8 * (t - 1)) * abs(sin(t * PI * 7));
    }
    else {
        return 1 - 8 * pow(2, -8 * t) * abs(sin(t * PI * 7));
    }
}