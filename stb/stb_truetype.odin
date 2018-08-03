package stb

foreign import stbtt "lib/stb_truetype.lib"
// when ODIN_OS == "windows" do foreign import stbtt "lib/stb_truetype.lib"
// when ODIN_OS == "linux" do foreign import stbtt "lib/stb_truetype.a"

import "core:mem";

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
////
////   INTERFACE
////
////


// private structure
stbtt__buf :: struct {
   data: ^u8,
   cursor, size: i32,
}

//////////////////////////////////////////////////////////////////////////////
//
// TEXTURE BAKING API
//
// If you use this API, you only have to call two functions ever.
//

stbtt_bakedchar :: struct {
   x0,y0,x1,y1: u16, // coordinates of bbox in bitmap
   xoff,yoff,xadvance: f32,
}

stbtt_aligned_quad :: struct {
    x0, y0, s0, t0: f32, // top-left
    x1, y1, s1, t1: f32, // bottom-right
}

Baked_Char :: stbtt_bakedchar;
Aligned_Quad :: stbtt_aligned_quad;


// bindings
@(default_calling_convention="c")
foreign stbtt {
    stbtt_BakeFontBitmap :: proc(data: ^u8, offset: i32, pixel_height: f32, pixels: ^u8, pw, ph, first_char, num_chars: i32, chardata: ^stbtt_bakedchar) -> i32 ---;
    stbtt_GetBakedQuad :: proc(chardata: ^stbtt_bakedchar, pw, ph, char_index: i32, xpos, ypos: ^f32, q: ^stbtt_aligned_quad, opengl_fillrule: i32) ---;
}

// wrappers
bake_font_bitmap :: proc(data: []u8, offset: int, pixel_height: f32, pixels: []u8, pw, ph, first_char, num_chars: int) -> ([]Baked_Char, int) {
    chardata := make([]Baked_Char, num_chars);
    ret := stbtt_BakeFontBitmap(&data[0], i32(offset), pixel_height, &pixels[0], i32(pw), i32(ph), i32(first_char), i32(num_chars), cast(^stbtt_bakedchar)&chardata[0]);
    return chardata, int(ret);
}

get_baked_quad :: proc(chardata: []Baked_Char, pw, ph, char_index: int, xpos, ypos: ^f32, opengl_fillrule: bool) -> (q: Aligned_Quad) {
    stbtt_GetBakedQuad(cast(^stbtt_bakedchar)&chardata[0], i32(pw), i32(ph), i32(char_index), xpos, ypos, &q, i32(opengl_fillrule));
    return Aligned_Quad(q);
}


//////////////////////////////////////////////////////////////////////////////
//
// NEW TEXTURE BAKING API
//
// This provides options for packing multiple fonts into one atlas, not
// perfectly but better than nothing.

stbtt_packedchar :: struct {
   x0, y0, x1, y1: u16,
   xoff, yoff, xadvance: f32,
   xoff2, yoff2: f32,
}

stbtt_pack_range :: struct {
   font_size: f32,
   first_unicode_codepoint_in_range: i32,
   array_of_unicode_codepoints: ^i32,
   num_chars: i32,
   chardata_for_range: ^stbtt_packedchar,
   _, _: u8, // used internally to store oversample info
}

stbtt_pack_context :: struct {
   user_allocator_context, pack_info: rawptr,
   width, height, stride_in_bytes, padding: i32,
   h_oversample, v_oversample: u32,
   pixels: ^u8,
   nodes: rawptr,
};

Packed_Char :: stbtt_packedchar;
Pack_Range :: stbtt_pack_range;
Pack_Context :: stbtt_pack_context;

STBTT_POINT_SIZE :: inline proc(x: $T) -> T { return -x; } // @NOTE: this was a macro

// bindings
@(default_calling_convention="c")
foreign stbtt {
    stbtt_PackBegin :: proc(spc: ^stbtt_pack_context, pixels: ^u8, width, height, stride_in_bytes, padding: i32, alloc_context: rawptr) -> i32 ---;
    stbtt_PackEnd :: proc(spc: ^stbtt_pack_context) ---;
    stbtt_PackFontRange :: proc(spc: ^stbtt_pack_context, fontdata: ^u8, font_index: i32, font_size: f32, first_unicode_char_in_range, num_chars_in_range: i32, chardata_for_range: ^stbtt_packedchar) -> i32 ---;
    stbtt_PackFontRanges :: proc(spc: ^stbtt_pack_context, fontdata: ^u8, font_index: i32, ranges: ^stbtt_pack_range, num_ranges: i32) -> i32 ---;
    stbtt_PackSetOversampling :: proc(spc: ^stbtt_pack_context, h_oversample, v_oversample: u32) ---;
    stbtt_GetPackedQuad :: proc(chardata: ^stbtt_packedchar, pw, ph, char_index: i32, xpos, ypos: ^f32, q: ^stbtt_aligned_quad, align_to_integer: i32) ---;
    stbtt_PackFontRangesGatherRects :: proc(spc: ^stbtt_pack_context, info: ^stbtt_fontinfo, ranges: ^stbtt_pack_range, num_ranges: i32, rects: ^stbrp_rect) -> i32 ---; // NOTE: These are not wrapped
    stbtt_PackFontRangesPackRects :: proc(spc: ^stbtt_pack_context, rects: ^stbrp_rect, num_rects: i32) ---; // NOTE: These are not wrapped
    stbtt_PackFontRangesRenderIntoRects :: proc(spc: ^stbtt_pack_context, info: ^stbtt_fontinfo, ranges: ^stbtt_pack_range, num_ranges: i32, rects: ^stbrp_rect) -> i32 ---; // NOTE: These are not wrapped
}

// wrappers
pack_begin :: proc(pixels: []u8, width, height, stride_in_bytes, padding: int) -> (Pack_Context, bool) {
    spc: Pack_Context;
    ret := stbtt_PackBegin(&spc, &pixels[0], i32(width), i32(height), i32(stride_in_bytes), i32(padding), nil);
    return cast(Pack_Context)spc, ret == 1;
}

pack_end :: proc(spc: ^Pack_Context) {
    stbtt_PackEnd(spc);
}

pack_font_range :: proc(spc: ^Pack_Context, fontdata: []u8, font_index: int, font_size: f32, first_unicode_char_in_range: i32, chardata_for_range: []stbtt_packedchar) -> int {
    ret := stbtt_PackFontRange(spc, &fontdata[0], i32(font_index), f32(font_size), i32(first_unicode_char_in_range), i32(len(chardata_for_range)), &chardata_for_range[0]);
    return cast(int)ret;
}

pack_font_ranges :: proc(spc: ^Pack_Context, fontdata: []u8, font_index: int, ranges: []Pack_Range) -> int {
    ret := stbtt_PackFontRanges(spc, &fontdata[0], i32(font_index), &ranges[0], i32(len(ranges)));
    return cast(int)ret;
}

pack_set_oversampling :: proc(spc: ^Pack_Context, h_oversample, v_oversample: int) {
    stbtt_PackSetOversampling(spc, u32(h_oversample), u32(v_oversample));
}

get_packed_quad :: proc(chardata: []Packed_Char, pw, ph, char_index: int, align_to_integer: bool) -> (f32, f32, Aligned_Quad) {
    xpos, ypos: f32;
    q: Aligned_Quad;
    stbtt_GetPackedQuad(&chardata[0], i32(pw), i32(ph), i32(char_index), &xpos, &ypos, &q, i32(align_to_integer));
    return xpos, ypos, q;
}



//////////////////////////////////////////////////////////////////////////////
//
// FONT LOADING
//
//

stbtt_fontinfo :: struct {
    userdata: rawptr,
    data: ^u8,
    fontstart: i32,

    numGlyphs: i32,

    loca,head,glyf,hhea,hmtx,kern: i32,
    index_map: i32,
    indexToLocFormat: i32,

    cff: stbtt__buf,
    charstrings: stbtt__buf,
    gsubrs: stbtt__buf,
    subrs: stbtt__buf,
    fontdicts: stbtt__buf,
    fdselect: stbtt__buf,
}

Font_Info :: stbtt_fontinfo;

@(default_calling_convention="c")
foreign stbtt {
    stbtt_GetNumberOfFonts :: proc(data: ^u8) -> i32 ---;
    stbtt_GetFontOffsetForIndex :: proc(data: ^u8, index: i32) -> i32 ---;
    stbtt_InitFont :: proc(info: ^stbtt_fontinfo, data: ^u8, offset: i32) -> i32 ---;
}

get_number_of_fonts :: proc(data: []u8) -> int {
    ret := stbtt_GetNumberOfFonts(&data[0]);
    return cast(int)ret;
}

get_font_offset_for_index :: proc(data: []u8, index: int) -> int {
    ret := stbtt_GetFontOffsetForIndex(&data[0], i32(index));
    return cast(int)ret;
}

init_font :: proc(info: ^Font_Info, data: []u8, offset: int) -> bool {
    ret := stbtt_InitFont(info, &data[0], i32(offset));
    return bool(ret != 0);
}


// wrappers

//////////////////////////////////////////////////////////////////////////////
//
// CHARACTER TO GLYPH-INDEX CONVERSIOn

@(default_calling_convention="c")
foreign stbtt {
    stbtt_FindGlyphIndex :: proc(info: ^stbtt_fontinfo, unicode_codepoint: i32) -> i32 ---;
}

find_glyph_index :: proc(info: ^stbtt_fontinfo, unicode_codepoint: int) -> int {
    ret := stbtt_FindGlyphIndex(info, i32(unicode_codepoint));
    return cast(int)ret;
}

//////////////////////////////////////////////////////////////////////////////
//
// CHARACTER PROPERTIES
//

@(default_calling_convention="c")
foreign stbtt {
    stbtt_ScaleForPixelHeight :: proc(info: ^stbtt_fontinfo, pixels: f32) -> f32 ---;
    stbtt_ScaleForMappingEmToPixels :: proc(info: ^stbtt_fontinfo, pixels: f32) -> f32 ---;
    stbtt_GetFontVMetrics :: proc(info: ^stbtt_fontinfo, ascent, descent, lineGap: ^i32) ---;
    stbtt_GetFontVMetricsOS2 :: proc(info: ^stbtt_fontinfo, typoAscent, typoDescent, typoLineGap: ^i32) -> i32 ---;
    stbtt_GetFontBoundingBox :: proc(info: ^stbtt_fontinfo, x0, y0, x1, y1: ^i32) ---;
    stbtt_GetCodepointHMetrics :: proc(info: ^stbtt_fontinfo, codepoint: i32, advanceWidth, leftSideBearing: ^i32) ---;
    stbtt_GetCodepointKernAdvance :: proc(info: ^stbtt_fontinfo, ch1, ch2: i32) -> i32 ---;
    stbtt_GetCodepointBox :: proc(info: ^stbtt_fontinfo, codepoint: i32, x0, y0, x1, y1: ^i32) -> i32 ---;
    stbtt_GetGlyphHMetrics :: proc(info: ^stbtt_fontinfo, glyph_index: i32, advanceWidth, leftSideBearing: ^i32) ---;
    stbtt_GetGlyphKernAdvance :: proc(info: ^stbtt_fontinfo, glyph1, glyph2: i32) -> i32 ---;
    stbtt_GetGlyphBox :: proc(info: ^stbtt_fontinfo, glyph_index: i32, x0, y0, x1, y1: ^i32) -> i32 ---;
}

scale_for_pixel_height :: proc(info: ^stbtt_fontinfo, pixels: f32) -> f32 {
    return stbtt_ScaleForPixelHeight(info, pixels);
}

scale_for_mapping_em_to_pixels :: proc(info: ^stbtt_fontinfo, pixels: f32) -> f32 {
    return stbtt_ScaleForMappingEmToPixels(info, pixels);
}

get_font_v_metrics :: proc(info: ^stbtt_fontinfo) -> (int, int, int) {
    ascent, descent, line_gap: i32;
    stbtt_GetFontVMetrics(info, &ascent, &descent, &line_gap);
    return int(ascent), int(descent), int(line_gap);
}

get_font_v_metrics_os2 :: proc(info: ^stbtt_fontinfo) -> (int, int, int, bool) {
    ascent, descent, line_gap: i32;
    ret := stbtt_GetFontVMetricsOS2(info, &ascent, &descent, &line_gap);
    return int(ascent), int(descent), int(line_gap), bool(ret);
}

get_font_bounding_box :: proc(info: ^stbtt_fontinfo) -> (int, int, int, int) {
    x0, y0, x1, y1: i32;
    stbtt_GetFontBoundingBox(info, &x0, &y0, &x1, &y1);
    return int(x0), int(y0), int(x1), int(y1);
}

get_codepoint_h_metrics :: proc(info: ^stbtt_fontinfo, codepoint: int) -> (int, int) {
    advanceWidth, leftSideBearing: i32;
    stbtt_GetCodepointHMetrics(info, i32(codepoint), &advanceWidth, &leftSideBearing);
    return int(advanceWidth), int(leftSideBearing);
}

get_codepoint_kern_advance :: proc(info: ^stbtt_fontinfo, ch1, ch2: int) -> int {
    ret := stbtt_GetCodepointKernAdvance(info, i32(ch1), i32(ch2));
    return cast(int)ret;
}

get_codepoint_box :: proc(info: ^stbtt_fontinfo, codepoint: int) -> (int, int, int, int, bool) {
    x0, y0, x1, y1: i32;
    ret := stbtt_GetCodepointBox(info, i32(codepoint), &x0, &y0, &x1, &y1);
    return int(x0), int(y0), int(x1), int(y1), bool(ret);
}

get_glyph_h_metrics :: proc(info: ^stbtt_fontinfo, glyph_index: int) -> (int, int) {
    advanceWidth, leftSideBearing: i32;
    stbtt_GetGlyphHMetrics(info, i32(glyph_index), &advanceWidth, &leftSideBearing);
    return int(advanceWidth), int(leftSideBearing);
}

get_glyph_kern_advance :: proc(info: ^stbtt_fontinfo, glyph1, glyph2: int) -> int {
    ret := stbtt_GetGlyphKernAdvance(info, i32(glyph1), i32(glyph2));
    return cast(int)ret;
}

get_glyph_box :: proc(info: ^stbtt_fontinfo, glyph_index: int) -> (int, int, int, int, bool) {
    x0, y0, x1, y1: i32;
    ret := stbtt_GetGlyphBox(info, i32(glyph_index), &x0, &y0, &x1, &y1);
    return int(x0), int(y0), int(x1), int(y1), bool(ret);
}



//////////////////////////////////////////////////////////////////////////////
//
// Signed Distance Function (or Field) rendering
//

@(default_calling_convention="c")
foreign stbtt {
    stbtt_FreeSDF :: proc(bitmap: ^u8, userdata: rawptr) ---;
    stbtt_GetGlyphSDF :: proc(info: ^stbtt_fontinfo, scale: f32, glyph, padding: i32, onedge_value: u8, pixel_dist_scale: f32, width, height, xoff, yoff: ^i32) -> ^u8 ---;
    stbtt_GetCodepointSDF :: proc(info: ^stbtt_fontinfo, scale: f32, codepoint, padding: i32, onedge_value: u8, pixel_dist_scale: f32, width, height, xoff, yoff: ^i32) -> ^u8 ---;
}

free_SDF :: proc(bitmap: []u8, userdata: rawptr) {
    stbtt_FreeSDF(&bitmap[0], userdata);
}


get_glyph_SDF :: proc(info: ^stbtt_fontinfo, scale: f32, glyph, padding: int, onedge_value: u8, pixel_dist_scale: f32) -> ([]u8, int, int, int, int) {
    width, height, xoff, yoff: i32;
    data := stbtt_GetGlyphSDF(info, scale, i32(glyph), i32(padding), onedge_value, pixel_dist_scale, &width, &height, &xoff, &yoff);
    return mem.slice_ptr(data, (int(width)+2*padding)*(int(height)+2*padding)), int(width), int(height), int(xoff), int(yoff);

}

get_codepoint_SDF :: proc(info: ^stbtt_fontinfo, scale: f32, codepoint: rune, padding: int, onedge_value: u8, pixel_dist_scale: f32) -> ([]u8, int, int, int, int) {
    width, height, xoff, yoff: i32;
    data := stbtt_GetCodepointSDF(info, scale, i32(codepoint), i32(padding), onedge_value, pixel_dist_scale, &width, &height, &xoff, &yoff);
    return mem.slice_ptr(data, (int(width)+2*padding)*(int(height)+2*padding)), int(width), int(height), int(xoff), int(yoff);
}



//////////////////////////////////////////////////////////////////////////////
//
// RECT PACK
//

stbrp_coord :: u16; // @WARNING: this assumes `STBRP_LARGE_RECTS` is undefined in the compiled library file

stbrp_rect :: struct {
    id: i32,
    w, h: stbrp_coord,
    x, y: stbrp_coord,
    was_packed: i32,
}
