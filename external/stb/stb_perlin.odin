package stb

// stb_perlin.h(.odin) - v0.3 - perlin noise
// public domain single-file C implementation by Sean Barrett, converted to odin by Lipid
//
// LICENSE
//
//   See end of file.
//
// Documentation:
//
// stb_perlin_noise3 :: proc(x, y, z: f32, x_wrap: int = 0, y_wrap: int = 0, z_wrap: int = 0) -> f32;
// noise3 :: stb_perlin_noise3;
//
// This function computes a random value at the coordinate (x,y,z).
// Adjacent random values are continuous but the noise fluctuates
// its randomness with period 1, i.e. takes on wholly unrelated values
// at integer points. Specifically, this implements Ken Perlin's
// revised noise function from 2002.
//
// The "wrap" parameters can be used to create wraparound noise that
// wraps at powers of two. The numbers MUST be powers of two. Specify
// 0 to mean "don't care". (The noise always wraps every 256 due
// details of the implementation, even if you ask for larger or no
// wrapping.)
//
// Fractal Noise:
//
// Three common fractal noise functions are included, which produce
// a wide variety of nice effects depending on the parameters
// provided. Note that each function will call stb_perlin_noise3
// 'octaves' times, so this parameter will affect runtime.
//
// stb_perlin_ridge_noise3 :: proc(x, y, z: f32,
//                                 lacunarity: f32 = 2.0, gain: f32 = 0.5, offset: f32 = 1.0, octaves: int = 6,
//                                 x_wrap: int = 0, y_wrap: int = 0, z_wrap: int = 0) -> f32;
// ridge_noise3 :: stb_perlin_ridge_noise3;
//
// stb_perlin_fbm_noise3 :: proc(x, y, z: f32,
//                               lacunarity: f32 = 2.0, gain: f32 = 0.5, octaves: int = 6,
//                               x_wrap: int = 0, y_wrap: int = 0, z_wrap: int = 0) -> f32;
// fbm_noise3 :: stb_perlin_fbm_noise3;
//
// stb_perlin_turbulence_noise3 :: proc(x, y, z: f32,
//                                      lacunarity: f32 = 2.0, gain: f32 = 0.5, octaves: int = 6,
//                                      x_wrap: int = 0, y_wrap: int = 0, z_wrap: int = 0) -> f32;
// turbulence_noise3 :: stb_perlin_turbulence_noise3;
//
// Typical values to start playing with:
//     octaves    =   6     -- number of "octaves" of noise3() to sum
//     lacunarity = ~ 2.0   -- spacing between successive octaves (use exactly 2.0 for wrapping output)
//     gain       =   0.5   -- relative weighting applied to each successive octave
//     offset     =   1.0?  -- used to invert the ridges, may need to be larger, not sure
//
//
// Contributors:
//    Jack Mott - additional noise functions
//

// not same permutation table as Perlin's reference to avoid copyright issues;
// Perlin's table can be found at http://mrl.nyu.edu/~perlin/noise/
// @OPTIMIZE: should this be unsigned char instead of int for cache?
stb__perlin_randtab := [512]u8{
   23, 125, 161, 52, 103, 117, 70, 37, 247, 101, 203, 169, 124, 126, 44, 123,
   152, 238, 145, 45, 171, 114, 253, 10, 192, 136, 4, 157, 249, 30, 35, 72,
   175, 63, 77, 90, 181, 16, 96, 111, 133, 104, 75, 162, 93, 56, 66, 240,
   8, 50, 84, 229, 49, 210, 173, 239, 141, 1, 87, 18, 2, 198, 143, 57,
   225, 160, 58, 217, 168, 206, 245, 204, 199, 6, 73, 60, 20, 230, 211, 233,
   94, 200, 88, 9, 74, 155, 33, 15, 219, 130, 226, 202, 83, 236, 42, 172,
   165, 218, 55, 222, 46, 107, 98, 154, 109, 67, 196, 178, 127, 158, 13, 243,
   65, 79, 166, 248, 25, 224, 115, 80, 68, 51, 184, 128, 232, 208, 151, 122,
   26, 212, 105, 43, 179, 213, 235, 148, 146, 89, 14, 195, 28, 78, 112, 76,
   250, 47, 24, 251, 140, 108, 186, 190, 228, 170, 183, 139, 39, 188, 244, 246,
   132, 48, 119, 144, 180, 138, 134, 193, 82, 182, 120, 121, 86, 220, 209, 3,
   91, 241, 149, 85, 205, 150, 113, 216, 31, 100, 41, 164, 177, 214, 153, 231,
   38, 71, 185, 174, 97, 201, 29, 95, 7, 92, 54, 254, 191, 118, 34, 221,
   131, 11, 163, 99, 234, 81, 227, 147, 156, 176, 17, 142, 69, 12, 110, 62,
   27, 255, 0, 194, 59, 116, 242, 252, 19, 21, 187, 53, 207, 129, 64, 135,
   61, 40, 167, 237, 102, 223, 106, 159, 197, 189, 215, 137, 36, 32, 22, 5,

   // and a second copy so we don't need an extra mask or static initializer
   23, 125, 161, 52, 103, 117, 70, 37, 247, 101, 203, 169, 124, 126, 44, 123,
   152, 238, 145, 45, 171, 114, 253, 10, 192, 136, 4, 157, 249, 30, 35, 72,
   175, 63, 77, 90, 181, 16, 96, 111, 133, 104, 75, 162, 93, 56, 66, 240,
   8, 50, 84, 229, 49, 210, 173, 239, 141, 1, 87, 18, 2, 198, 143, 57,
   225, 160, 58, 217, 168, 206, 245, 204, 199, 6, 73, 60, 20, 230, 211, 233,
   94, 200, 88, 9, 74, 155, 33, 15, 219, 130, 226, 202, 83, 236, 42, 172,
   165, 218, 55, 222, 46, 107, 98, 154, 109, 67, 196, 178, 127, 158, 13, 243,
   65, 79, 166, 248, 25, 224, 115, 80, 68, 51, 184, 128, 232, 208, 151, 122,
   26, 212, 105, 43, 179, 213, 235, 148, 146, 89, 14, 195, 28, 78, 112, 76,
   250, 47, 24, 251, 140, 108, 186, 190, 228, 170, 183, 139, 39, 188, 244, 246,
   132, 48, 119, 144, 180, 138, 134, 193, 82, 182, 120, 121, 86, 220, 209, 3,
   91, 241, 149, 85, 205, 150, 113, 216, 31, 100, 41, 164, 177, 214, 153, 231,
   38, 71, 185, 174, 97, 201, 29, 95, 7, 92, 54, 254, 191, 118, 34, 221,
   131, 11, 163, 99, 234, 81, 227, 147, 156, 176, 17, 142, 69, 12, 110, 62,
   27, 255, 0, 194, 59, 116, 242, 252, 19, 21, 187, 53, 207, 129, 64, 135,
   61, 40, 167, 237, 102, 223, 106, 159, 197, 189, 215, 137, 36, 32, 22, 5,
};

stb__perlin_lerp :: proc(a, b, t: f32) -> f32 {
    return a + (b-a) * t;
}

stb__perlin_fastfloor :: proc(a: f32) -> int {
    ai := int(a);
    return (a < f32(ai)) ? ai-1 : ai;
}

// different grad function from Perlin's, but easy to modify to match reference
stb__perlin_grad :: proc(hash: int, x, y, z: f32) -> f32 {
    // NOTE(Lipid) This was [12][4] in the original file, but the literals were only 3 values long.
    // I assumed it was a typo.
    basis := [12][3]f32{
        {  1, 1, 0 },
        { -1, 1, 0 },
        {  1,-1, 0 },
        { -1,-1, 0 },
        {  1, 0, 1 },
        { -1, 0, 1 },
        {  1, 0,-1 },
        { -1, 0,-1 },
        {  0, 1, 1 },
        {  0,-1, 1 },
        {  0, 1,-1 },
        {  0,-1,-1 },
    };

    // perlin's gradient has 12 cases so some get used 1/16th of the time
    // and some 2/16ths. We reduce bias by changing those fractions
    // to 5/64ths and 6/64ths, and the same 4 cases get the extra weight.
    indices := [64]u8{
        0,1,2,3,4,5,6,7,8,9,10,11,
        0,9,1,11,
        0,1,2,3,4,5,6,7,8,9,10,11,
        0,1,2,3,4,5,6,7,8,9,10,11,
        0,1,2,3,4,5,6,7,8,9,10,11,
        0,1,2,3,4,5,6,7,8,9,10,11,
    };

    // if you use reference permutation table, change 63 below to 15 to match reference
    // (this is why the ordering of the table above is funky)
    grad := basis[indices[hash & 63]];
    return grad.x*x + grad.y*y + grad.z*z;
}

noise3 :: stb_perlin_noise3;
stb_perlin_noise3 :: proc(_x, _y, _z: f32, x_wrap := 0, y_wrap := 0, z_wrap := 0) -> f32 {
    u,v,w: f32;
    n000,n001,n010,n011,n100,n101,n110,n111: f32;
    n00,n01,n10,n11: f32;
    n0,n1: f32;

    x := _x;
    y := _y;
    z := _z;

    x_mask := (x_wrap-1) & 255;
    y_mask := (y_wrap-1) & 255;
    z_mask := (z_wrap-1) & 255;
    px := stb__perlin_fastfloor(x);
    py := stb__perlin_fastfloor(y);
    pz := stb__perlin_fastfloor(z);
    x0, x1 := px & x_mask, (px+1) & x_mask;
    y0, y1 := py & y_mask, (py+1) & y_mask;
    z0, z1 := pz & z_mask, (pz+1) & z_mask;
    r0,r1, r00,r01,r10,r11: int;

    stb__perlin_ease :: proc(a: $T) -> T do return ((a*6-15)*a + 10) * a * a * a;

    x -= f32(px); u = stb__perlin_ease(x);
    y -= f32(py); v = stb__perlin_ease(y);
    z -= f32(pz); w = stb__perlin_ease(z);

    r0 = cast(int)stb__perlin_randtab[x0];
    r1 = cast(int)stb__perlin_randtab[x1];

    r00 = cast(int)stb__perlin_randtab[r0+y0];
    r01 = cast(int)stb__perlin_randtab[r0+y1];
    r10 = cast(int)stb__perlin_randtab[r1+y0];
    r11 = cast(int)stb__perlin_randtab[r1+y1];

    n000 = stb__perlin_grad(cast(int)stb__perlin_randtab[r00+z0], x  , y  , z   );
    n001 = stb__perlin_grad(cast(int)stb__perlin_randtab[r00+z1], x  , y  , z-1 );
    n010 = stb__perlin_grad(cast(int)stb__perlin_randtab[r01+z0], x  , y-1, z   );
    n011 = stb__perlin_grad(cast(int)stb__perlin_randtab[r01+z1], x  , y-1, z-1 );
    n100 = stb__perlin_grad(cast(int)stb__perlin_randtab[r10+z0], x-1, y  , z   );
    n101 = stb__perlin_grad(cast(int)stb__perlin_randtab[r10+z1], x-1, y  , z-1 );
    n110 = stb__perlin_grad(cast(int)stb__perlin_randtab[r11+z0], x-1, y-1, z   );
    n111 = stb__perlin_grad(cast(int)stb__perlin_randtab[r11+z1], x-1, y-1, z-1 );

    n00 = stb__perlin_lerp(n000,n001,w);
    n01 = stb__perlin_lerp(n010,n011,w);
    n10 = stb__perlin_lerp(n100,n101,w);
    n11 = stb__perlin_lerp(n110,n111,w);

    n0 = stb__perlin_lerp(n00,n01,v);
    n1 = stb__perlin_lerp(n10,n11,v);

    return stb__perlin_lerp(n0,n1,u);
}

ridge_noise3 :: stb_perlin_ridge_noise3;
stb_perlin_ridge_noise3 :: proc(x, y, z: f32, lacunarity: f32 = 2.0, gain: f32 = 0.5, offset: f32 = 1.0, octaves := 6, x_wrap := 0, y_wrap := 0, z_wrap := 0) -> f32 {
    i: int;
    frequency := f32(1.0);
    prev := f32(1.0);
    amplitude := f32(0.5);
    sum := f32(0.0);

    for i in 0..octaves {
        r := cast(f32)stb_perlin_noise3(x*frequency,y*frequency,z*frequency,x_wrap,y_wrap,z_wrap);
        r = r<0 ? -r : r; // fabs()
        r = offset - r;
        r = r*r;
        sum += r*amplitude*prev;
        prev = r;
        frequency *= lacunarity;
        amplitude *= gain;
    }
    return sum;
}

fbm_noise3 :: stb_perlin_fbm_noise3;
stb_perlin_fbm_noise3 :: proc(x, y, z: f32, lacunarity: f32 = 2.0, gain: f32 = 0.5, octaves := 6, x_wrap := 0, y_wrap := 0, z_wrap := 0) -> f32 {
    i: int;
    frequency := f32(1.0);
    amplitude := f32(1.0);
    sum := f32(0.0);

    for i in 0..octaves {
        sum += stb_perlin_noise3(x*frequency,y*frequency,z*frequency,x_wrap,y_wrap,z_wrap)*amplitude;
        frequency *= lacunarity;
        amplitude *= gain;
    }
    return sum;
}

turbulence_noise3 :: stb_perlin_turbulence_noise3;
stb_perlin_turbulence_noise3 :: proc(x, y, z: f32, lacunarity: f32 = 2.0, gain: f32 = 0.5, octaves := 6, x_wrap := 0, y_wrap := 0, z_wrap := 0) -> f32 {
    i: int;
    frequency := f32(1.0);
    amplitude := f32(1.0);
    sum := f32(0.0);

    for i in 0..octaves {
        r := stb_perlin_noise3(x*frequency,y*frequency,z*frequency,x_wrap,y_wrap,z_wrap)*amplitude;
        r = r<0 ? -r : r; // fabs()
        sum += r;
        frequency *= lacunarity;
        amplitude *= gain;
    }
    return sum;
}

/*
------------------------------------------------------------------------------
Public Domain (www.unlicense.org)
This is free and unencumbered software released into the public domain.
Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
software, either in source code form or as a compiled binary, for any purpose,
commercial or non-commercial, and by any means.
In jurisdictions that recognize copyright laws, the author or authors of this
software dedicate any and all copyright interest in the software to the public
domain. We make this dedication for the benefit of the public at large and to
the detriment of our heirs and successors. We intend this dedication to be an
overt act of relinquishment in perpetuity of all present and future rights to
this software under copyright law.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------
*/