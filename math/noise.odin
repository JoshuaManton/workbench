package math

import "core:math/rand"

get_noise :: proc(x, y: int, seed: int, roughness: f32 = 0.1, octaves: int = 2, ampl: f32 = 1) -> f32 {
    total: f32 = 0;
    d := pow(f32(2), f32(octaves - 1));
    for i in 0..octaves {
        freq := pow(roughness, f32(i)) * ampl;
        amp := pow(roughness, f32(i)) * ampl;
        total += get_interpolated_noise(f32(x) *freq, f32(y)*freq, seed) * amp;
    }

    return total;
}

get_smooth_noise :: proc(x, y: int, seed: int, roughness: f32 = 0.1, octaves: int = 2, ampl: f32 = 1) -> f32 {
    corners := (_get_noise(x-1, y-1, seed) + _get_noise(x+1, y-1, seed) + _get_noise(x-1, y+1, seed) + _get_noise(x+1, y+1, seed)) / 16;
    sides := (_get_noise(x-1, y, seed) + _get_noise(x+1, y, seed) + _get_noise(x, y-1, seed) + _get_noise(x, y+1, seed)) / 8;
    center := _get_noise(x,y, seed) / 4;
    return corners + sides + center;
}

_get_noise :: proc (x, y: int, seed: int) -> f32 {
    return rand.float32() * 2 - 1;
}

get_interpolated_noise :: proc(x,y: f32, seed: int) -> f32 {
    ix := int(x);
    iy := int(y);
    fracx := x - f32(ix);
    fracy := y - f32(iy);

    v1 := get_smooth_noise(ix, iy, seed);
    v2 := get_smooth_noise(ix + 1, iy, seed);
    v3 := get_smooth_noise(ix, iy + 1, seed);
    v4 := get_smooth_noise(ix + 1, iy + 1, seed);
    i1 := lerp(v1, v2, fracx);
    i2 := lerp(v3, v4, fracx);
    return lerp(i1, i2, fracy);
}