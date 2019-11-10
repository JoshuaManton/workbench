package workbench

using import "../math"

Colorf :: struct {
	r: f32 `imgui_range="0":"1"`,
	g: f32 `imgui_range="0":"1"`,
	b: f32 `imgui_range="0":"1"`,
	a: f32 `imgui_range="0":"1"`,
}

Colori :: struct {
	r, g, b, a: u8,
}

color_lerp :: proc(c1, c2: $T, t: f32) -> T where T == Colorf || T == Colori {
	return T {
		r = lerp(c1.r, c2.r, t),
		g = lerp(c1.g, c2.g, t),
		b = lerp(c1.b, c2.b, t),
		a = lerp(c1.a, c2.a, t),
	};
}

COLOR_WHITE  := Colorf{1, 1, 1, 1};
COLOR_RED    := Colorf{1, 0, 0, 1};
COLOR_GREEN  := Colorf{0, 1, 0, 1};
COLOR_BLUE   := Colorf{0, 0, 1, 1};
COLOR_BLACK  := Colorf{0, 0, 0, 1};
COLOR_YELLOW := Colorf{1, 1, 0, 1};

Maybe :: union(T: typeid) {
	T,
}

getval :: inline proc(m: Maybe($T)) -> (T, bool) {
	return m.(T);
}