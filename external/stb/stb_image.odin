package stb

/*
	Taken from https://gist.github.com/gingerBill/17ed98d3312a56d3e515f35e093a1b8f, with some minor modifications
*/
foreign import stbi "lib/stb_image.lib"
// when ODIN_OS == "windows" do foreign import stbi "lib/stb_image.lib"
// when ODIN_OS == "linux" do foreign import stbi "lib/stb_image.a"

//
// load image by filename, open file, or memory buffer
//
Io_Callbacks :: struct {
	read: proc "c" (user: rawptr, data: ^u8, size: i32) -> i32, // fill 'data' with 'size' u8s.  return number of u8s actually read
	skip: proc "c" (user: rawptr, n: i32),                        // skip the next 'n' u8s, or 'unget' the last -n u8s if negative
	eof:  proc "c" (user: rawptr) -> i32,                         // returns nonzero if we are at end of file/data
}

@(default_calling_convention="c", link_prefix="stbi_")
foreign stbi {
	////////////////////////////////////
	//
	// 8-bits-per-channel interface
	//
	load                :: proc(filename: ^u8,                     x, y, channels_in_file: ^i32, desired_channels: i32) -> ^u8 ---;
	load_from_memory    :: proc(buffer: ^u8, len: i32,             x, y, channels_in_file: ^i32, desired_channels: i32) -> ^u8 ---;
	load_from_callbacks :: proc(clbk: ^Io_Callbacks, user: rawptr, x, y, channels_in_file: ^i32, desired_channels: i32) -> ^u8 ---;

	////////////////////////////////////
	//
	// 16-bits-per-channel interface
	//
	load_16 :: proc(filename: ^u8, x, y, channels_in_file: ^i32, desired_channels: i32) -> ^u16 ---;

	////////////////////////////////////
	//
	// float-per-channel interface
	//
	loadf                 :: proc(filename: ^u8,                     x, y, channels_in_file: ^i32, desired_channels: i32) -> ^f32 ---;
	loadf_from_memory     :: proc(buffer: ^u8, len: i32,             x, y, channels_in_file: ^i32, desired_channels: i32) -> ^f32 ---;
	loadf_from_callbacks  :: proc(clbk: ^Io_Callbacks, user: rawptr, x, y, channels_in_file: ^i32, desired_channels: i32) -> ^f32 ---;


	hdr_to_ldr_gamma :: proc(gamma: f32) ---;
	hdr_to_ldr_scale :: proc(scale: f32) ---;

	is_hdr_from_callbacks :: proc(clbk: ^Io_Callbacks, user: rawptr) -> i32 ---;
	is_hdr_from_memory    :: proc(buffer: ^u8, len: i32) -> i32 ---;

	is_hdr :: proc(filename: ^u8) -> i32 ---;

	// get a VERY brief reason for failure
	// NOT THREADSAFE
	failure_reason :: proc() -> ^u8 ---;

	// free the loaded image -- this is just free()
	image_free :: proc(retval_from_load: rawptr) ---;

	// get image dimensions & components without fully decoding
	info                :: proc(filename: ^u8,                     x, y, comp: ^i32) -> i32 ---;
	info_from_memory    :: proc(buffer: ^u8, len: i32,             x, y, comp: ^i32) -> i32 ---;
	info_from_callbacks :: proc(clbk: ^Io_Callbacks, user: rawptr, x, y, comp: ^i32) -> i32 ---;

	// for image formats that explicitly notate that they have premultiplied alpha,
	// we just return the colors as stored in the file. set this flag to force
	// unpremultiplication. results are undefined if the unpremultiply overflow.
	set_unpremultiply_on_load :: proc (flag_true_if_should_unpremultiply: i32) ---;


	// indicate whether we should process iphone images back to canonical format,
	// or just pass them through "as-is"
	convert_iphone_png_to_rgb :: proc(flag_true_if_should_convert: i32) ---;

	// flip the image vertically, so the first pixel in the output array is the bottom left
	set_flip_vertically_on_load :: proc(flag_true_if_should_flip: i32) ---;

	// ZLIB client - used by PNG, available for other purposes
	zlib_decode_malloc                      :: proc(buffer: ^u8, len: i32,               outlen: ^i32) -> ^u8 ---;
	zlib_decode_malloc_guesssize            :: proc(buffer: ^u8, len, initial_size: i32, outlen: ^i32) -> ^u8 ---;
	zlib_decode_malloc_guesssize_headerflag :: proc(buffer: ^u8, len, initial_size: i32, outlen: ^i32, parse_header: i32) -> ^u8 ---;

	zlib_decode_buffer          :: proc(out_buffer: ^u8, olen: i32, in_buffer: ^u8, ilen: i32) -> i32 ---;
	zlib_decode_noheader_malloc :: proc(buffer:     ^u8, len:  i32, outlen: ^i32) -> ^u8 ---;
	zlib_decode_noheader_buffer :: proc(obuffer:    ^u8, olen: i32, ibuffer: ^u8, ilen: i32) -> i32 ---;
}


main :: proc() {

}