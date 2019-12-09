package gpu

when !#defined(GPU_BACKEND) || GPU_BACKEND == "OPENGL" {

using import "core:runtime"
      import "core:fmt"
      import "core:strings"
      import "core:mem"
      import "core:os"

using import "../math"
using import "../types"
using import "../basic"
using import "../logging"

      import odingl "../external/gl"

init_opengl :: proc(version_major, version_minor: int, set_proc_address: proc(rawptr, cstring)) {
	odingl.load_up_to(version_major, version_minor, set_proc_address);
}

Shader_Program :: distinct u32;
Graphics_Buffer :: distinct u32;
FBO :: distinct u32;
VAO :: distinct u32;
VBO :: distinct u32;
EBO :: distinct u32;
TextureId :: distinct u32;
RBO :: distinct u32;
Location :: distinct i32;

gen_vao :: inline proc(loc := #caller_location) -> VAO {
	vao: u32;
	odingl.GenVertexArrays(1, &vao);
	log_errors(#procedure, loc);
	return cast(VAO)vao;
}

bind_vao :: inline proc(vao: VAO, loc := #caller_location) {
	odingl.BindVertexArray(cast(u32)vao);
}

delete_vao :: inline proc(_vao: VAO, loc := #caller_location) {
	vao := _vao;
	odingl.DeleteVertexArrays(1, cast(^u32)&vao);
	log_errors(#procedure, loc);
}

gen_vbo :: inline proc(loc := #caller_location) -> VBO {
	vbo := cast(VBO)gen_buffer(loc);
	return vbo;
}

gen_ebo :: inline proc(loc := #caller_location) -> EBO {
	ebo := cast(EBO)gen_buffer(loc);
	return ebo;
}

gen_buffer :: inline proc(loc := #caller_location) -> Graphics_Buffer {
	buffer: u32;
	odingl.GenBuffers(1, &buffer);
	log_errors(#procedure, loc);
	return cast(Graphics_Buffer)buffer;
}

gen_framebuffer :: inline proc(loc := #caller_location) -> FBO {
	buffer: u32;
	odingl.GenFramebuffers(1, &buffer);
	log_errors(#procedure, loc);
	return cast(FBO)buffer;
}

gen_renderbuffer :: inline proc(loc := #caller_location) -> RBO {
	buffer: u32;
	odingl.GenRenderbuffers(1, &buffer);
	log_errors(#procedure, loc);
	return cast(RBO)buffer;
}

// bind_buffer :: proc{bind_vbo, bind_ebo, bind_fbo, bind_rbo};
bind_vbo :: inline proc(vbo: VBO, loc := #caller_location) {
	odingl.BindBuffer(odingl.ARRAY_BUFFER, cast(u32)vbo);
	log_errors(#procedure, loc);
}
bind_ibo :: bind_ebo;
bind_ebo :: inline proc(ebo: EBO, loc := #caller_location) {
	odingl.BindBuffer(odingl.ELEMENT_ARRAY_BUFFER, cast(u32)ebo);
	log_errors(#procedure, loc);
}
bind_fbo :: inline proc(frame_buffer: FBO, loc := #caller_location) {
	odingl.BindFramebuffer(odingl.FRAMEBUFFER, u32(frame_buffer));
	log_errors(#procedure, loc);
}
bind_rbo :: inline proc(render_buffer: RBO, loc := #caller_location) {
	odingl.BindRenderbuffer(odingl.RENDERBUFFER, u32(render_buffer));
	log_errors(#procedure, loc);
}

delete_buffer :: proc{delete_buffer_vbo, delete_buffer_ebo};
delete_buffer_vbo :: inline proc(_vbo: VBO, loc := #caller_location) {
	vbo := _vbo;
	odingl.DeleteBuffers(1, cast(^u32)&vbo);
	log_errors(#procedure, loc);
}
delete_buffer_ebo :: inline proc(_ebo: EBO, loc := #caller_location) {
	ebo := _ebo;
	odingl.DeleteBuffers(1, cast(^u32)&ebo);
	log_errors(#procedure, loc);
}

buffer_vertices :: inline proc(vertices: []$Vertex_Type, loc := #caller_location) {
	odingl.BufferData(odingl.ARRAY_BUFFER, size_of(Vertex_Type) * len(vertices), mem.raw_data(vertices), odingl.STATIC_DRAW);
	log_errors(#procedure, loc);
}
buffer_elements :: inline proc(elements: []u32, loc := #caller_location) {
	odingl.BufferData(odingl.ELEMENT_ARRAY_BUFFER, size_of(u32) * len(elements), mem.raw_data(elements), odingl.STATIC_DRAW);
	log_errors(#procedure, loc);
}



draw_arrays :: inline proc(draw_mode: Draw_Mode, first: int, count: int) {
	odingl.DrawArrays(cast(u32)draw_mode, cast(i32)first, cast(i32)count);
	log_errors(#procedure);
}

draw_elements :: inline proc(draw_mode: Draw_Mode, count: int, type: Draw_Elements_Type, indices: rawptr) { // todo(josh): this is a pretty shitty wrapper
	odingl.DrawElements(cast(u32)draw_mode, i32(count), cast(u32)type, indices);
	log_errors(#procedure);
}
draw_elephants :: draw_elements;



scissor :: proc(rect: [4]int, loc := #caller_location) {
	odingl.Enable(odingl.SCISSOR_TEST);
	odingl.Scissor(rect[0], rect[1], rect[2], rect[3]);
	log_errors(#procedure, loc);
}
unscissor :: proc(screen_width, screen_height: f32, loc := #caller_location) {
	odingl.Disable(odingl.SCISSOR_TEST);
	odingl.Scissor(0, 0, screen_width, screen_height); // todo(josh): we might not need this line, if we disable the scissor test wouldn't that be enough?
	log_errors(#procedure, loc);
}


enable :: inline proc(bits: Capabilities, loc := #caller_location) {
	odingl.Enable(transmute(u32)bits);
	log_errors(#procedure, loc);
}
disable :: inline proc(bits: Capabilities, loc := #caller_location) {
	odingl.Disable(transmute(u32)bits);
	log_errors(#procedure, loc);
}

is_enabled :: inline proc(bits: Capabilities, loc := #caller_location) -> bool {
	b := odingl.IsEnabled(transmute(u32)bits);
	log_errors(#procedure, loc);
	return b == odingl.TRUE;
}



cull_face :: inline proc(face: Polygon_Face, loc := #caller_location) {
	odingl.CullFace(transmute(u32)face);
	log_errors(#procedure, loc);
}



blend_func :: proc(sfactor, dfactor: Blend_Factors, loc := #caller_location) {
	odingl.BlendFunc(transmute(u32)sfactor, transmute(u32)dfactor);
	log_errors(#procedure, loc);
}



set_clear_color :: inline proc(color: Colorf, loc := #caller_location) {
	odingl.ClearColor(color.r, color.g, color.b, color.a);
	log_errors(#procedure, loc);
}
clear_screen :: proc(bits: Clear_Flags, loc := #caller_location) {
	odingl.Clear(transmute(u32)bits);
	log_errors(#procedure, loc);
}



viewport :: proc(x1, y1, x2, y2: int, loc := #caller_location) {
	odingl.Viewport(cast(i32)x1, cast(i32)y1, cast(i32)x2, cast(i32)y2);
	log_errors(#procedure, loc);
}



polygon_mode :: proc(face: Polygon_Face, mode: Polygon_Mode, loc := #caller_location) {
	odingl.PolygonMode(cast(u32)face, cast(u32)mode);
	log_errors(#procedure, loc);
}



//
// Shaders
//

load_shader_files :: inline proc(vs, fs: string) -> (Shader_Program, bool) {
	vs_code, ok1 := os.read_entire_file(vs);
	if !ok1 {
		logln("Couldn't open shader file: ", vs);
		return Shader_Program{}, false;
	}
	defer delete(vs_code);

	fs_code, ok2 := os.read_entire_file(fs);
	if !ok2 {
		logln("Couldn't open shader file: ", fs);
		return Shader_Program{}, false;
	}
	defer delete(fs_code);

	program, ok := load_shader_vert_frag(cast(string)vs_code, cast(string)fs_code);
	return cast(Shader_Program)program, ok;
}

load_shader_vert_frag :: proc(vs_code, fs_code: string) -> (program: Shader_Program, success: bool) {
    vertex_shader_id, ok1 := compile_shader_from_text(vs_code, .VERTEX_SHADER);
    defer odingl.DeleteShader(vertex_shader_id);

    fragment_shader_id, ok2 := compile_shader_from_text(fs_code, .FRAGMENT_SHADER);
    defer odingl.DeleteShader(fragment_shader_id);

    if !ok1 || !ok2 {
        return 0, false;
    }

    program_id, ok := create_and_link_program([]u32{vertex_shader_id, fragment_shader_id});
    if !ok {
        return 0, false;
    }

    // print_uniforms(cast(Shader_Program)program_id);

    return cast(Shader_Program)program_id, true;
}

load_shader_compute :: proc(source: string) -> (program: Shader_Program, success: bool) {
    shader, ok1 := compile_shader_from_text(source, .COMPUTE_SHADER);
    defer odingl.DeleteShader(shader);
    if !ok1 do return 0, false;

    program_id, ok2 := create_and_link_program([]u32{shader});
    if !ok2 do return 0, false;

    return cast(Shader_Program)program_id, true;
}
print_uniforms :: proc(shader: Shader_Program) {
    count: i32;
    odingl.GetProgramiv(cast(u32)shader, odingl.ACTIVE_UNIFORMS, &count);
    logln("Active Uniforms: ", count);
    for i in 0..<count {
        name: [32]byte;
        name_len: i32;
        size_of_uniform: i32;
        uniform_type: u32;
        odingl.GetActiveUniform(cast(u32)shader, cast(u32)i, len(name), &name_len, &size_of_uniform, &uniform_type, &name[0]);
        logln("Uniform #", i, " Type: ", uniform_type, " Name: ", cast(string)name[:name_len]);
    }
}



use_program :: inline proc(program: Shader_Program, loc := #caller_location) {
	odingl.UseProgram(cast(u32)program);
	log_errors(#procedure, loc);
}

delete_shader :: inline proc(program: Shader_Program, loc := #caller_location) {
	odingl.DeleteShader(cast(u32)program);
	log_errors(#procedure, loc);
}

// Shader checking and linking checking are identical
// except for calling differently named GL functions
// it's a bit ugly looking, but meh
check_error :: proc(id: u32, type_: odingl.Shader_Type, status: u32,
                    iv_func: proc "c" (u32, u32, ^i32),
                    log_func: proc "c" (u32, i32, ^i32, ^u8)) -> bool {
    result, info_log_length: i32;
    iv_func(id, status, &result);
    iv_func(id, odingl.INFO_LOG_LENGTH, &info_log_length);

    if result == 0 {
        error_message := make([]u8, info_log_length);
        defer delete(error_message);

        log_func(id, i32(info_log_length), nil, &error_message[0]);
        fmt.eprintf("Error in %v:\n%s", type_, string(error_message[0:len(error_message)-1]));

        return true;
    }

    return false;
}

// Compiling shaders are identical for any shader (vertex, geometry, fragment, tesselation, (maybe compute too))
compile_shader_from_text :: proc(_shader_code: string, shader_type: odingl.Shader_Type) -> (u32, bool) {
	shader_code := _shader_code;
    shader_id := odingl.CreateShader(cast(u32)shader_type);
    length := i32(len(shader_code));
    odingl.ShaderSource(shader_id, 1, (^^u8)(&shader_code), &length);
    odingl.CompileShader(shader_id);

    if check_error(shader_id, shader_type, odingl.COMPILE_STATUS, odingl.GetShaderiv, odingl.GetShaderInfoLog) {
        return 0, false;
    }

    return shader_id, true;
}

// only used once, but I'd just make a subprocedure(?) for consistency
create_and_link_program :: proc(shader_ids: []u32) -> (u32, bool) {
    program_id := odingl.CreateProgram();
    for id in shader_ids {
        odingl.AttachShader(program_id, id);
    }
    odingl.LinkProgram(program_id);

    if check_error(program_id, odingl.Shader_Type.SHADER_LINK, odingl.LINK_STATUS, odingl.GetProgramiv, odingl.GetProgramInfoLog) {
        return 0, false;
    }

    return program_id, true;
}







gen_texture :: inline proc(loc := #caller_location) -> TextureId {
	texture: u32;
	odingl.GenTextures(1, &texture);
	log_errors(#procedure, loc);
	return cast(TextureId)texture;
}

bind_texture_1d :: inline proc(texture: TextureId, loc := #caller_location) {
	odingl.BindTexture(odingl.TEXTURE_1D, cast(u32)texture);
	log_errors(#procedure, loc);
}

bind_texture_2d :: inline proc(texture: TextureId, loc := #caller_location) {
	odingl.BindTexture(odingl.TEXTURE_2D, cast(u32)texture);
	log_errors(#procedure, loc);
}

bind_texture_3d :: inline proc(texture: TextureId, loc := #caller_location) {
	odingl.BindTexture(odingl.TEXTURE_3D, cast(u32)texture);
	log_errors(#procedure, loc);
}

delete_texture :: inline proc(_texture: TextureId, loc := #caller_location) {
	t := _texture;
	odingl.DeleteTextures(1, cast(^u32)&t);
	log_errors(#procedure, loc);
}

delete_fbo :: proc(_fbo: FBO, loc := #caller_location) {
	fbo := _fbo;
	odingl.DeleteFramebuffers(1, cast(^u32)&fbo);
	log_errors(#procedure, loc);
}

delete_rbo :: proc(_rbo: RBO, loc := #caller_location) {
	rbo := _rbo;
	odingl.DeleteRenderbuffers(1, cast(^u32)&rbo);
	log_errors(#procedure, loc);
}

tex_image_2d :: proc(lod: i32,
					 internal_format: Internal_Color_Format,
					 width: i32, height: i32,
					 border: i32,
					 format: Pixel_Data_Format,
					 type: Texture2D_Data_Type,
					 data: rawptr,
					 loc := #caller_location) {

    odingl.TexImage2D(cast(u32)Texture_Target.Texture2D, lod, cast(i32)internal_format, width, height, border, cast(u32)format, cast(u32)type, data);
	log_errors(#procedure, loc);
}

tex_image_3d :: proc(lod: i32,
					 internal_format: Internal_Color_Format,
					 width, height, depth: i32,
					 border: i32,
					 format: Pixel_Data_Format,
					 type: Texture2D_Data_Type,
					 data: rawptr,
					 loc := #caller_location) {

    odingl.TexImage3D(cast(u32)Texture_Target.Texture3D, lod, cast(i32)internal_format, width, height, depth, border, cast(u32)format, cast(u32)type, data);
	log_errors(#procedure, loc);
}

get_tex_image :: proc(target: Texture_Target, format: Pixel_Data_Format, type: Texture2D_Data_Type, data: rawptr, loc := #caller_location) {
	odingl.GetTexImage(cast(u32)target, 0, cast(u32)format, cast(u32)type, data);
	log_errors(#procedure, loc);
}

tex_parameteri :: proc(target: Texture_Target, pname: Texture_Parameter, param: Texture_Parameter_Value, loc := #caller_location) {
    odingl.TexParameteri(cast(u32)target, cast(u32)pname, cast(i32)param);
	log_errors(#procedure, loc);
}

tex_parameterfv :: proc(target: Texture_Target, pname: Texture_Parameter, floats: ^f32, loc := #caller_location) {
    odingl.TexParameterfv(cast(u32)target, cast(u32)pname, floats);
	log_errors(#procedure, loc);
}

tex_sub_image2d :: proc(target: Texture_Target,
	                    lod: i32,
	                    xoffset: i32,
	                    yoffset: i32,
	                    width: i32,
	                    height: i32,
	                    format: Pixel_Data_Format,
	                    type: Texture2D_Data_Type,
	                    pixels: rawptr,
						loc := #caller_location) {

	odingl.TexSubImage2D(cast(u32)target, lod, xoffset, yoffset, width, height, cast(u32)format, cast(u32)type, pixels);
	log_errors(#procedure, loc);
}


// this is a shitty wrapper
draw_buffer :: proc(thing: u32, loc := #caller_location) {
	odingl.DrawBuffer(thing);
	log_errors(#procedure, loc);
}
draw_buffers :: proc(bufs: []Framebuffer_Attachment, loc := #caller_location) {
	#assert(size_of(Framebuffer_Attachment) == size_of(u32));
	bufs_u32 := transmute([]u32)bufs;
	odingl.DrawBuffers(cast(i32)len(bufs), &bufs_u32[0]);
	log_errors(#procedure, loc);
}
// this is a shitty wrapper
read_buffer :: proc(thing: u32, loc := #caller_location) {
	odingl.ReadBuffer(thing);
	log_errors(#procedure, loc);
}

framebuffer_texture2d :: proc(attachment: Framebuffer_Attachment, texture: TextureId) {
	odingl.FramebufferTexture2D(odingl.FRAMEBUFFER, cast(u32)attachment, odingl.TEXTURE_2D, cast(u32)texture, 0);
}

framebuffer_renderbuffer :: proc(attachment: Framebuffer_Attachment, rbo: RBO) {
	odingl.FramebufferRenderbuffer(odingl.FRAMEBUFFER, cast(u32)attachment, odingl.RENDERBUFFER, cast(u32)rbo);
}

assert_framebuffer_complete :: proc() {
	if odingl.CheckFramebufferStatus(odingl.FRAMEBUFFER) != odingl.FRAMEBUFFER_COMPLETE {
		panic("Failed to setup frame buffer");
	}
}

renderbuffer_storage :: proc(storage: Renderbuffer_Storage, width: i32, height: i32) {
	odingl.RenderbufferStorage(odingl.RENDERBUFFER, cast(u32)storage, width, height);
}


// ActiveTexture() is guaranteed to go from 0-47 on all implementations of OpenGL, but can go higher on some
active_texture :: inline proc(texture_idx: u32, loc := #caller_location) {
	odingl.ActiveTexture(odingl.TEXTURE0 + texture_idx);
	log_errors(#procedure, loc);
}

active_texture0 :: inline proc(loc := #caller_location) {
	odingl.ActiveTexture(odingl.TEXTURE0);
	log_errors(#procedure, loc);
}

active_texture1 :: inline proc(loc := #caller_location) {
	odingl.ActiveTexture(odingl.TEXTURE1);
	log_errors(#procedure, loc);
}

active_texture2 :: inline proc(loc := #caller_location) {
	odingl.ActiveTexture(odingl.TEXTURE2);
	log_errors(#procedure, loc);
}

active_texture3 :: inline proc(loc := #caller_location) {
	odingl.ActiveTexture(odingl.TEXTURE3);
	log_errors(#procedure, loc);
}

active_texture4 :: inline proc(loc := #caller_location) {
	odingl.ActiveTexture(odingl.TEXTURE4);
	log_errors(#procedure, loc);
}

c_string_buffer: [4096]byte;
c_string :: proc(fmt_: string, args: ..any) -> ^byte {
    s := fmt.bprintf(c_string_buffer[:], fmt_, ..args);
    c_string_buffer[len(s)] = 0;
    return cast(^byte)&c_string_buffer[0];
}



get_uniform_location :: inline proc(program: Shader_Program, str: cstring, loc := #caller_location) -> Location {
	uniform_loc := odingl.GetUniformLocation(cast(u32)program, cast(^u8)str);
	log_errors(#procedure, loc);
	return cast(Location)uniform_loc;
}

get_attrib_location :: inline proc(program: Shader_Program, str: cstring, loc := #caller_location) -> Location {
	attrib_loc := odingl.GetAttribLocation(cast(u32)program, cast(^u8)str);
	log_errors(#procedure, loc);
	return cast(Location)attrib_loc;
}

set_vertex_format :: proc{set_vertex_format_poly, set_vertex_format_ti};
set_vertex_format_poly :: proc($Type: typeid, loc := #caller_location) {
	set_vertex_format(type_info_of(Type), loc);
}
set_vertex_format_ti :: proc(_ti: ^Type_Info, loc := #caller_location) {
	log_errors("set_vertex_format_ti start", loc);

	ti := type_info_base(_ti).variant.(Type_Info_Struct);

	for name, _i in ti.names {
		i := cast(u32)_i;
		offset := ti.offsets[i];
		offset_in_struct := rawptr(uintptr(offset));
		num_elements: i32;
		type_of_elements: u32;
		is_int := false;

		switch ti.types[i].id {
			case Vec2: {
				num_elements = 2;
				type_of_elements = odingl.FLOAT;
			}
			case Vec3: {
				num_elements = 3;
				type_of_elements = odingl.FLOAT;
			}
			case Vec4, Colorf: {
				num_elements = 4;
				type_of_elements = odingl.FLOAT;
			}
			case Colori: {
				num_elements = 4;
				type_of_elements = odingl.UNSIGNED_BYTE;
			}
			case f64: {
				num_elements = 1;
				type_of_elements = odingl.DOUBLE;
			}
			case f32: {
				num_elements = 1;
				type_of_elements = odingl.FLOAT;
			}
			case i32: {
				num_elements = 1;
				type_of_elements = odingl.INT;
				is_int = true;
			}
			case u32: {
				num_elements = 1;
				type_of_elements = odingl.UNSIGNED_INT;
				is_int = true;
			}
			case i16: {
				num_elements = 1;
				type_of_elements = odingl.SHORT;
				is_int = true;
			}
			case u16: {
				num_elements = 1;
				type_of_elements = odingl.UNSIGNED_SHORT;
				is_int = true;
			}
			case i8: {
				num_elements = 1;
				type_of_elements = odingl.BYTE;
				is_int = true;
			}
			case u8: {
				num_elements = 1;
				type_of_elements = odingl.UNSIGNED_BYTE;
				is_int = true;
			}
			case [BONES_PER_VERTEX]u32: {
				num_elements = BONES_PER_VERTEX;
				type_of_elements = odingl.UNSIGNED_INT;
				is_int = true;
			}
			case [BONES_PER_VERTEX]f32: {
				num_elements = BONES_PER_VERTEX;
				type_of_elements = odingl.FLOAT;
			}
			case: {
				panic(fmt.tprintf("UNSUPPORTED TYPE IN VERTEX FORMAT - %s: %s\n", name, ti.types[i].id));
			}
		}

		odingl.EnableVertexAttribArray(i);
		log_errors("set_vertex_format: EnableVertexAttribArray", loc);
		// logln(i, num_elements, type_of_elements, cast(i32)_ti.size, offset_in_struct);
		if is_int {
			odingl.VertexAttribIPointer(i, num_elements, type_of_elements, cast(i32)_ti.size, offset_in_struct);
		} else {
			odingl.VertexAttribPointer(i, num_elements, type_of_elements, odingl.FALSE, cast(i32)_ti.size, offset_in_struct);
		}

		log_errors("set_vertex_format: VertexAttribPointer", loc);
	}
}



get_int :: inline proc(pname: u32, loc := #caller_location) -> i32 {
	i: i32;
	odingl.GetIntegerv(pname, &i);
	log_errors(#procedure, loc);
	return i;
}

get_current_shader :: inline proc(loc := #caller_location) -> Shader_Program {
	id := get_int(odingl.CURRENT_PROGRAM, loc);
	return cast(Shader_Program)id;
}



uniform_int :: inline proc(program: Shader_Program, name: cstring, p: i32, loc := #caller_location) {
	uniform1i(program, name, p, loc);
}
uniform_int_array :: inline proc(program: Shader_Program, name: cstring, p: []i32, loc := #caller_location) {
	uniform1iv(program, name, cast(i32)len(p), &p[0], loc);
}

uniform_float :: inline proc(program: Shader_Program, name: cstring, p: f32, loc := #caller_location) {
	uniform1f(program, name, p, loc);
}
uniform_float_array :: inline proc(program: Shader_Program, name: cstring, p: []f32, loc := #caller_location) {
	uniform1fv(program, name, cast(i32)len(p), &p[0], loc);
}

uniform_vec2 :: inline proc(program: Shader_Program, name: cstring, p: Vec2, loc := #caller_location) {
	uniform2f(program, name, expand_to_tuple(p), loc);
}
uniform_vec2_array :: inline proc(program: Shader_Program, name: cstring, p: []Vec2, loc := #caller_location) {
	uniform2fv(program, name, cast(i32)len(p), &p[0].x, loc);
}
uniform_vec3 :: inline proc(program: Shader_Program, name: cstring, p: Vec3, loc := #caller_location) {
	uniform3f(program, name, expand_to_tuple(p), loc);
}
uniform_vec3_array :: inline proc(program: Shader_Program, name: cstring, p: []Vec3, loc := #caller_location) {
	uniform3fv(program, name, cast(i32)len(p), &p[0].x, loc);
}
uniform_vec4 :: inline proc(program: Shader_Program, name: cstring, p: Vec4, loc := #caller_location) {
	uniform4f(program, name, expand_to_tuple(p), loc);
}
uniform_vec4_array :: inline proc(program: Shader_Program, name: cstring, p: []Vec4, loc := #caller_location) {
	uniform4fv(program, name, cast(i32)len(p), &p[0].x, loc);
}

uniform_mat4 :: inline proc(program: Shader_Program, name: cstring, p: ^Mat4, transpose := false, loc := #caller_location) {
	uniform_matrix4fv(program, name, 1, transpose, &p[0][0]);
}
uniform_mat4_array :: inline proc(program: Shader_Program, name: cstring, p: []Mat4, transpose := false, loc := #caller_location) {
	uniform_matrix4fv(program, name, cast(i32)len(p), transpose, &p[0][0][0]);
}



uniform1f :: inline proc(program: Shader_Program, name: cstring, v0: f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform1f(cast(i32)location, v0);
	log_errors(#procedure, loc);
}
uniform2f :: inline proc(program: Shader_Program, name: cstring, v0: f32, v1: f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform2f(cast(i32)location, v0, v1);
	log_errors(#procedure, loc);
}
uniform3f :: inline proc(program: Shader_Program, name: cstring, v0: f32, v1: f32, v2: f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform3f(cast(i32)location, v0, v1, v2);
	log_errors(#procedure, loc);
}
uniform4f :: inline proc(program: Shader_Program, name: cstring, v0: f32, v1: f32, v2: f32, v3: f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform4f(cast(i32)location, v0, v1, v2, v3);
	log_errors(#procedure, loc);
}
uniform1i :: inline proc(program: Shader_Program, name: cstring, v0: i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform1i(cast(i32)location, v0);
	log_errors(#procedure, loc);
}
uniform2i :: inline proc(program: Shader_Program, name: cstring, v0: i32, v1: i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform2i(cast(i32)location, v0, v1);
	log_errors(#procedure, loc);
}
uniform3i :: inline proc(program: Shader_Program, name: cstring, v0: i32, v1: i32, v2: i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform3i(cast(i32)location, v0, v1, v2);
	log_errors(#procedure, loc);
}
uniform4i :: inline proc(program: Shader_Program, name: cstring, v0: i32, v1: i32, v2: i32, v3: i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform4i(cast(i32)location, v0, v1, v2, v3);
	log_errors(#procedure, loc);
}



uniform1fv :: inline proc(program: Shader_Program, name: cstring, count: i32, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform1fv(cast(i32)location, count, value);
	log_errors(#procedure, loc);
}
uniform1iv :: inline proc(program: Shader_Program, name: cstring, count: i32, value: ^i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform1iv(cast(i32)location, count, value);
	log_errors(#procedure, loc);
}



uniform2fv :: inline proc(program: Shader_Program, name: cstring, count: i32, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform2fv(cast(i32)location, count, value);
	log_errors(#procedure, loc);
}
uniform2iv :: inline proc(program: Shader_Program, name: cstring, count: i32, value: ^i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform2iv(cast(i32)location, count, value);
	log_errors(#procedure, loc);
}



uniform3fv :: inline proc(program: Shader_Program, name: cstring, count: i32, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform3fv(cast(i32)location, count, value);
	log_errors(#procedure, loc);
}
uniform3iv :: inline proc(program: Shader_Program, name: cstring, count: i32, value: ^i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform3iv(cast(i32)location, count, value);
	log_errors(#procedure, loc);
}



uniform4fv :: inline proc(program: Shader_Program, name: cstring, count: i32, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform4fv(cast(i32)location, count, value);
	log_errors(#procedure, loc);
}
uniform4iv :: inline proc(program: Shader_Program, name: cstring, count: i32, value: ^i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.Uniform4iv(cast(i32)location, count, value);
	log_errors(#procedure, loc);
}



uniform_matrix2fv :: inline proc(program: Shader_Program, name: cstring, count: i32, transpose: bool, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.UniformMatrix2fv(cast(i32)location, count, cast(u8)transpose, value);
	log_errors(#procedure, loc);
}

uniform_matrix3fv :: inline proc(program: Shader_Program, name: cstring, count: i32, transpose: bool, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.UniformMatrix3fv(cast(i32)location, count, cast(u8)transpose, value);
	log_errors(#procedure, loc);
}

uniform_matrix4fv :: inline proc(program: Shader_Program, name: cstring, count: i32, transpose: bool, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	odingl.UniformMatrix4fv(cast(i32)location, count, cast(u8)transpose, value);
	log_errors(#procedure, loc);
}


log_errors :: proc(caller_context: string, location := #caller_location) -> bool {
	did_error := false;
	for {
		err := odingl.GetError();
		if err == 0 {
			break;
		}

		did_error = true;
		file := location.file_path;
		idx, ok := find_from_right(location.file_path, '\\');
		if ok {
			file = location.file_path[idx+1:len(location.file_path)];
		}

		fmt.printf("[%s] OpenGL Error at %s:%d: %d\n", caller_context, file, location.line, err);
	}
	return did_error;
}

}
