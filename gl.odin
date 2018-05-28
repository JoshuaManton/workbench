/*
 *  @Name:     gl
 *
 *  @Author:   Joshua Manton
 *  @Email:    joshuamarkk@gmail.com
 *  @Creation: 21-12-2017 07:19:30 UTC-8
 *
 *  @Last By:   Joshua Manton
 *  @Last Time: 27-05-2018 13:02:46 UTC-8
 *
 *  @Description:
 *
 */

      import "core:fmt.odin"
      import "core:os.odin"
using import "core:math.odin"

      export "shared:odin-gl/gl.odin"

using import "logging.odin"
      import "basic.odin"
using import "types.odin"

Shader_Program :: distinct u32;
VAO :: distinct u32;
VBO :: distinct u32;
Texture :: distinct u32;

gen_vao :: inline proc() -> VAO {
	vao: u32;
	GenVertexArrays(1, &vao);
	return cast(VAO)vao;
}

bind_vao :: inline proc(vao: VAO) {
	BindVertexArray(cast(u32)vao);
}

delete_vao :: inline proc(vao: VAO) {
	DeleteVertexArrays(1, cast(^u32)&vao);
}

gen_buffer :: inline proc() -> VBO {
	vbo: u32;
	GenBuffers(1, &vbo);
	return cast(VBO)vbo;
}

bind_buffer :: inline proc(vbo: VBO) {
	BindBuffer(ARRAY_BUFFER, cast(u32)vbo);
}

delete_buffer :: inline proc(vbo: VBO) {
	DeleteBuffers(1, cast(^u32)&vbo);
}



load_shader_files :: inline proc(vs, fs: string) -> (Shader_Program, bool) {
	vs_code, ok1 := os.read_entire_file(vs);
	if !ok1 {
		logln("Couldn't open shader file: ", vs);
		return Shader_Program{}, false;
	}
	defer free(vs_code);

	fs_code, ok2 := os.read_entire_file(fs);
	if !ok2 {
		logln("Couldn't open shader file: ", fs);
		return Shader_Program{}, false;
	}
	defer free(fs_code);

	program, ok := load_shader_text(cast(string)vs_code, cast(string)fs_code);
	return cast(Shader_Program)program, ok;
}

load_shader_text :: proc(vs_code, fs_code: string) -> (program: Shader_Program, success: bool) {
    // Shader checking and linking checking are identical
    // except for calling differently named GL functions
    // it's a bit ugly looking, but meh
    check_error :: proc(id: u32, type_: Shader_Type, status: u32,
                        iv_func: proc "c" (u32, u32, ^i32),
                        log_func: proc "c" (u32, i32, ^i32, ^u8)) -> bool {
        result, info_log_length: i32;
        iv_func(id, status, &result);
        iv_func(id, INFO_LOG_LENGTH, &info_log_length);

        if result == 0 {
            error_message := make([]u8, info_log_length);
            defer free(error_message);

            log_func(id, i32(info_log_length), nil, &error_message[0]);
            fmt.printf_err("Error in %v:\n%s", type_, string(error_message[0..len(error_message)-1]));

            return true;
        }

        return false;
    }

    // Compiling shaders are identical for any shader (vertex, geometry, fragment, tesselation, (maybe compute too))
    compile_shader_from_text :: proc(shader_code: string, shader_type: Shader_Type) -> (u32, bool) {
        shader_id := CreateShader(cast(u32)shader_type);
        length := i32(len(shader_code));
        ShaderSource(shader_id, 1, (^^u8)(&shader_code), &length);
        CompileShader(shader_id);

        if check_error(shader_id, shader_type, COMPILE_STATUS, GetShaderiv, GetShaderInfoLog) {
            return 0, false;
        }

        return shader_id, true;
    }

    // only used once, but I'd just make a subprocedure(?) for consistency
    create_and_link_program :: proc(shader_ids: []u32) -> (u32, bool) {
        program_id := CreateProgram();
        for id in shader_ids {
            AttachShader(program_id, id);
        }
        LinkProgram(program_id);

        if check_error(program_id, Shader_Type.SHADER_LINK, LINK_STATUS, GetProgramiv, GetProgramInfoLog) {
            return 0, false;
        }

        return program_id, true;
    }

    // actual function from here
    vertex_shader_id, ok1 := compile_shader_from_text(vs_code, Shader_Type.VERTEX_SHADER);
    defer DeleteShader(vertex_shader_id);

    fragment_shader_id, ok2 := compile_shader_from_text(fs_code, Shader_Type.FRAGMENT_SHADER);
    defer DeleteShader(fragment_shader_id);

    if !ok1 || !ok2 {
        return 0, false;
    }

    program_id, ok := create_and_link_program([]u32{vertex_shader_id, fragment_shader_id});
    if !ok {
        return 0, false;
    }

    return cast(Shader_Program)program_id, true;
}

use_program :: inline proc(program: Shader_Program) {
	UseProgram(cast(u32)program);
}



gen_texture :: inline proc() -> Texture {
	texture: u32;
	GenTextures(1, &texture);
	return cast(Texture)texture;
}

bind_texture1d :: inline proc(texture: Texture) {
	BindTexture(TEXTURE_1D, cast(u32)texture);
}

bind_texture2d :: inline proc(texture: Texture) {
	BindTexture(TEXTURE_2D, cast(u32)texture);
}

delete_texture :: inline proc(texture: Texture) {
	DeleteTextures(1, cast(^u32)&texture);
}

// ActiveTexture() is guaranteed to go from 0-47 on all implementations of OpenGL, but can go higher on some
active_texture0 :: inline proc() {
	ActiveTexture(TEXTURE0);
}

active_texture1 :: inline proc() {
	ActiveTexture(TEXTURE1);
}

active_texture2 :: inline proc() {
	ActiveTexture(TEXTURE2);
}

active_texture3 :: inline proc() {
	ActiveTexture(TEXTURE3);
}

active_texture4 :: inline proc() {
	ActiveTexture(TEXTURE4);
}

c_string_buffer: [4096]byte;
c_string :: proc(fmt_: string, args: ...any) -> ^byte {
    s := fmt.bprintf(c_string_buffer[..], fmt_, ...args);
    c_string_buffer[len(s)] = 0;
    return cast(^byte)&c_string_buffer[0];
}



get_uniform_location :: inline proc(program: Shader_Program, str: string, loc := #caller_location) -> i32 {
	uniform_loc := GetUniformLocation(cast(u32)program, &str[0]);
	log_gl_errors(#procedure, loc);
	return uniform_loc;
}

set_vertex_format :: proc(vertex_type: type) {
	ti := type_info_base(type_info_of(vertex_type)).variant.(Type_Info_Struct);

	for name, _i in ti.names {
		i := cast(u32)_i;
		offset := ti.offsets[i];
		offset_in_struct := rawptr(uintptr(offset));
		num_elements: i32;
		type_of_elements: u32;

		a: any;
		a.typeid = typeid_of(ti.types[i]);
		switch kind in a {
			case Vec2: {
				num_elements = 2;
				type_of_elements = FLOAT;
			}
			case Vec3: {
				num_elements = 3;
				type_of_elements = FLOAT;
			}
			case Vec4, Colorf: {
				num_elements = 4;
				type_of_elements = FLOAT;
			}
			case Colori: {
				num_elements = 4;
				type_of_elements = UNSIGNED_BYTE;
			}
			case f64: {
				num_elements = 1;
				type_of_elements = DOUBLE;
			}
			case f32: {
				num_elements = 1;
				type_of_elements = FLOAT;
			}
			case i32: {
				num_elements = 1;
				type_of_elements = INT;
			}
			case u32: {
				num_elements = 1;
				type_of_elements = UNSIGNED_INT;
			}
			case i16: {
				num_elements = 1;
				type_of_elements = SHORT;
			}
			case u16: {
				num_elements = 1;
				type_of_elements = UNSIGNED_SHORT;
			}
			case i8: {
				num_elements = 1;
				type_of_elements = BYTE;
			}
			case u8: {
				num_elements = 1;
				type_of_elements = UNSIGNED_BYTE;
			}
			case: {
				fmt.printf("UNSUPPORTED TYPE IN VERTEX FORMAT - %s: %s\n", name, kind);
			}
		}

		VertexAttribPointer(i, num_elements, type_of_elements, FALSE, size_of(vertex_type), offset_in_struct);
		EnableVertexAttribArray(i);
	}
}



get_int :: inline proc(pname: u32, loc := #caller_location) -> i32 {
	i: i32;
	GetIntegerv(pname, &i); log_gl_errors(#procedure, loc);
	return i;
}

get_current_shader :: inline proc() -> Shader_Program {
	id := get_int(CURRENT_PROGRAM);
	return cast(Shader_Program)id;
}



uniform :: proc[uniform1f,
				uniform2f,
				uniform3f,
				uniform4f,
				uniform1i,
				uniform2i,
				uniform3i,
				uniform4i,
				];
uniform1f :: inline proc(program: Shader_Program, name: string, v0: f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform1f(location, v0); log_gl_errors(#procedure, loc);
}
uniform2f :: inline proc(program: Shader_Program, name: string, v0: f32, v1: f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform2f(location, v0, v1); log_gl_errors(#procedure, loc);
}
uniform3f :: inline proc(program: Shader_Program, name: string, v0: f32, v1: f32, v2: f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform3f(location, v0, v1, v2); log_gl_errors(#procedure, loc);
}
uniform4f :: inline proc(program: Shader_Program, name: string, v0: f32, v1: f32, v2: f32, v3: f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform4f(location, v0, v1, v2, v3); log_gl_errors(#procedure, loc);
}
uniform1i :: inline proc(program: Shader_Program, name: string, v0: i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform1i(location, v0); log_gl_errors(#procedure, loc);
}
uniform2i :: inline proc(program: Shader_Program, name: string, v0: i32, v1: i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform2i(location, v0, v1); log_gl_errors(#procedure, loc);
}
uniform3i :: inline proc(program: Shader_Program, name: string, v0: i32, v1: i32, v2: i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform3i(location, v0, v1, v2); log_gl_errors(#procedure, loc);
}
uniform4i :: inline proc(program: Shader_Program, name: string, v0: i32, v1: i32, v2: i32, v3: i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform4i(location, v0, v1, v2, v3); log_gl_errors(#procedure, loc);
}



uniform1 :: proc[uniform1fv,
				 uniform1iv,
				 ];
uniform1fv :: inline proc(program: Shader_Program, name: string, count: i32, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform1fv(location, count, value); log_gl_errors(#procedure, loc);
}
uniform1iv :: inline proc(program: Shader_Program, name: string, count: i32, value: ^i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform1iv(location, count, value); log_gl_errors(#procedure, loc);
}



uniform2 :: proc[uniform2fv,
				 uniform2iv,
				 ];
uniform2fv :: inline proc(program: Shader_Program, name: string, count: i32, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform2fv(location, count, value); log_gl_errors(#procedure, loc);
}
uniform2iv :: inline proc(program: Shader_Program, name: string, count: i32, value: ^i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform2iv(location, count, value); log_gl_errors(#procedure, loc);
}



uniform3 :: proc[uniform3fv,
				 uniform3iv,
				 ];
uniform3fv :: inline proc(program: Shader_Program, name: string, count: i32, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform3fv(location, count, value); log_gl_errors(#procedure, loc);
}
uniform3iv :: inline proc(program: Shader_Program, name: string, count: i32, value: ^i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform3iv(location, count, value); log_gl_errors(#procedure, loc);
}



uniform4 :: proc[uniform4fv,
				 uniform4iv,
				 ];
uniform4fv :: inline proc(program: Shader_Program, name: string, count: i32, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform4fv(location, count, value); log_gl_errors(#procedure, loc);
}
uniform4iv :: inline proc(program: Shader_Program, name: string, count: i32, value: ^i32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	Uniform4iv(location, count, value); log_gl_errors(#procedure, loc);
}



uniform_matrix2fv :: inline proc(program: Shader_Program, name: string, count: i32, transpose: bool, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	UniformMatrix2fv(location, count, transpose ? 1 : 0, value); log_gl_errors(#procedure, loc);
}

uniform_matrix3fv :: inline proc(program: Shader_Program, name: string, count: i32, transpose: bool, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	UniformMatrix3fv(location, count, transpose ? 1 : 0, value); log_gl_errors(#procedure, loc);
}

uniform_matrix4fv :: inline proc(program: Shader_Program, name: string, count: i32, transpose: bool, value: ^f32, loc := #caller_location) {
	location := get_uniform_location(program, name, loc);
	UniformMatrix4fv(location, count, transpose ? 1 : 0, value); log_gl_errors(#procedure, loc);
}



log_gl_errors :: proc(caller_context: string, location := #caller_location) {
	for {
		err := GetError();
		if err == 0 {
			break;
		}

		file := location.file_path;
		idx, ok := basic.find_from_right(location.file_path, '\\');
		if ok {
			file = location.file_path[idx+1..len(location.file_path)];
		}

		fmt.printf("[%s] OpenGL Error at %s:%d: %d\n", caller_context, file, location.line, err);
	}
}