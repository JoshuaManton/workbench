package gl

import "core:os";
import "core:fmt";
import "core:strings"
import "../../basic"

loaded_up_to_major := 0;
loaded_up_to_minor := 0;

Set_Proc_Address_Type :: #type proc(p: rawptr, name: cstring);

load_up_to :: proc(major, minor : int, set_proc_address: Set_Proc_Address_Type) {
    loaded_up_to_major = major;
    loaded_up_to_minor = minor;

    switch major*10+minor {
    case 46: load_4_6(set_proc_address); fallthrough;
    case 45: load_4_5(set_proc_address); fallthrough;
    case 44: load_4_4(set_proc_address); fallthrough;
    case 43: load_4_3(set_proc_address); fallthrough;
    case 42: load_4_2(set_proc_address); fallthrough;
    case 41: load_4_1(set_proc_address); fallthrough;
    case 40: load_4_0(set_proc_address); fallthrough;
    case 33: load_3_3(set_proc_address); fallthrough;
    case 32: load_3_2(set_proc_address); fallthrough;
    case 31: load_3_1(set_proc_address); fallthrough;
    case 30: load_3_0(set_proc_address); fallthrough;
    case 21: load_2_1(set_proc_address); fallthrough;
    case 20: load_2_0(set_proc_address); fallthrough;
    case 15: load_1_5(set_proc_address); fallthrough;
    case 14: load_1_4(set_proc_address); fallthrough;
    case 13: load_1_3(set_proc_address); fallthrough;
    case 12: load_1_2(set_proc_address); fallthrough;
    case 11: load_1_1(set_proc_address); fallthrough;
    case 10: load_1_0(set_proc_address);
    }
}

/*
Type conversion overview:
    typedef unsigned int GLenum;     -> u32
    typedef unsigned char GLboolean; -> u8
    typedef unsigned int GLbitfield; -> u32
    typedef signed char GLbyte;      -> i8
    typedef short GLshort;           -> i16
    typedef int GLint;               -> i32
    typedef unsigned char GLubyte;   -> u8
    typedef unsigned short GLushort; -> u16
    typedef unsigned int GLuint;     -> u32
    typedef int GLsizei;             -> i32
    typedef float GLfloat;           -> f32
    typedef double GLdouble;         -> f64
    typedef char GLchar;             -> u8
    typedef ptrdiff_t GLintptr;      -> int
    typedef ptrdiff_t GLsizeiptr;    -> int
    typedef int64_t GLint64;         -> i64
    typedef uint64_t GLuint64;       -> u64

    void*                            -> rawptr
*/

sync_t :: rawptr;
debug_proc_t :: #type proc "c" (source: u32, type_: u32, id: u32, severity: u32, length: i32, message: ^u8, userParam: rawptr);


// VERSION_1_0
CullFace:               proc "c" (mode: u32);
FrontFace:              proc "c" (mode: u32);
Hint:                   proc "c" (target: u32, mode: u32);
LineWidth:              proc "c" (width: f32);
PointSize:              proc "c" (size: f32);
PolygonMode:            proc "c" (face: u32, mode: u32);
Scissor:                proc "c" (auto_cast x: i32, auto_cast y: i32, auto_cast width: i32, auto_cast height: i32);
TexParameterf:          proc "c" (target: u32, pname: u32, param: f32);
TexParameterfv:         proc "c" (target: u32, pname: u32, params: ^f32);
TexParameteri:          proc "c" (target: u32, pname: u32, param: i32);
TexParameteriv:         proc "c" (target: u32, pname: u32, params: ^i32);
TexImage1D:             proc "c" (target: u32, level: i32, internalformat: i32, width: i32, border: i32, format: u32, type_: u32, pixels: rawptr);
TexImage2D:             proc "c" (target: u32, level: i32, internalformat: i32, width: i32, height: i32, border: i32, format: u32, type_: u32, pixels: rawptr);
DrawBuffer:             proc "c" (buf: u32);
Clear:                  proc "c" (mask: u32);
ClearColor:             proc "c" (red: f32, green: f32, blue: f32, alpha: f32);
ClearStencil:           proc "c" (s: i32);
ClearDepth:             proc "c" (depth: f64);
StencilMask:            proc "c" (mask: u32);
ColorMask:              proc "c" (red: u8, green: u8, blue: u8, alpha: u8);
DepthMask:              proc "c" (flag: u8);
Disable:                proc "c" (cap: u32);
Enable:                 proc "c" (cap: u32);
Finish:                 proc "c" ();
Flush:                  proc "c" ();
BlendFunc:              proc "c" (sfactor: u32, dfactor: u32);
LogicOp:                proc "c" (opcode: u32);
StencilFunc:            proc "c" (func: u32, ref: i32, mask: u32);
StencilOp:              proc "c" (fail: u32, zfail: u32, zpass: u32);
DepthFunc:              proc "c" (func: u32);
PixelStoref:            proc "c" (pname: u32, param: f32);
PixelStorei:            proc "c" (pname: u32, param: i32);
ReadBuffer:             proc "c" (src: u32);
ReadPixels:             proc "c" (x: i32, y: i32, width: i32, height: i32, format: u32, type_: u32, pixels: rawptr);
GetBooleanv:            proc "c" (pname: u32, data: ^u8);
GetDoublev:             proc "c" (pname: u32, data: ^f64);
GetError:               proc "c" () -> u32;
GetFloatv:              proc "c" (pname: u32, data: ^f32);
GetIntegerv:            proc "c" (pname: u32, data: ^i32);
GetString:              proc "c" (name: u32) -> ^u8;
GetTexImage:            proc "c" (target: u32,  level: i32, format: u32, type_: u32, pixels: rawptr);
GetTexParameterfv:      proc "c" (target: u32, pname: u32, params: ^f32);
GetTexParameteriv:      proc "c" (target: u32, pname: u32, params: ^i32);
GetTexLevelParameterfv: proc "c" (target: u32, level: i32, pname: u32, params: ^f32);
GetTexLevelParameteriv: proc "c" (target: u32, level: i32, pname: u32, params: ^i32);
IsEnabled:              proc "c" (cap: u32) -> u8;
DepthRange:             proc "c" (near: f64, far: f64);
Viewport:               proc "c" (x: i32, y: i32, width: i32, height: i32);

load_1_0 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&CullFace,               "glCullFace");
    set_proc_address(&FrontFace,              "glFrontFace");
    set_proc_address(&Hint,                   "glHint");
    set_proc_address(&LineWidth,              "glLineWidth");
    set_proc_address(&PointSize,              "glPointSize");
    set_proc_address(&PolygonMode,            "glPolygonMode");
    set_proc_address(&Scissor,                "glScissor");
    set_proc_address(&TexParameterf,          "glTexParameterf");
    set_proc_address(&TexParameterfv,         "glTexParameterfv");
    set_proc_address(&TexParameteri,          "glTexParameteri");
    set_proc_address(&TexParameteriv,         "glTexParameteriv");
    set_proc_address(&TexImage1D,             "glTexImage1D");
    set_proc_address(&TexImage2D,             "glTexImage2D");
    set_proc_address(&DrawBuffer,             "glDrawBuffer");
    set_proc_address(&Clear,                  "glClear");
    set_proc_address(&ClearColor,             "glClearColor");
    set_proc_address(&ClearStencil,           "glClearStencil");
    set_proc_address(&ClearDepth,             "glClearDepth");
    set_proc_address(&StencilMask,            "glStencilMask");
    set_proc_address(&ColorMask,              "glColorMask");
    set_proc_address(&DepthMask,              "glDepthMask");
    set_proc_address(&Disable,                "glDisable");
    set_proc_address(&Enable,                 "glEnable");
    set_proc_address(&Finish,                 "glFinish");
    set_proc_address(&Flush,                  "glFlush");
    set_proc_address(&BlendFunc,              "glBlendFunc");
    set_proc_address(&LogicOp,                "glLogicOp");
    set_proc_address(&StencilFunc,            "glStencilFunc");
    set_proc_address(&StencilOp,              "glStencilOp");
    set_proc_address(&DepthFunc,              "glDepthFunc");
    set_proc_address(&PixelStoref,            "glPixelStoref");
    set_proc_address(&PixelStorei,            "glPixelStorei");
    set_proc_address(&ReadBuffer,             "glReadBuffer");
    set_proc_address(&ReadPixels,             "glReadPixels");
    set_proc_address(&GetBooleanv,            "glGetBooleanv");
    set_proc_address(&GetDoublev,             "glGetDoublev");
    set_proc_address(&GetError,               "glGetError");
    set_proc_address(&GetFloatv,              "glGetFloatv");
    set_proc_address(&GetIntegerv,            "glGetIntegerv");
    set_proc_address(&GetString,              "glGetString");
    set_proc_address(&GetTexImage,            "glGetTexImage");
    set_proc_address(&GetTexParameterfv,      "glGetTexParameterfv");
    set_proc_address(&GetTexParameteriv,      "glGetTexParameteriv");
    set_proc_address(&GetTexLevelParameterfv, "glGetTexLevelParameterfv");
    set_proc_address(&GetTexLevelParameteriv, "glGetTexLevelParameteriv");
    set_proc_address(&IsEnabled,              "glIsEnabled");
    set_proc_address(&DepthRange,             "glDepthRange");
    set_proc_address(&Viewport,               "glViewport");
}


// VERSION_1_1
DrawArrays:        proc "c" (mode: u32, first: i32, count: i32);
DrawElements:      proc "c" (mode: u32, count: i32, type_: u32, indices: rawptr);
PolygonOffset:     proc "c" (factor: f32, units: f32);
CopyTexImage1D:    proc "c" (target: u32, level: i32, internalformat: u32, x: i32, y: i32, width: i32, border: i32);
CopyTexImage2D:    proc "c" (target: u32, level: i32, internalformat: u32, x: i32, y: i32, width: i32, height: i32, border: i32);
CopyTexSubImage1D: proc "c" (target: u32, level: i32, xoffset: i32, x: i32, y: i32, width: i32);
CopyTexSubImage2D: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, x: i32, y: i32, width: i32, height: i32);
TexSubImage1D:     proc "c" (target: u32, level: i32, xoffset: i32, width: i32, format: u32, type_: u32, pixels: rawptr);
TexSubImage2D:     proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, type_: u32, pixels: rawptr);
BindTexture:       proc "c" (target: u32, texture: u32);
DeleteTextures:    proc "c" (n: i32, textures: ^u32);
GenTextures:       proc "c" (n: i32, textures: ^u32);
IsTexture:         proc "c" (texture: u32) -> u8;

load_1_1 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&DrawArrays,        "glDrawArrays");
    set_proc_address(&DrawElements,      "glDrawElements");
    set_proc_address(&PolygonOffset,     "glPolygonOffset");
    set_proc_address(&CopyTexImage1D,    "glCopyTexImage1D");
    set_proc_address(&CopyTexImage2D,    "glCopyTexImage2D");
    set_proc_address(&CopyTexSubImage1D, "glCopyTexSubImage1D");
    set_proc_address(&CopyTexSubImage2D, "glCopyTexSubImage2D");
    set_proc_address(&TexSubImage1D,     "glTexSubImage1D");
    set_proc_address(&TexSubImage2D,     "glTexSubImage2D");
    set_proc_address(&BindTexture,       "glBindTexture");
    set_proc_address(&DeleteTextures,    "glDeleteTextures");
    set_proc_address(&GenTextures,       "glGenTextures");
    set_proc_address(&IsTexture,         "glIsTexture");
}


// VERSION_1_2
DrawRangeElements: proc "c" (mode: u32, start: u32, end: u32, count: i32, type_: u32, indices: rawptr);
TexImage3D:        proc "c" (target: u32, level: i32, internalformat: i32, width: i32, height: i32, depth: i32, border: i32, format: u32, type_: u32, pixels: rawptr);
TexSubImage3D:     proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32, format: u32, type_: u32, pixels: rawptr);
CopyTexSubImage3D: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, x: i32, y: i32, width: i32, height: i32);

load_1_2 :: proc(set_proc_address: Set_Proc_Address_Type) {

    set_proc_address(&DrawRangeElements, "glDrawRangeElements");
    set_proc_address(&TexImage3D,        "glTexImage3D");
    set_proc_address(&TexSubImage3D,     "glTexSubImage3D");
    set_proc_address(&CopyTexSubImage3D, "glCopyTexSubImage3D");
}


// VERSION_1_3
ActiveTexture:           proc "c" (texture: u32);
SampleCoverage:          proc "c" (value: f32, invert: u8);
CompressedTexImage3D:    proc "c" (target: u32, level: i32, internalformat: u32, width: i32, height: i32, depth: i32, border: i32, imageSize: i32, data: rawptr);
CompressedTexImage2D:    proc "c" (target: u32, level: i32, internalformat: u32, width: i32, height: i32, border: i32, imageSize: i32, data: rawptr);
CompressedTexImage1D:    proc "c" (target: u32, level: i32, internalformat: u32, width: i32, border: i32, imageSize: i32, data: rawptr);
CompressedTexSubImage3D: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32, format: u32, imageSize: i32, data: rawptr);
CompressedTexSubImage2D: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, imageSize: i32, data: rawptr);
CompressedTexSubImage1D: proc "c" (target: u32, level: i32, xoffset: i32, width: i32, format: u32, imageSize: i32, data: rawptr);
GetCompressedTexImage:   proc "c" (target: u32, level: i32, img: rawptr);

load_1_3 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&ActiveTexture,           "glActiveTexture");
    set_proc_address(&SampleCoverage,          "glSampleCoverage");
    set_proc_address(&CompressedTexImage3D,    "glCompressedTexImage3D");
    set_proc_address(&CompressedTexImage2D,    "glCompressedTexImage2D");
    set_proc_address(&CompressedTexImage1D,    "glCompressedTexImage1D");
    set_proc_address(&CompressedTexSubImage3D, "glCompressedTexSubImage3D");
    set_proc_address(&CompressedTexSubImage2D, "glCompressedTexSubImage2D");
    set_proc_address(&CompressedTexSubImage1D, "glCompressedTexSubImage1D");
    set_proc_address(&GetCompressedTexImage,   "glGetCompressedTexImage");
}


// VERSION_1_4
BlendFuncSeparate: proc "c" (sfactorRGB: u32, dfactorRGB: u32, sfactorAlpha: u32, dfactorAlpha: u32);
MultiDrawArrays:   proc "c" (mode: u32, first: ^i32, count: ^i32, drawcount: i32);
MultiDrawElements: proc "c" (mode: u32, count: ^i32, type_: u32, indices: ^rawptr, drawcount: i32);
PointParameterf:   proc "c" (pname: u32, param: f32);
PointParameterfv:  proc "c" (pname: u32, params: ^f32);
PointParameteri:   proc "c" (pname: u32, param: i32);
PointParameteriv:  proc "c" (pname: u32, params: ^i32);
BlendColor:        proc "c" (red: f32, green: f32, blue: f32, alpha: f32);
BlendEquation:     proc "c" (mode: u32);


load_1_4 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&BlendFuncSeparate, "glBlendFuncSeparate");
    set_proc_address(&MultiDrawArrays,   "glMultiDrawArrays");
    set_proc_address(&MultiDrawElements, "glMultiDrawElements");
    set_proc_address(&PointParameterf,   "glPointParameterf");
    set_proc_address(&PointParameterfv,  "glPointParameterfv");
    set_proc_address(&PointParameteri,   "glPointParameteri");
    set_proc_address(&PointParameteriv,  "glPointParameteriv");
    set_proc_address(&BlendColor,        "glBlendColor");
    set_proc_address(&BlendEquation,     "glBlendEquation");
}


// VERSION_1_5
GenQueries:           proc "c" (n: i32, ids: ^u32);
DeleteQueries:        proc "c" (n: i32, ids: ^u32);
IsQuery:              proc "c" (id: u32) -> u8;
BeginQuery:           proc "c" (target: u32, id: u32);
EndQuery:             proc "c" (target: u32);
GetQueryiv:           proc "c" (target: u32, pname: u32, params: ^i32);
GetQueryObjectiv:     proc "c" (id: u32, pname: u32, params: ^i32);
GetQueryObjectuiv:    proc "c" (id: u32, pname: u32, params: ^u32);
BindBuffer:           proc "c" (target: u32, buffer: u32);
DeleteBuffers:        proc "c" (n: i32, buffers: ^u32);
GenBuffers:           proc "c" (n: i32, buffers: ^u32);
IsBuffer:             proc "c" (buffer: u32) -> u8;
BufferData:           proc "c" (target: u32, size: int, data: rawptr, usage: u32);
BufferSubData:        proc "c" (target: u32, offset: int, size: int, data: rawptr);
GetBufferSubData:     proc "c" (target: u32, offset: int, size: int, data: rawptr);
MapBuffer:            proc "c" (target: u32, access: u32) -> rawptr;
UnmapBuffer:          proc "c" (target: u32) -> u8;
GetBufferParameteriv: proc "c" (target: u32, pname: u32, params: ^i32);
GetBufferPointerv:    proc "c" (target: u32, pname: u32, params: ^rawptr);

load_1_5 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&GenQueries,           "glGenQueries");
    set_proc_address(&DeleteQueries,        "glDeleteQueries");
    set_proc_address(&IsQuery,              "glIsQuery");
    set_proc_address(&BeginQuery,           "glBeginQuery");
    set_proc_address(&EndQuery,             "glEndQuery");
    set_proc_address(&GetQueryiv,           "glGetQueryiv");
    set_proc_address(&GetQueryObjectiv,     "glGetQueryObjectiv");
    set_proc_address(&GetQueryObjectuiv,    "glGetQueryObjectuiv");
    set_proc_address(&BindBuffer,           "glBindBuffer");
    set_proc_address(&DeleteBuffers,        "glDeleteBuffers");
    set_proc_address(&GenBuffers,           "glGenBuffers");
    set_proc_address(&IsBuffer,             "glIsBuffer");
    set_proc_address(&BufferData,           "glBufferData");
    set_proc_address(&BufferSubData,        "glBufferSubData");
    set_proc_address(&GetBufferSubData,     "glGetBufferSubData");
    set_proc_address(&MapBuffer,            "glMapBuffer");
    set_proc_address(&UnmapBuffer,          "glUnmapBuffer");
    set_proc_address(&GetBufferParameteriv, "glGetBufferParameteriv");
    set_proc_address(&GetBufferPointerv,    "glGetBufferPointerv");
}


// VERSION_2_0
BlendEquationSeparate:    proc "c" (modeRGB: u32, modeAlpha: u32);
DrawBuffers:              proc "c" (n: i32, bufs: ^u32);
StencilOpSeparate:        proc "c" (face: u32, sfail: u32, dpfail: u32, dppass: u32);
StencilFuncSeparate:      proc "c" (face: u32, func: u32, ref: i32, mask: u32);
StencilMaskSeparate:      proc "c" (face: u32, mask: u32);
AttachShader:             proc "c" (program: u32, shader: u32);
BindAttribLocation:       proc "c" (program: u32, index: u32, name: ^u8);
CompileShader:            proc "c" (shader: u32);
CreateProgram:            proc "c" () -> u32;
CreateShader:             proc "c" (type_: u32) -> u32;
DeleteProgram:            proc "c" (program: u32);
DeleteShader:             proc "c" (shader: u32);
DetachShader:             proc "c" (program: u32, shader: u32);
DisableVertexAttribArray: proc "c" (index: u32);
EnableVertexAttribArray:  proc "c" (index: u32);
GetActiveAttrib:          proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type_: ^u32, name: ^u8);
GetActiveUniform:         proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type_: ^u32, name: ^u8);
GetAttachedShaders:       proc "c" (program: u32, maxCount: i32, count: ^i32, shaders: ^u32);
GetAttribLocation:        proc "c" (program: u32, name: ^u8) -> i32;
GetProgramiv:             proc "c" (program: u32, pname: u32, params: ^i32);
GetProgramInfoLog:        proc "c" (program: u32, bufSize: i32, length: ^i32, infoLog: ^u8);
GetShaderiv:              proc "c" (shader: u32, pname: u32, params: ^i32);
GetShaderInfoLog:         proc "c" (shader: u32, bufSize: i32, length: ^i32, infoLog: ^u8);
GetShaderSource:          proc "c" (shader: u32, bufSize: i32, length: ^i32, source: ^u8);
GetUniformLocation:       proc "c" (program: u32, name: ^u8) -> i32;
GetUniformfv:             proc "c" (program: u32, location: i32, params: ^f32);
GetUniformiv:             proc "c" (program: u32, location: i32, params: ^i32);
GetVertexAttribdv:        proc "c" (index: u32, pname: u32, params: ^f64);
GetVertexAttribfv:        proc "c" (index: u32, pname: u32, params: ^f32);
GetVertexAttribiv:        proc "c" (index: u32, pname: u32, params: ^i32);
GetVertexAttribPointerv:  proc "c" (index: u32, pname: u32, pointer: ^rawptr);
IsProgram:                proc "c" (program: u32) -> u8;
IsShader:                 proc "c" (shader: u32) -> u8;
LinkProgram:              proc "c" (program: u32);
ShaderSource:             proc "c" (shader: u32, count: i32, string: ^^u8, length: ^i32);
UseProgram:               proc "c" (program: u32);
Uniform1f:                proc "c" (location: i32, v0: f32);
Uniform2f:                proc "c" (location: i32, v0: f32, v1: f32);
Uniform3f:                proc "c" (location: i32, v0: f32, v1: f32, v2: f32);
Uniform4f:                proc "c" (location: i32, v0: f32, v1: f32, v2: f32, v3: f32);
Uniform1i:                proc "c" (location: i32, v0: i32);
Uniform2i:                proc "c" (location: i32, v0: i32, v1: i32);
Uniform3i:                proc "c" (location: i32, v0: i32, v1: i32, v2: i32);
Uniform4i:                proc "c" (location: i32, v0: i32, v1: i32, v2: i32, v3: i32);
Uniform1fv:               proc "c" (location: i32, count: i32, value: ^f32);
Uniform2fv:               proc "c" (location: i32, count: i32, value: ^f32);
Uniform3fv:               proc "c" (location: i32, count: i32, value: ^f32);
Uniform4fv:               proc "c" (location: i32, count: i32, value: ^f32);
Uniform1iv:               proc "c" (location: i32, count: i32, value: ^i32);
Uniform2iv:               proc "c" (location: i32, count: i32, value: ^i32);
Uniform3iv:               proc "c" (location: i32, count: i32, value: ^i32);
Uniform4iv:               proc "c" (location: i32, count: i32, value: ^i32);
UniformMatrix2fv:         proc "c" (location: i32, count: i32, transpose: u8, value: ^f32);
UniformMatrix3fv:         proc "c" (location: i32, count: i32, transpose: u8, value: ^f32);
UniformMatrix4fv:         proc "c" (location: i32, count: i32, transpose: u8, value: ^f32);
ValidateProgram:          proc "c" (program: u32);
VertexAttrib1d:           proc "c" (index: u32, x: f64);
VertexAttrib1dv:          proc "c" (index: u32, v: ^f64);
VertexAttrib1f:           proc "c" (index: u32, x: f32);
VertexAttrib1fv:          proc "c" (index: u32, v: ^f32);
VertexAttrib1s:           proc "c" (index: u32, x: i16);
VertexAttrib1sv:          proc "c" (index: u32, v: ^i16);
VertexAttrib2d:           proc "c" (index: u32, x: f64, y: f64);
VertexAttrib2dv:          proc "c" (index: u32, v: ^f64);
VertexAttrib2f:           proc "c" (index: u32, x: f32, y: f32);
VertexAttrib2fv:          proc "c" (index: u32, v: ^f32);
VertexAttrib2s:           proc "c" (index: u32, x: i16, y: i16);
VertexAttrib2sv:          proc "c" (index: u32, v: ^i16);
VertexAttrib3d:           proc "c" (index: u32, x: f64, y: f64, z: f64);
VertexAttrib3dv:          proc "c" (index: u32, v: ^f64);
VertexAttrib3f:           proc "c" (index: u32, x: f32, y: f32, z: f32);
VertexAttrib3fv:          proc "c" (index: u32, v: ^f32);
VertexAttrib3s:           proc "c" (index: u32, x: i16, y: i16, z: i16);
VertexAttrib3sv:          proc "c" (index: u32, v: ^i16);
VertexAttrib4Nbv:         proc "c" (index: u32, v: ^i8);
VertexAttrib4Niv:         proc "c" (index: u32, v: ^i32);
VertexAttrib4Nsv:         proc "c" (index: u32, v: ^i16);
VertexAttrib4Nub:         proc "c" (index: u32, x: u8, y: u8, z: u8, w: u8);
VertexAttrib4Nubv:        proc "c" (index: u32, v: ^u8);
VertexAttrib4Nuiv:        proc "c" (index: u32, v: ^u32);
VertexAttrib4Nusv:        proc "c" (index: u32, v: ^u16);
VertexAttrib4bv:          proc "c" (index: u32, v: ^i8);
VertexAttrib4d:           proc "c" (index: u32, x: f64, y: f64, z: f64, w: f64);
VertexAttrib4dv:          proc "c" (index: u32, v: ^f64);
VertexAttrib4f:           proc "c" (index: u32, x: f32, y: f32, z: f32, w: f32);
VertexAttrib4fv:          proc "c" (index: u32, v: ^f32);
VertexAttrib4iv:          proc "c" (index: u32, v: ^i32);
VertexAttrib4s:           proc "c" (index: u32, x: i16, y: i16, z: i16, w: i16);
VertexAttrib4sv:          proc "c" (index: u32, v: ^i16);
VertexAttrib4ubv:         proc "c" (index: u32, v: ^u8);
VertexAttrib4uiv:         proc "c" (index: u32, v: ^u32);
VertexAttrib4usv:         proc "c" (index: u32, v: ^u16);
VertexAttribPointer:      proc "c" (index: u32, size: i32, type_: u32, normalized: u8, stride: i32, pointer: rawptr);

load_2_0 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&BlendEquationSeparate,    "glBlendEquationSeparate");
    set_proc_address(&DrawBuffers,              "glDrawBuffers");
    set_proc_address(&StencilOpSeparate,        "glStencilOpSeparate");
    set_proc_address(&StencilFuncSeparate,      "glStencilFuncSeparate");
    set_proc_address(&StencilMaskSeparate,      "glStencilMaskSeparate");
    set_proc_address(&AttachShader,             "glAttachShader");
    set_proc_address(&BindAttribLocation,       "glBindAttribLocation");
    set_proc_address(&CompileShader,            "glCompileShader");
    set_proc_address(&CreateProgram,            "glCreateProgram");
    set_proc_address(&CreateShader,             "glCreateShader");
    set_proc_address(&DeleteProgram,            "glDeleteProgram");
    set_proc_address(&DeleteShader,             "glDeleteShader");
    set_proc_address(&DetachShader,             "glDetachShader");
    set_proc_address(&DisableVertexAttribArray, "glDisableVertexAttribArray");
    set_proc_address(&EnableVertexAttribArray,  "glEnableVertexAttribArray");
    set_proc_address(&GetActiveAttrib,          "glGetActiveAttrib");
    set_proc_address(&GetActiveUniform,         "glGetActiveUniform");
    set_proc_address(&GetAttachedShaders,       "glGetAttachedShaders");
    set_proc_address(&GetAttribLocation,        "glGetAttribLocation");
    set_proc_address(&GetProgramiv,             "glGetProgramiv");
    set_proc_address(&GetProgramInfoLog,        "glGetProgramInfoLog");
    set_proc_address(&GetShaderiv,              "glGetShaderiv");
    set_proc_address(&GetShaderInfoLog,         "glGetShaderInfoLog");
    set_proc_address(&GetShaderSource,          "glGetShaderSource");
    set_proc_address(&GetUniformLocation,       "glGetUniformLocation");
    set_proc_address(&GetUniformfv,             "glGetUniformfv");
    set_proc_address(&GetUniformiv,             "glGetUniformiv");
    set_proc_address(&GetVertexAttribdv,        "glGetVertexAttribdv");
    set_proc_address(&GetVertexAttribfv,        "glGetVertexAttribfv");
    set_proc_address(&GetVertexAttribiv,        "glGetVertexAttribiv");
    set_proc_address(&GetVertexAttribPointerv,  "glGetVertexAttribPointerv");
    set_proc_address(&IsProgram,                "glIsProgram");
    set_proc_address(&IsShader,                 "glIsShader");
    set_proc_address(&LinkProgram,              "glLinkProgram");
    set_proc_address(&ShaderSource,             "glShaderSource");
    set_proc_address(&UseProgram,               "glUseProgram");
    set_proc_address(&Uniform1f,                "glUniform1f");
    set_proc_address(&Uniform2f,                "glUniform2f");
    set_proc_address(&Uniform3f,                "glUniform3f");
    set_proc_address(&Uniform4f,                "glUniform4f");
    set_proc_address(&Uniform1i,                "glUniform1i");
    set_proc_address(&Uniform2i,                "glUniform2i");
    set_proc_address(&Uniform3i,                "glUniform3i");
    set_proc_address(&Uniform4i,                "glUniform4i");
    set_proc_address(&Uniform1fv,               "glUniform1fv");
    set_proc_address(&Uniform2fv,               "glUniform2fv");
    set_proc_address(&Uniform3fv,               "glUniform3fv");
    set_proc_address(&Uniform4fv,               "glUniform4fv");
    set_proc_address(&Uniform1iv,               "glUniform1iv");
    set_proc_address(&Uniform2iv,               "glUniform2iv");
    set_proc_address(&Uniform3iv,               "glUniform3iv");
    set_proc_address(&Uniform4iv,               "glUniform4iv");
    set_proc_address(&UniformMatrix2fv,         "glUniformMatrix2fv");
    set_proc_address(&UniformMatrix3fv,         "glUniformMatrix3fv");
    set_proc_address(&UniformMatrix4fv,         "glUniformMatrix4fv");
    set_proc_address(&ValidateProgram,          "glValidateProgram");
    set_proc_address(&VertexAttrib1d,           "glVertexAttrib1d");
    set_proc_address(&VertexAttrib1dv,          "glVertexAttrib1dv");
    set_proc_address(&VertexAttrib1f,           "glVertexAttrib1f");
    set_proc_address(&VertexAttrib1fv,          "glVertexAttrib1fv");
    set_proc_address(&VertexAttrib1s,           "glVertexAttrib1s");
    set_proc_address(&VertexAttrib1sv,          "glVertexAttrib1sv");
    set_proc_address(&VertexAttrib2d,           "glVertexAttrib2d");
    set_proc_address(&VertexAttrib2dv,          "glVertexAttrib2dv");
    set_proc_address(&VertexAttrib2f,           "glVertexAttrib2f");
    set_proc_address(&VertexAttrib2fv,          "glVertexAttrib2fv");
    set_proc_address(&VertexAttrib2s,           "glVertexAttrib2s");
    set_proc_address(&VertexAttrib2sv,          "glVertexAttrib2sv");
    set_proc_address(&VertexAttrib3d,           "glVertexAttrib3d");
    set_proc_address(&VertexAttrib3dv,          "glVertexAttrib3dv");
    set_proc_address(&VertexAttrib3f,           "glVertexAttrib3f");
    set_proc_address(&VertexAttrib3fv,          "glVertexAttrib3fv");
    set_proc_address(&VertexAttrib3s,           "glVertexAttrib3s");
    set_proc_address(&VertexAttrib3sv,          "glVertexAttrib3sv");
    set_proc_address(&VertexAttrib4Nbv,         "glVertexAttrib4Nbv");
    set_proc_address(&VertexAttrib4Niv,         "glVertexAttrib4Niv");
    set_proc_address(&VertexAttrib4Nsv,         "glVertexAttrib4Nsv");
    set_proc_address(&VertexAttrib4Nub,         "glVertexAttrib4Nub");
    set_proc_address(&VertexAttrib4Nubv,        "glVertexAttrib4Nubv");
    set_proc_address(&VertexAttrib4Nuiv,        "glVertexAttrib4Nuiv");
    set_proc_address(&VertexAttrib4Nusv,        "glVertexAttrib4Nusv");
    set_proc_address(&VertexAttrib4bv,          "glVertexAttrib4bv");
    set_proc_address(&VertexAttrib4d,           "glVertexAttrib4d");
    set_proc_address(&VertexAttrib4dv,          "glVertexAttrib4dv");
    set_proc_address(&VertexAttrib4f,           "glVertexAttrib4f");
    set_proc_address(&VertexAttrib4fv,          "glVertexAttrib4fv");
    set_proc_address(&VertexAttrib4iv,          "glVertexAttrib4iv");
    set_proc_address(&VertexAttrib4s,           "glVertexAttrib4s");
    set_proc_address(&VertexAttrib4sv,          "glVertexAttrib4sv");
    set_proc_address(&VertexAttrib4ubv,         "glVertexAttrib4ubv");
    set_proc_address(&VertexAttrib4uiv,         "glVertexAttrib4uiv");
    set_proc_address(&VertexAttrib4usv,         "glVertexAttrib4usv");
    set_proc_address(&VertexAttribPointer,      "glVertexAttribPointer");
}


// VERSION_2_1
UniformMatrix2x3fv: proc "c" (location: i32, count: i32, transpose: u8, value: ^f32);
UniformMatrix3x2fv: proc "c" (location: i32, count: i32, transpose: u8, value: ^f32);
UniformMatrix2x4fv: proc "c" (location: i32, count: i32, transpose: u8, value: ^f32);
UniformMatrix4x2fv: proc "c" (location: i32, count: i32, transpose: u8, value: ^f32);
UniformMatrix3x4fv: proc "c" (location: i32, count: i32, transpose: u8, value: ^f32);
UniformMatrix4x3fv: proc "c" (location: i32, count: i32, transpose: u8, value: ^f32);

load_2_1 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&UniformMatrix2x3fv, "glUniformMatrix2x3fv");
    set_proc_address(&UniformMatrix3x2fv, "glUniformMatrix3x2fv");
    set_proc_address(&UniformMatrix2x4fv, "glUniformMatrix2x4fv");
    set_proc_address(&UniformMatrix4x2fv, "glUniformMatrix4x2fv");
    set_proc_address(&UniformMatrix3x4fv, "glUniformMatrix3x4fv");
    set_proc_address(&UniformMatrix4x3fv, "glUniformMatrix4x3fv");
}


// VERSION_3_0
 ColorMaski:                          proc "c" (index: u32, r: u8, g: u8, b: u8, a: u8);
 GetBooleani_v:                       proc "c" (target: u32, index: u32, data: ^u8);
 GetIntegeri_v:                       proc "c" (target: u32, index: u32, data: ^i32);
 Enablei:                             proc "c" (target: u32, index: u32);
 Disablei:                            proc "c" (target: u32, index: u32);
 IsEnabledi:                          proc "c" (target: u32, index: u32) -> u8;
 BeginTransformFeedback:              proc "c" (primitiveMode: u32);
 EndTransformFeedback:                proc "c" ();
 BindBufferRange:                     proc "c" (target: u32, index: u32, buffer: u32, offset: int, size: int);
 BindBufferBase:                      proc "c" (target: u32, index: u32, buffer: u32);
 TransformFeedbackVaryings:           proc "c" (program: u32, count: i32, varyings: ^u8, bufferMode: u32);
 GetTransformFeedbackVarying:         proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type_: ^u32, name: ^u8);
 ClampColor:                          proc "c" (target: u32, clamp: u32);
 BeginConditionalRender:              proc "c" (id: u32, mode: u32);
 EndConditionalRender:                proc "c" ();
 VertexAttribIPointer:                proc "c" (index: u32, size: i32, type_: u32, stride: i32, pointer: rawptr);
 GetVertexAttribIiv:                  proc "c" (index: u32, pname: u32, params: ^i32);
 GetVertexAttribIuiv:                 proc "c" (index: u32, pname: u32, params: ^u32);
 VertexAttribI1i:                     proc "c" (index: u32, x: i32);
 VertexAttribI2i:                     proc "c" (index: u32, x: i32, y: i32);
 VertexAttribI3i:                     proc "c" (index: u32, x: i32, y: i32, z: i32);
 VertexAttribI4i:                     proc "c" (index: u32, x: i32, y: i32, z: i32, w: i32);
 VertexAttribI1ui:                    proc "c" (index: u32, x: u32);
 VertexAttribI2ui:                    proc "c" (index: u32, x: u32, y: u32);
 VertexAttribI3ui:                    proc "c" (index: u32, x: u32, y: u32, z: u32);
 VertexAttribI4ui:                    proc "c" (index: u32, x: u32, y: u32, z: u32, w: u32);
 VertexAttribI1iv:                    proc "c" (index: u32, v: ^i32);
 VertexAttribI2iv:                    proc "c" (index: u32, v: ^i32);
 VertexAttribI3iv:                    proc "c" (index: u32, v: ^i32);
 VertexAttribI4iv:                    proc "c" (index: u32, v: ^i32);
 VertexAttribI1uiv:                   proc "c" (index: u32, v: ^u32);
 VertexAttribI2uiv:                   proc "c" (index: u32, v: ^u32);
 VertexAttribI3uiv:                   proc "c" (index: u32, v: ^u32);
 VertexAttribI4uiv:                   proc "c" (index: u32, v: ^u32);
 VertexAttribI4bv:                    proc "c" (index: u32, v: ^i8);
 VertexAttribI4sv:                    proc "c" (index: u32, v: ^i16);
 VertexAttribI4ubv:                   proc "c" (index: u32, v: ^u8);
 VertexAttribI4usv:                   proc "c" (index: u32, v: ^u16);
 GetUniformuiv:                       proc "c" (program: u32, location: i32, params: ^u32);
 BindFragDataLocation:                proc "c" (program: u32, color: u32, name: ^u8);
 GetFragDataLocation:                 proc "c" (program: u32, name: ^u8) -> i32;
 Uniform1ui:                          proc "c" (location: i32, v0: u32);
 Uniform2ui:                          proc "c" (location: i32, v0: u32, v1: u32);
 Uniform3ui:                          proc "c" (location: i32, v0: u32, v1: u32, v2: u32);
 Uniform4ui:                          proc "c" (location: i32, v0: u32, v1: u32, v2: u32, v3: u32);
 Uniform1uiv:                         proc "c" (location: i32, count: i32, value: ^u32);
 Uniform2uiv:                         proc "c" (location: i32, count: i32, value: ^u32);
 Uniform3uiv:                         proc "c" (location: i32, count: i32, value: ^u32);
 Uniform4uiv:                         proc "c" (location: i32, count: i32, value: ^u32);
 TexParameterIiv:                     proc "c" (target: u32, pname: u32, params: ^i32);
 TexParameterIuiv:                    proc "c" (target: u32, pname: u32, params: ^u32);
 GetTexParameterIiv:                  proc "c" (target: u32, pname: u32, params: ^i32);
 GetTexParameterIuiv:                 proc "c" (target: u32, pname: u32, params: ^u32);
 ClearBufferiv:                       proc "c" (buffer: u32, drawbuffer: i32, value: ^i32);
 ClearBufferuiv:                      proc "c" (buffer: u32, drawbuffer: i32, value: ^u32);
 ClearBufferfv:                       proc "c" (buffer: u32, drawbuffer: i32, value: ^f32);
 ClearBufferfi:                       proc "c" (buffer: u32, drawbuffer: i32, depth: f32, stencil: i32) -> rawptr;
 GetStringi:                          proc "c" (name: u32, index: u32) -> u8;
 IsRenderbuffer:                      proc "c" (renderbuffer: u32) -> u8;
 BindRenderbuffer:                    proc "c" (target: u32, renderbuffer: u32);
 DeleteRenderbuffers:                 proc "c" (n: i32, renderbuffers: ^u32);
 GenRenderbuffers:                    proc "c" (n: i32, renderbuffers: ^u32);
 RenderbufferStorage:                 proc "c" (target: u32, internalformat: u32, width: i32, height: i32);
 GetRenderbufferParameteriv:          proc "c" (target: u32, pname: u32, params: ^i32);
 IsFramebuffer:                       proc "c" (framebuffer: u32) -> u8;
 BindFramebuffer:                     proc "c" (target: u32, framebuffer: u32);
 DeleteFramebuffers:                  proc "c" (n: i32, framebuffers: ^u32);
 GenFramebuffers:                     proc "c" (n: i32, framebuffers: ^u32);
 CheckFramebufferStatus:              proc "c" (target: u32) -> u32;
 FramebufferTexture1D:                proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32);
 FramebufferTexture2D:                proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32);
 FramebufferTexture3D:                proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32, zoffset: i32);
 FramebufferRenderbuffer:             proc "c" (target: u32, attachment: u32, renderbuffertarget: u32, renderbuffer: u32);
 GetFramebufferAttachmentParameteriv: proc "c" (target: u32, attachment: u32, pname: u32, params: ^i32);
 GenerateMipmap:                      proc "c" (target: u32);
 BlitFramebuffer:                     proc "c" (srcX0: i32, srcY0: i32, srcX1: i32, srcY1: i32, dstX0: i32, dstY0: i32, dstX1: i32, dstY1: i32, mask: u32, filter: u32);
 RenderbufferStorageMultisample:      proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32);
 FramebufferTextureLayer:             proc "c" (target: u32, attachment: u32, texture: u32, level: i32, layer: i32);
 MapBufferRange:                      proc "c" (target: u32, offset: int, length: int, access: u32) -> rawptr;
 FlushMappedBufferRange:              proc "c" (target: u32, offset: int, length: int);
 BindVertexArray:                     proc "c" (array: u32);
 DeleteVertexArrays:                  proc "c" (n: i32, arrays: ^u32);
 GenVertexArrays:                     proc "c" (n: i32, arrays: ^u32);
 IsVertexArray:                       proc "c" (array: u32) -> u8;

load_3_0 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&ColorMaski,                          "glColorMaski");
    set_proc_address(&GetBooleani_v,                       "glGetBooleani_v");
    set_proc_address(&GetIntegeri_v,                       "glGetIntegeri_v");
    set_proc_address(&Enablei,                             "glEnablei");
    set_proc_address(&Disablei,                            "glDisablei");
    set_proc_address(&IsEnabledi,                          "glIsEnabledi");
    set_proc_address(&BeginTransformFeedback,              "glBeginTransformFeedback");
    set_proc_address(&EndTransformFeedback,                "glEndTransformFeedback");
    set_proc_address(&BindBufferRange,                     "glBindBufferRange");
    set_proc_address(&BindBufferBase,                      "glBindBufferBase");
    set_proc_address(&TransformFeedbackVaryings,           "glTransformFeedbackVaryings");
    set_proc_address(&GetTransformFeedbackVarying,         "glGetTransformFeedbackVarying");
    set_proc_address(&ClampColor,                          "glClampColor");
    set_proc_address(&BeginConditionalRender,              "glBeginConditionalRender");
    set_proc_address(&EndConditionalRender,                "glEndConditionalRender");
    set_proc_address(&VertexAttribIPointer,                "glVertexAttribIPointer");
    set_proc_address(&GetVertexAttribIiv,                  "glGetVertexAttribIiv");
    set_proc_address(&GetVertexAttribIuiv,                 "glGetVertexAttribIuiv");
    set_proc_address(&VertexAttribI1i,                     "glVertexAttribI1i");
    set_proc_address(&VertexAttribI2i,                     "glVertexAttribI2i");
    set_proc_address(&VertexAttribI3i,                     "glVertexAttribI3i");
    set_proc_address(&VertexAttribI4i,                     "glVertexAttribI4i");
    set_proc_address(&VertexAttribI1ui,                    "glVertexAttribI1ui");
    set_proc_address(&VertexAttribI2ui,                    "glVertexAttribI2ui");
    set_proc_address(&VertexAttribI3ui,                    "glVertexAttribI3ui");
    set_proc_address(&VertexAttribI4ui,                    "glVertexAttribI4ui");
    set_proc_address(&VertexAttribI1iv,                    "glVertexAttribI1iv");
    set_proc_address(&VertexAttribI2iv,                    "glVertexAttribI2iv");
    set_proc_address(&VertexAttribI3iv,                    "glVertexAttribI3iv");
    set_proc_address(&VertexAttribI4iv,                    "glVertexAttribI4iv");
    set_proc_address(&VertexAttribI1uiv,                   "glVertexAttribI1uiv");
    set_proc_address(&VertexAttribI2uiv,                   "glVertexAttribI2uiv");
    set_proc_address(&VertexAttribI3uiv,                   "glVertexAttribI3uiv");
    set_proc_address(&VertexAttribI4uiv,                   "glVertexAttribI4uiv");
    set_proc_address(&VertexAttribI4bv,                    "glVertexAttribI4bv");
    set_proc_address(&VertexAttribI4sv,                    "glVertexAttribI4sv");
    set_proc_address(&VertexAttribI4ubv,                   "glVertexAttribI4ubv");
    set_proc_address(&VertexAttribI4usv,                   "glVertexAttribI4usv");
    set_proc_address(&GetUniformuiv,                       "glGetUniformuiv");
    set_proc_address(&BindFragDataLocation,                "glBindFragDataLocation");
    set_proc_address(&GetFragDataLocation,                 "glGetFragDataLocation");
    set_proc_address(&Uniform1ui,                          "glUniform1ui");
    set_proc_address(&Uniform2ui,                          "glUniform2ui");
    set_proc_address(&Uniform3ui,                          "glUniform3ui");
    set_proc_address(&Uniform4ui,                          "glUniform4ui");
    set_proc_address(&Uniform1uiv,                         "glUniform1uiv");
    set_proc_address(&Uniform2uiv,                         "glUniform2uiv");
    set_proc_address(&Uniform3uiv,                         "glUniform3uiv");
    set_proc_address(&Uniform4uiv,                         "glUniform4uiv");
    set_proc_address(&TexParameterIiv,                     "glTexParameterIiv");
    set_proc_address(&TexParameterIuiv,                    "glTexParameterIuiv");
    set_proc_address(&GetTexParameterIiv,                  "glGetTexParameterIiv");
    set_proc_address(&GetTexParameterIuiv,                 "glGetTexParameterIuiv");
    set_proc_address(&ClearBufferiv,                       "glClearBufferiv");
    set_proc_address(&ClearBufferuiv,                      "glClearBufferuiv");
    set_proc_address(&ClearBufferfv,                       "glClearBufferfv");
    set_proc_address(&ClearBufferfi,                       "glClearBufferfi");
    set_proc_address(&GetStringi,                          "glGetStringi");
    set_proc_address(&IsRenderbuffer,                      "glIsRenderbuffer");
    set_proc_address(&BindRenderbuffer,                    "glBindRenderbuffer");
    set_proc_address(&DeleteRenderbuffers,                 "glDeleteRenderbuffers");
    set_proc_address(&GenRenderbuffers,                    "glGenRenderbuffers");
    set_proc_address(&RenderbufferStorage,                 "glRenderbufferStorage");
    set_proc_address(&GetRenderbufferParameteriv,          "glGetRenderbufferParameteriv");
    set_proc_address(&IsFramebuffer,                       "glIsFramebuffer");
    set_proc_address(&BindFramebuffer,                     "glBindFramebuffer");
    set_proc_address(&DeleteFramebuffers,                  "glDeleteFramebuffers");
    set_proc_address(&GenFramebuffers,                     "glGenFramebuffers");
    set_proc_address(&CheckFramebufferStatus,              "glCheckFramebufferStatus");
    set_proc_address(&FramebufferTexture1D,                "glFramebufferTexture1D");
    set_proc_address(&FramebufferTexture2D,                "glFramebufferTexture2D");
    set_proc_address(&FramebufferTexture3D,                "glFramebufferTexture3D");
    set_proc_address(&FramebufferRenderbuffer,             "glFramebufferRenderbuffer");
    set_proc_address(&GetFramebufferAttachmentParameteriv, "glGetFramebufferAttachmentParameteriv");
    set_proc_address(&GenerateMipmap,                      "glGenerateMipmap");
    set_proc_address(&BlitFramebuffer,                     "glBlitFramebuffer");
    set_proc_address(&RenderbufferStorageMultisample,      "glRenderbufferStorageMultisample");
    set_proc_address(&FramebufferTextureLayer,             "glFramebufferTextureLayer");
    set_proc_address(&MapBufferRange,                      "glMapBufferRange");
    set_proc_address(&FlushMappedBufferRange,              "glFlushMappedBufferRange");
    set_proc_address(&BindVertexArray,                     "glBindVertexArray");
    set_proc_address(&DeleteVertexArrays,                  "glDeleteVertexArrays");
    set_proc_address(&GenVertexArrays,                     "glGenVertexArrays");
    set_proc_address(&IsVertexArray,                       "glIsVertexArray");
}


// VERSION_3_1
DrawArraysInstanced:       proc "c" (mode: u32, first: i32, count: i32, instancecount: i32);
DrawElementsInstanced:     proc "c" (mode: u32, count: i32, type_: u32, indices: rawptr, instancecount: i32);
TexBuffer:                 proc "c" (target: u32, internalformat: u32, buffer: u32);
PrimitiveRestartIndex:     proc "c" (index: u32);
CopyBufferSubData:         proc "c" (readTarget: u32, writeTarget: u32, readOffset: int, writeOffset: int, size: int);
GetUniformIndices:         proc "c" (program: u32, uniformCount: i32, uniformNames: ^u8, uniformIndices: ^u32);
GetActiveUniformsiv:       proc "c" (program: u32, uniformCount: i32, uniformIndices: ^u32, pname: u32, params: ^i32);
GetActiveUniformName:      proc "c" (program: u32, uniformIndex: u32, bufSize: i32, length: ^i32, uniformName: ^u8);
GetUniformBlockIndex:      proc "c" (program: u32, uniformBlockName: ^u8) -> u32;
GetActiveUniformBlockiv:   proc "c" (program: u32, uniformBlockIndex: u32, pname: u32, params: ^i32);
GetActiveUniformBlockName: proc "c" (program: u32, uniformBlockIndex: u32, bufSize: i32, length: ^i32, uniformBlockName: ^u8);
UniformBlockBinding:       proc "c" (program: u32, uniformBlockIndex: u32, uniformBlockBinding: u32);

load_3_1 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&DrawArraysInstanced,       "glDrawArraysInstanced");
    set_proc_address(&DrawElementsInstanced,     "glDrawElementsInstanced");
    set_proc_address(&TexBuffer,                 "glTexBuffer");
    set_proc_address(&PrimitiveRestartIndex,     "glPrimitiveRestartIndex");
    set_proc_address(&CopyBufferSubData,         "glCopyBufferSubData");
    set_proc_address(&GetUniformIndices,         "glGetUniformIndices");
    set_proc_address(&GetActiveUniformsiv,       "glGetActiveUniformsiv");
    set_proc_address(&GetActiveUniformName,      "glGetActiveUniformName");
    set_proc_address(&GetUniformBlockIndex,      "glGetUniformBlockIndex");
    set_proc_address(&GetActiveUniformBlockiv,   "glGetActiveUniformBlockiv");
    set_proc_address(&GetActiveUniformBlockName, "glGetActiveUniformBlockName");
    set_proc_address(&UniformBlockBinding,       "glUniformBlockBinding");
}


// VERSION_3_2
DrawElementsBaseVertex:          proc "c" (mode: u32, count: i32, type_: u32, indices: rawptr, basevertex: i32);
DrawRangeElementsBaseVertex:     proc "c" (mode: u32, start: u32, end: u32, count: i32, type_: u32, indices: rawptr, basevertex: i32);
DrawElementsInstancedBaseVertex: proc "c" (mode: u32, count: i32, type_: u32, indices: rawptr, instancecount: i32, basevertex: i32);
MultiDrawElementsBaseVertex:     proc "c" (mode: u32, count: ^i32, type_: u32, indices: ^rawptr, drawcount: i32, basevertex: ^i32);
ProvokingVertex:                 proc "c" (mode: u32);
FenceSync:                       proc "c" (condition: u32, flags: u32) -> sync_t;
IsSync:                          proc "c" (sync: sync_t) -> u8;
DeleteSync:                      proc "c" (sync: sync_t);
ClientWaitSync:                  proc "c" (sync: sync_t, flags: u32, timeout: u64) -> u32;
WaitSync:                        proc "c" (sync: sync_t, flags: u32, timeout: u64);
GetInteger64v:                   proc "c" (pname: u32, data: ^i64);
GetSynciv:                       proc "c" (sync: sync_t, pname: u32, bufSize: i32, length: ^i32, values: ^i32);
GetInteger64i_v:                 proc "c" (target: u32, index: u32, data: ^i64);
GetBufferParameteri64v:          proc "c" (target: u32, pname: u32, params: ^i64);
FramebufferTexture:              proc "c" (target: u32, attachment: u32, texture: u32, level: i32);
TexImage2DMultisample:           proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32, fixedsamplelocations: u8);
TexImage3DMultisample:           proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32, depth: i32, fixedsamplelocations: u8);
GetMultisamplefv:                proc "c" (pname: u32, index: u32, val: ^f32);
SampleMaski:                     proc "c" (maskNumber: u32, mask: u32);

load_3_2 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&DrawElementsBaseVertex,          "glDrawElementsBaseVertex");
    set_proc_address(&DrawRangeElementsBaseVertex,     "glDrawRangeElementsBaseVertex");
    set_proc_address(&DrawElementsInstancedBaseVertex, "glDrawElementsInstancedBaseVertex");
    set_proc_address(&MultiDrawElementsBaseVertex,     "glMultiDrawElementsBaseVertex");
    set_proc_address(&ProvokingVertex,                 "glProvokingVertex");
    set_proc_address(&FenceSync,                       "glFenceSync");
    set_proc_address(&IsSync,                          "glIsSync");
    set_proc_address(&DeleteSync,                      "glDeleteSync");
    set_proc_address(&ClientWaitSync,                  "glClientWaitSync");
    set_proc_address(&WaitSync,                        "glWaitSync");
    set_proc_address(&GetInteger64v,                   "glGetInteger64v");
    set_proc_address(&GetSynciv,                       "glGetSynciv");
    set_proc_address(&GetInteger64i_v,                 "glGetInteger64i_v");
    set_proc_address(&GetBufferParameteri64v,          "glGetBufferParameteri64v");
    set_proc_address(&FramebufferTexture,              "glFramebufferTexture");
    set_proc_address(&TexImage2DMultisample,           "glTexImage2DMultisample");
    set_proc_address(&TexImage3DMultisample,           "glTexImage3DMultisample");
    set_proc_address(&GetMultisamplefv,                "glGetMultisamplefv");
    set_proc_address(&SampleMaski,                     "glSampleMaski");
}


// VERSION_3_3
BindFragDataLocationIndexed: proc "c" (program: u32, colorNumber: u32, index: u32, name: ^u8);
GetFragDataIndex:            proc "c" (program: u32, name: ^u8) -> i32;
GenSamplers:                 proc "c" (count: i32, samplers: ^u32);
DeleteSamplers:              proc "c" (count: i32, samplers: ^u32);
IsSampler:                   proc "c" (sampler: u32) -> u8;
BindSampler:                 proc "c" (unit: u32, sampler: u32);
SamplerParameteri:           proc "c" (sampler: u32, pname: u32, param: i32);
SamplerParameteriv:          proc "c" (sampler: u32, pname: u32, param: ^i32);
SamplerParameterf:           proc "c" (sampler: u32, pname: u32, param: f32);
SamplerParameterfv:          proc "c" (sampler: u32, pname: u32, param: ^f32);
SamplerParameterIiv:         proc "c" (sampler: u32, pname: u32, param: ^i32);
SamplerParameterIuiv:        proc "c" (sampler: u32, pname: u32, param: ^u32);
GetSamplerParameteriv:       proc "c" (sampler: u32, pname: u32, params: ^i32);
GetSamplerParameterIiv:      proc "c" (sampler: u32, pname: u32, params: ^i32);
GetSamplerParameterfv:       proc "c" (sampler: u32, pname: u32, params: ^f32);
GetSamplerParameterIuiv:     proc "c" (sampler: u32, pname: u32, params: ^u32);
QueryCounter:                proc "c" (id: u32, target: u32);
GetQueryObjecti64v:          proc "c" (id: u32, pname: u32, params: ^i64);
GetQueryObjectui64v:         proc "c" (id: u32, pname: u32, params: ^u64);
VertexAttribDivisor:         proc "c" (index: u32, divisor: u32);
VertexAttribP1ui:            proc "c" (index: u32, type_: u32, normalized: u8, value: u32);
VertexAttribP1uiv:           proc "c" (index: u32, type_: u32, normalized: u8, value: ^u32);
VertexAttribP2ui:            proc "c" (index: u32, type_: u32, normalized: u8, value: u32);
VertexAttribP2uiv:           proc "c" (index: u32, type_: u32, normalized: u8, value: ^u32);
VertexAttribP3ui:            proc "c" (index: u32, type_: u32, normalized: u8, value: u32);
VertexAttribP3uiv:           proc "c" (index: u32, type_: u32, normalized: u8, value: ^u32);
VertexAttribP4ui:            proc "c" (index: u32, type_: u32, normalized: u8, value: u32);
VertexAttribP4uiv:           proc "c" (index: u32, type_: u32, normalized: u8, value: ^u32);
VertexP2ui:                  proc "c" (type_: u32, value: u32);
VertexP2uiv:                 proc "c" (type_: u32, value: ^u32);
VertexP3ui:                  proc "c" (type_: u32, value: u32);
VertexP3uiv:                 proc "c" (type_: u32, value: ^u32);
VertexP4ui:                  proc "c" (type_: u32, value: u32);
VertexP4uiv:                 proc "c" (type_: u32, value: ^u32);
TexCoordP1ui:                proc "c" (type_: u32, coords: u32);
TexCoordP1uiv:               proc "c" (type_: u32, coords: ^u32);
TexCoordP2ui:                proc "c" (type_: u32, coords: u32);
TexCoordP2uiv:               proc "c" (type_: u32, coords: ^u32);
TexCoordP3ui:                proc "c" (type_: u32, coords: u32);
TexCoordP3uiv:               proc "c" (type_: u32, coords: ^u32);
TexCoordP4ui:                proc "c" (type_: u32, coords: u32);
TexCoordP4uiv:               proc "c" (type_: u32, coords: ^u32);
MultiTexCoordP1ui:           proc "c" (texture: u32, type_: u32, coords: u32);
MultiTexCoordP1uiv:          proc "c" (texture: u32, type_: u32, coords: ^u32);
MultiTexCoordP2ui:           proc "c" (texture: u32, type_: u32, coords: u32);
MultiTexCoordP2uiv:          proc "c" (texture: u32, type_: u32, coords: ^u32);
MultiTexCoordP3ui:           proc "c" (texture: u32, type_: u32, coords: u32);
MultiTexCoordP3uiv:          proc "c" (texture: u32, type_: u32, coords: ^u32);
MultiTexCoordP4ui:           proc "c" (texture: u32, type_: u32, coords: u32);
MultiTexCoordP4uiv:          proc "c" (texture: u32, type_: u32, coords: ^u32);
NormalP3ui:                  proc "c" (type_: u32, coords: u32);
NormalP3uiv:                 proc "c" (type_: u32, coords: ^u32);
ColorP3ui:                   proc "c" (type_: u32, color: u32);
ColorP3uiv:                  proc "c" (type_: u32, color: ^u32);
ColorP4ui:                   proc "c" (type_: u32, color: u32);
ColorP4uiv:                  proc "c" (type_: u32, color: ^u32);
SecondaryColorP3ui:          proc "c" (type_: u32, color: u32);
SecondaryColorP3uiv:         proc "c" (type_: u32, color: ^u32);

load_3_3 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&BindFragDataLocationIndexed, "glBindFragDataLocationIndexed");
    set_proc_address(&GetFragDataIndex,            "glGetFragDataIndex");
    set_proc_address(&GenSamplers,                 "glGenSamplers");
    set_proc_address(&DeleteSamplers,              "glDeleteSamplers");
    set_proc_address(&IsSampler,                   "glIsSampler");
    set_proc_address(&BindSampler,                 "glBindSampler");
    set_proc_address(&SamplerParameteri,           "glSamplerParameteri");
    set_proc_address(&SamplerParameteriv,          "glSamplerParameteriv");
    set_proc_address(&SamplerParameterf,           "glSamplerParameterf");
    set_proc_address(&SamplerParameterfv,          "glSamplerParameterfv");
    set_proc_address(&SamplerParameterIiv,         "glSamplerParameterIiv");
    set_proc_address(&SamplerParameterIuiv,        "glSamplerParameterIuiv");
    set_proc_address(&GetSamplerParameteriv,       "glGetSamplerParameteriv");
    set_proc_address(&GetSamplerParameterIiv,      "glGetSamplerParameterIiv");
    set_proc_address(&GetSamplerParameterfv,       "glGetSamplerParameterfv");
    set_proc_address(&GetSamplerParameterIuiv,     "glGetSamplerParameterIuiv");
    set_proc_address(&QueryCounter,                "glQueryCounter");
    set_proc_address(&GetQueryObjecti64v,          "glGetQueryObjecti64v");
    set_proc_address(&GetQueryObjectui64v,         "glGetQueryObjectui64v");
    set_proc_address(&VertexAttribDivisor,         "glVertexAttribDivisor");
    set_proc_address(&VertexAttribP1ui,            "glVertexAttribP1ui");
    set_proc_address(&VertexAttribP1uiv,           "glVertexAttribP1uiv");
    set_proc_address(&VertexAttribP2ui,            "glVertexAttribP2ui");
    set_proc_address(&VertexAttribP2uiv,           "glVertexAttribP2uiv");
    set_proc_address(&VertexAttribP3ui,            "glVertexAttribP3ui");
    set_proc_address(&VertexAttribP3uiv,           "glVertexAttribP3uiv");
    set_proc_address(&VertexAttribP4ui,            "glVertexAttribP4ui");
    set_proc_address(&VertexAttribP4uiv,           "glVertexAttribP4uiv");
    set_proc_address(&VertexP2ui,                  "glVertexP2ui");
    set_proc_address(&VertexP2uiv,                 "glVertexP2uiv");
    set_proc_address(&VertexP3ui,                  "glVertexP3ui");
    set_proc_address(&VertexP3uiv,                 "glVertexP3uiv");
    set_proc_address(&VertexP4ui,                  "glVertexP4ui");
    set_proc_address(&VertexP4uiv,                 "glVertexP4uiv");
    set_proc_address(&TexCoordP1ui,                "glTexCoordP1ui");
    set_proc_address(&TexCoordP1uiv,               "glTexCoordP1uiv");
    set_proc_address(&TexCoordP2ui,                "glTexCoordP2ui");
    set_proc_address(&TexCoordP2uiv,               "glTexCoordP2uiv");
    set_proc_address(&TexCoordP3ui,                "glTexCoordP3ui");
    set_proc_address(&TexCoordP3uiv,               "glTexCoordP3uiv");
    set_proc_address(&TexCoordP4ui,                "glTexCoordP4ui");
    set_proc_address(&TexCoordP4uiv,               "glTexCoordP4uiv");
    set_proc_address(&MultiTexCoordP1ui,           "glMultiTexCoordP1ui");
    set_proc_address(&MultiTexCoordP1uiv,          "glMultiTexCoordP1uiv");
    set_proc_address(&MultiTexCoordP2ui,           "glMultiTexCoordP2ui");
    set_proc_address(&MultiTexCoordP2uiv,          "glMultiTexCoordP2uiv");
    set_proc_address(&MultiTexCoordP3ui,           "glMultiTexCoordP3ui");
    set_proc_address(&MultiTexCoordP3uiv,          "glMultiTexCoordP3uiv");
    set_proc_address(&MultiTexCoordP4ui,           "glMultiTexCoordP4ui");
    set_proc_address(&MultiTexCoordP4uiv,          "glMultiTexCoordP4uiv");
    set_proc_address(&NormalP3ui,                  "glNormalP3ui");
    set_proc_address(&NormalP3uiv,                 "glNormalP3uiv");
    set_proc_address(&ColorP3ui,                   "glColorP3ui");
    set_proc_address(&ColorP3uiv,                  "glColorP3uiv");
    set_proc_address(&ColorP4ui,                   "glColorP4ui");
    set_proc_address(&ColorP4uiv,                  "glColorP4uiv");
    set_proc_address(&SecondaryColorP3ui,          "glSecondaryColorP3ui");
    set_proc_address(&SecondaryColorP3uiv,         "glSecondaryColorP3uiv");
}


// VERSION_4_0
MinSampleShading:               proc "c" (value: f32);
BlendEquationi:                 proc "c" (buf: u32, mode: u32);
BlendEquationSeparatei:         proc "c" (buf: u32, modeRGB: u32, modeAlpha: u32);
BlendFunci:                     proc "c" (buf: u32, src: u32, dst: u32);
BlendFuncSeparatei:             proc "c" (buf: u32, srcRGB: u32, dstRGB: u32, srcAlpha: u32, dstAlpha: u32);
DrawArraysIndirect:             proc "c" (mode: u32, indirect: rawptr);
DrawElementsIndirect:           proc "c" (mode: u32, type_: u32, indirect: rawptr);
Uniform1d:                      proc "c" (location: i32, x: f64);
Uniform2d:                      proc "c" (location: i32, x: f64, y: f64);
Uniform3d:                      proc "c" (location: i32, x: f64, y: f64, z: f64);
Uniform4d:                      proc "c" (location: i32, x: f64, y: f64, z: f64, w: f64);
Uniform1dv:                     proc "c" (location: i32, count: i32, value: ^f64);
Uniform2dv:                     proc "c" (location: i32, count: i32, value: ^f64);
Uniform3dv:                     proc "c" (location: i32, count: i32, value: ^f64);
Uniform4dv:                     proc "c" (location: i32, count: i32, value: ^f64);
UniformMatrix2dv:               proc "c" (location: i32, count: i32, transpose: u8, value: ^f64);
UniformMatrix3dv:               proc "c" (location: i32, count: i32, transpose: u8, value: ^f64);
UniformMatrix4dv:               proc "c" (location: i32, count: i32, transpose: u8, value: ^f64);
UniformMatrix2x3dv:             proc "c" (location: i32, count: i32, transpose: u8, value: ^f64);
UniformMatrix2x4dv:             proc "c" (location: i32, count: i32, transpose: u8, value: ^f64);
UniformMatrix3x2dv:             proc "c" (location: i32, count: i32, transpose: u8, value: ^f64);
UniformMatrix3x4dv:             proc "c" (location: i32, count: i32, transpose: u8, value: ^f64);
UniformMatrix4x2dv:             proc "c" (location: i32, count: i32, transpose: u8, value: ^f64);
UniformMatrix4x3dv:             proc "c" (location: i32, count: i32, transpose: u8, value: ^f64);
GetUniformdv:                   proc "c" (program: u32, location: i32, params: ^f64);
GetSubroutineUniformLocation:   proc "c" (program: u32, shadertype_: u32, name: ^u8) -> i32;
GetSubroutineIndex:             proc "c" (program: u32, shadertype_: u32, name: ^u8) -> u32;
GetActiveSubroutineUniformiv:   proc "c" (program: u32, shadertype_: u32, index: u32, pname: u32, values: ^i32);
GetActiveSubroutineUniformName: proc "c" (program: u32, shadertype_: u32, index: u32, bufsize: i32, length: ^i32, name: ^u8);
GetActiveSubroutineName:        proc "c" (program: u32, shadertype_: u32, index: u32, bufsize: i32, length: ^i32, name: ^u8);
UniformSubroutinesuiv:          proc "c" (shadertype_: u32, count: i32, indices: ^u32);
GetUniformSubroutineuiv:        proc "c" (shadertype_: u32, location: i32, params: ^u32);
GetProgramStageiv:              proc "c" (program: u32, shadertype_: u32, pname: u32, values: ^i32);
PatchParameteri:                proc "c" (pname: u32, value: i32);
PatchParameterfv:               proc "c" (pname: u32, values: ^f32);
BindTransformFeedback:          proc "c" (target: u32, id: u32);
DeleteTransformFeedbacks:       proc "c" (n: i32, ids: ^u32);
GenTransformFeedbacks:          proc "c" (n: i32, ids: ^u32);
IsTransformFeedback:            proc "c" (id: u32) -> u8;
PauseTransformFeedback:         proc "c" ();
ResumeTransformFeedback:        proc "c" ();
DrawTransformFeedback:          proc "c" (mode: u32, id: u32);
DrawTransformFeedbackStream:    proc "c" (mode: u32, id: u32, stream: u32);
BeginQueryIndexed:              proc "c" (target: u32, index: u32, id: u32);
EndQueryIndexed:                proc "c" (target: u32, index: u32);
GetQueryIndexediv:              proc "c" (target: u32, index: u32, pname: u32, params: ^i32);

load_4_0 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&MinSampleShading,               "glMinSampleShading");
    set_proc_address(&BlendEquationi,                 "glBlendEquationi");
    set_proc_address(&BlendEquationSeparatei,         "glBlendEquationSeparatei");
    set_proc_address(&BlendFunci,                     "glBlendFunci");
    set_proc_address(&BlendFuncSeparatei,             "glBlendFuncSeparatei");
    set_proc_address(&DrawArraysIndirect,             "glDrawArraysIndirect");
    set_proc_address(&DrawElementsIndirect,           "glDrawElementsIndirect");
    set_proc_address(&Uniform1d,                      "glUniform1d");
    set_proc_address(&Uniform2d,                      "glUniform2d");
    set_proc_address(&Uniform3d,                      "glUniform3d");
    set_proc_address(&Uniform4d,                      "glUniform4d");
    set_proc_address(&Uniform1dv,                     "glUniform1dv");
    set_proc_address(&Uniform2dv,                     "glUniform2dv");
    set_proc_address(&Uniform3dv,                     "glUniform3dv");
    set_proc_address(&Uniform4dv,                     "glUniform4dv");
    set_proc_address(&UniformMatrix2dv,               "glUniformMatrix2dv");
    set_proc_address(&UniformMatrix3dv,               "glUniformMatrix3dv");
    set_proc_address(&UniformMatrix4dv,               "glUniformMatrix4dv");
    set_proc_address(&UniformMatrix2x3dv,             "glUniformMatrix2x3dv");
    set_proc_address(&UniformMatrix2x4dv,             "glUniformMatrix2x4dv");
    set_proc_address(&UniformMatrix3x2dv,             "glUniformMatrix3x2dv");
    set_proc_address(&UniformMatrix3x4dv,             "glUniformMatrix3x4dv");
    set_proc_address(&UniformMatrix4x2dv,             "glUniformMatrix4x2dv");
    set_proc_address(&UniformMatrix4x3dv,             "glUniformMatrix4x3dv");
    set_proc_address(&GetUniformdv,                   "glGetUniformdv");
    set_proc_address(&GetSubroutineUniformLocation,   "glGetSubroutineUniformLocation");
    set_proc_address(&GetSubroutineIndex,             "glGetSubroutineIndex");
    set_proc_address(&GetActiveSubroutineUniformiv,   "glGetActiveSubroutineUniformiv");
    set_proc_address(&GetActiveSubroutineUniformName, "glGetActiveSubroutineUniformName");
    set_proc_address(&GetActiveSubroutineName,        "glGetActiveSubroutineName");
    set_proc_address(&UniformSubroutinesuiv,          "glUniformSubroutinesuiv");
    set_proc_address(&GetUniformSubroutineuiv,        "glGetUniformSubroutineuiv");
    set_proc_address(&GetProgramStageiv,              "glGetProgramStageiv");
    set_proc_address(&PatchParameteri,                "glPatchParameteri");
    set_proc_address(&PatchParameterfv,               "glPatchParameterfv");
    set_proc_address(&BindTransformFeedback,          "glBindTransformFeedback");
    set_proc_address(&DeleteTransformFeedbacks,       "glDeleteTransformFeedbacks");
    set_proc_address(&GenTransformFeedbacks,          "glGenTransformFeedbacks");
    set_proc_address(&IsTransformFeedback,            "glIsTransformFeedback");
    set_proc_address(&PauseTransformFeedback,         "glPauseTransformFeedback");
    set_proc_address(&ResumeTransformFeedback,        "glResumeTransformFeedback");
    set_proc_address(&DrawTransformFeedback,          "glDrawTransformFeedback");
    set_proc_address(&DrawTransformFeedbackStream,    "glDrawTransformFeedbackStream");
    set_proc_address(&BeginQueryIndexed,              "glBeginQueryIndexed");
    set_proc_address(&EndQueryIndexed,                "glEndQueryIndexed");
    set_proc_address(&GetQueryIndexediv,              "glGetQueryIndexediv");
}


// VERSION_4_1
ReleaseShaderCompiler:     proc "c" ();
ShaderBinary:              proc "c" (count: i32, shaders: ^u32, binaryformat: u32, binary: rawptr, length: i32);
GetShaderPrecisionFormat:  proc "c" (shadertype_: u32, precisiontype_: u32, range: ^i32, precision: ^i32);
DepthRangef:               proc "c" (n: f32, f: f32);
ClearDepthf:               proc "c" (d: f32);
GetProgramBinary:          proc "c" (program: u32, bufSize: i32, length: ^i32, binaryFormat: ^u32, binary: rawptr);
ProgramBinary:             proc "c" (program: u32, binaryFormat: u32, binary: rawptr, length: i32);
ProgramParameteri:         proc "c" (program: u32, pname: u32, value: i32);
UseProgramStages:          proc "c" (pipeline: u32, stages: u32, program: u32);
ActiveShaderProgram:       proc "c" (pipeline: u32, program: u32);
CreateShaderProgramv:      proc "c" (type_: u32, count: i32, strings: ^u8) -> u32;
BindProgramPipeline:       proc "c" (pipeline: u32);
DeleteProgramPipelines:    proc "c" (n: i32, pipelines: ^u32);
GenProgramPipelines:       proc "c" (n: i32, pipelines: ^u32);
IsProgramPipeline:         proc "c" (pipeline: u32) -> u8;
GetProgramPipelineiv:      proc "c" (pipeline: u32, pname: u32, params: ^i32);
ProgramUniform1i:          proc "c" (program: u32, location: i32, v0: i32);
ProgramUniform1iv:         proc "c" (program: u32, location: i32, count: i32, value: ^i32);
ProgramUniform1f:          proc "c" (program: u32, location: i32, v0: f32);
ProgramUniform1fv:         proc "c" (program: u32, location: i32, count: i32, value: ^f32);
ProgramUniform1d:          proc "c" (program: u32, location: i32, v0: f64);
ProgramUniform1dv:         proc "c" (program: u32, location: i32, count: i32, value: ^f64);
ProgramUniform1ui:         proc "c" (program: u32, location: i32, v0: u32);
ProgramUniform1uiv:        proc "c" (program: u32, location: i32, count: i32, value: ^u32);
ProgramUniform2i:          proc "c" (program: u32, location: i32, v0: i32, v1: i32);
ProgramUniform2iv:         proc "c" (program: u32, location: i32, count: i32, value: ^i32);
ProgramUniform2f:          proc "c" (program: u32, location: i32, v0: f32, v1: f32);
ProgramUniform2fv:         proc "c" (program: u32, location: i32, count: i32, value: ^f32);
ProgramUniform2d:          proc "c" (program: u32, location: i32, v0: f64, v1: f64);
ProgramUniform2dv:         proc "c" (program: u32, location: i32, count: i32, value: ^f64);
ProgramUniform2ui:         proc "c" (program: u32, location: i32, v0: u32, v1: u32);
ProgramUniform2uiv:        proc "c" (program: u32, location: i32, count: i32, value: ^u32);
ProgramUniform3i:          proc "c" (program: u32, location: i32, v0: i32, v1: i32, v2: i32);
ProgramUniform3iv:         proc "c" (program: u32, location: i32, count: i32, value: ^i32);
ProgramUniform3f:          proc "c" (program: u32, location: i32, v0: f32, v1: f32, v2: f32);
ProgramUniform3fv:         proc "c" (program: u32, location: i32, count: i32, value: ^f32);
ProgramUniform3d:          proc "c" (program: u32, location: i32, v0: f64, v1: f64, v2: f64);
ProgramUniform3dv:         proc "c" (program: u32, location: i32, count: i32, value: ^f64);
ProgramUniform3ui:         proc "c" (program: u32, location: i32, v0: u32, v1: u32, v2: u32);
ProgramUniform3uiv:        proc "c" (program: u32, location: i32, count: i32, value: ^u32);
ProgramUniform4i:          proc "c" (program: u32, location: i32, v0: i32, v1: i32, v2: i32, v3: i32);
ProgramUniform4iv:         proc "c" (program: u32, location: i32, count: i32, value: ^i32);
ProgramUniform4f:          proc "c" (program: u32, location: i32, v0: f32, v1: f32, v2: f32, v3: f32);
ProgramUniform4fv:         proc "c" (program: u32, location: i32, count: i32, value: ^f32);
ProgramUniform4d:          proc "c" (program: u32, location: i32, v0: f64, v1: f64, v2: f64, v3: f64);
ProgramUniform4dv:         proc "c" (program: u32, location: i32, count: i32, value: ^f64);
ProgramUniform4ui:         proc "c" (program: u32, location: i32, v0: u32, v1: u32, v2: u32, v3: u32);
ProgramUniform4uiv:        proc "c" (program: u32, location: i32, count: i32, value: ^u32);
ProgramUniformMatrix2fv:   proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f32);
ProgramUniformMatrix3fv:   proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f32);
ProgramUniformMatrix4fv:   proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f32);
ProgramUniformMatrix2dv:   proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f64);
ProgramUniformMatrix3dv:   proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f64);
ProgramUniformMatrix4dv:   proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f64);
ProgramUniformMatrix2x3fv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f32);
ProgramUniformMatrix3x2fv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f32);
ProgramUniformMatrix2x4fv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f32);
ProgramUniformMatrix4x2fv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f32);
ProgramUniformMatrix3x4fv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f32);
ProgramUniformMatrix4x3fv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f32);
ProgramUniformMatrix2x3dv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f64);
ProgramUniformMatrix3x2dv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f64);
ProgramUniformMatrix2x4dv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f64);
ProgramUniformMatrix4x2dv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f64);
ProgramUniformMatrix3x4dv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f64);
ProgramUniformMatrix4x3dv: proc "c" (program: u32, location: i32, count: i32, transpose: u8, value: ^f64);
ValidateProgramPipeline:   proc "c" (pipeline: u32);
GetProgramPipelineInfoLog: proc "c" (pipeline: u32, bufSize: i32, length: ^i32, infoLog: ^u8);
VertexAttribL1d:           proc "c" (index: u32, x: f64);
VertexAttribL2d:           proc "c" (index: u32, x: f64, y: f64);
VertexAttribL3d:           proc "c" (index: u32, x: f64, y: f64, z: f64);
VertexAttribL4d:           proc "c" (index: u32, x: f64, y: f64, z: f64, w: f64);
VertexAttribL1dv:          proc "c" (index: u32, v: ^f64);
VertexAttribL2dv:          proc "c" (index: u32, v: ^f64);
VertexAttribL3dv:          proc "c" (index: u32, v: ^f64);
VertexAttribL4dv:          proc "c" (index: u32, v: ^f64);
VertexAttribLPointer:      proc "c" (index: u32, size: i32, type_: u32, stride: i32, pointer: rawptr);
GetVertexAttribLdv:        proc "c" (index: u32, pname: u32, params: ^f64);
ViewportArrayv:            proc "c" (first: u32, count: i32, v: ^f32);
ViewportIndexedf:          proc "c" (index: u32, x: f32, y: f32, w: f32, h: f32);
ViewportIndexedfv:         proc "c" (index: u32, v: ^f32);
ScissorArrayv:             proc "c" (first: u32, count: i32, v: ^i32);
ScissorIndexed:            proc "c" (index: u32, left: i32, bottom: i32, width: i32, height: i32);
ScissorIndexedv:           proc "c" (index: u32, v: ^i32);
DepthRangeArrayv:          proc "c" (first: u32, count: i32, v: ^f64);
DepthRangeIndexed:         proc "c" (index: u32, n: f64, f: f64);
GetFloati_v:               proc "c" (target: u32, index: u32, data: ^f32);
GetDoublei_v:              proc "c" (target: u32, index: u32, data: ^f64);

load_4_1 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&ReleaseShaderCompiler,     "glReleaseShaderCompiler");
    set_proc_address(&ShaderBinary,              "glShaderBinary");
    set_proc_address(&GetShaderPrecisionFormat,  "glGetShaderPrecisionFormat");
    set_proc_address(&DepthRangef,               "glDepthRangef");
    set_proc_address(&ClearDepthf,               "glClearDepthf");
    set_proc_address(&GetProgramBinary,          "glGetProgramBinary");
    set_proc_address(&ProgramBinary,             "glProgramBinary");
    set_proc_address(&ProgramParameteri,         "glProgramParameteri");
    set_proc_address(&UseProgramStages,          "glUseProgramStages");
    set_proc_address(&ActiveShaderProgram,       "glActiveShaderProgram");
    set_proc_address(&CreateShaderProgramv,      "glCreateShaderProgramv");
    set_proc_address(&BindProgramPipeline,       "glBindProgramPipeline");
    set_proc_address(&DeleteProgramPipelines,    "glDeleteProgramPipelines");
    set_proc_address(&GenProgramPipelines,       "glGenProgramPipelines");
    set_proc_address(&IsProgramPipeline,         "glIsProgramPipeline");
    set_proc_address(&GetProgramPipelineiv,      "glGetProgramPipelineiv");
    set_proc_address(&ProgramUniform1i,          "glProgramUniform1i");
    set_proc_address(&ProgramUniform1iv,         "glProgramUniform1iv");
    set_proc_address(&ProgramUniform1f,          "glProgramUniform1f");
    set_proc_address(&ProgramUniform1fv,         "glProgramUniform1fv");
    set_proc_address(&ProgramUniform1d,          "glProgramUniform1d");
    set_proc_address(&ProgramUniform1dv,         "glProgramUniform1dv");
    set_proc_address(&ProgramUniform1ui,         "glProgramUniform1ui");
    set_proc_address(&ProgramUniform1uiv,        "glProgramUniform1uiv");
    set_proc_address(&ProgramUniform2i,          "glProgramUniform2i");
    set_proc_address(&ProgramUniform2iv,         "glProgramUniform2iv");
    set_proc_address(&ProgramUniform2f,          "glProgramUniform2f");
    set_proc_address(&ProgramUniform2fv,         "glProgramUniform2fv");
    set_proc_address(&ProgramUniform2d,          "glProgramUniform2d");
    set_proc_address(&ProgramUniform2dv,         "glProgramUniform2dv");
    set_proc_address(&ProgramUniform2ui,         "glProgramUniform2ui");
    set_proc_address(&ProgramUniform2uiv,        "glProgramUniform2uiv");
    set_proc_address(&ProgramUniform3i,          "glProgramUniform3i");
    set_proc_address(&ProgramUniform3iv,         "glProgramUniform3iv");
    set_proc_address(&ProgramUniform3f,          "glProgramUniform3f");
    set_proc_address(&ProgramUniform3fv,         "glProgramUniform3fv");
    set_proc_address(&ProgramUniform3d,          "glProgramUniform3d");
    set_proc_address(&ProgramUniform3dv,         "glProgramUniform3dv");
    set_proc_address(&ProgramUniform3ui,         "glProgramUniform3ui");
    set_proc_address(&ProgramUniform3uiv,        "glProgramUniform3uiv");
    set_proc_address(&ProgramUniform4i,          "glProgramUniform4i");
    set_proc_address(&ProgramUniform4iv,         "glProgramUniform4iv");
    set_proc_address(&ProgramUniform4f,          "glProgramUniform4f");
    set_proc_address(&ProgramUniform4fv,         "glProgramUniform4fv");
    set_proc_address(&ProgramUniform4d,          "glProgramUniform4d");
    set_proc_address(&ProgramUniform4dv,         "glProgramUniform4dv");
    set_proc_address(&ProgramUniform4ui,         "glProgramUniform4ui");
    set_proc_address(&ProgramUniform4uiv,        "glProgramUniform4uiv");
    set_proc_address(&ProgramUniformMatrix2fv,   "glProgramUniformMatrix2fv");
    set_proc_address(&ProgramUniformMatrix3fv,   "glProgramUniformMatrix3fv");
    set_proc_address(&ProgramUniformMatrix4fv,   "glProgramUniformMatrix4fv");
    set_proc_address(&ProgramUniformMatrix2dv,   "glProgramUniformMatrix2dv");
    set_proc_address(&ProgramUniformMatrix3dv,   "glProgramUniformMatrix3dv");
    set_proc_address(&ProgramUniformMatrix4dv,   "glProgramUniformMatrix4dv");
    set_proc_address(&ProgramUniformMatrix2x3fv, "glProgramUniformMatrix2x3fv");
    set_proc_address(&ProgramUniformMatrix3x2fv, "glProgramUniformMatrix3x2fv");
    set_proc_address(&ProgramUniformMatrix2x4fv, "glProgramUniformMatrix2x4fv");
    set_proc_address(&ProgramUniformMatrix4x2fv, "glProgramUniformMatrix4x2fv");
    set_proc_address(&ProgramUniformMatrix3x4fv, "glProgramUniformMatrix3x4fv");
    set_proc_address(&ProgramUniformMatrix4x3fv, "glProgramUniformMatrix4x3fv");
    set_proc_address(&ProgramUniformMatrix2x3dv, "glProgramUniformMatrix2x3dv");
    set_proc_address(&ProgramUniformMatrix3x2dv, "glProgramUniformMatrix3x2dv");
    set_proc_address(&ProgramUniformMatrix2x4dv, "glProgramUniformMatrix2x4dv");
    set_proc_address(&ProgramUniformMatrix4x2dv, "glProgramUniformMatrix4x2dv");
    set_proc_address(&ProgramUniformMatrix3x4dv, "glProgramUniformMatrix3x4dv");
    set_proc_address(&ProgramUniformMatrix4x3dv, "glProgramUniformMatrix4x3dv");
    set_proc_address(&ValidateProgramPipeline,   "glValidateProgramPipeline");
    set_proc_address(&GetProgramPipelineInfoLog, "glGetProgramPipelineInfoLog");
    set_proc_address(&VertexAttribL1d,           "glVertexAttribL1d");
    set_proc_address(&VertexAttribL2d,           "glVertexAttribL2d");
    set_proc_address(&VertexAttribL3d,           "glVertexAttribL3d");
    set_proc_address(&VertexAttribL4d,           "glVertexAttribL4d");
    set_proc_address(&VertexAttribL1dv,          "glVertexAttribL1dv");
    set_proc_address(&VertexAttribL2dv,          "glVertexAttribL2dv");
    set_proc_address(&VertexAttribL3dv,          "glVertexAttribL3dv");
    set_proc_address(&VertexAttribL4dv,          "glVertexAttribL4dv");
    set_proc_address(&VertexAttribLPointer,      "glVertexAttribLPointer");
    set_proc_address(&GetVertexAttribLdv,        "glGetVertexAttribLdv");
    set_proc_address(&ViewportArrayv,            "glViewportArrayv");
    set_proc_address(&ViewportIndexedf,          "glViewportIndexedf");
    set_proc_address(&ViewportIndexedfv,         "glViewportIndexedfv");
    set_proc_address(&ScissorArrayv,             "glScissorArrayv");
    set_proc_address(&ScissorIndexed,            "glScissorIndexed");
    set_proc_address(&ScissorIndexedv,           "glScissorIndexedv");
    set_proc_address(&DepthRangeArrayv,          "glDepthRangeArrayv");
    set_proc_address(&DepthRangeIndexed,         "glDepthRangeIndexed");
    set_proc_address(&GetFloati_v,               "glGetFloati_v");
    set_proc_address(&GetDoublei_v,              "glGetDoublei_v");
}


// VERSION_4_2
DrawArraysInstancedBaseInstance:             proc "c" (mode: u32, first: i32, count: i32, instancecount: i32, baseinstance: u32);
DrawElementsInstancedBaseInstance:           proc "c" (mode: u32, count: i32, type_: u32, indices: rawptr, instancecount: i32, baseinstance: u32);
DrawElementsInstancedBaseVertexBaseInstance: proc "c" (mode: u32, count: i32, type_: u32, indices: rawptr, instancecount: i32, basevertex: i32, baseinstance: u32);
GetInternalformativ:                         proc "c" (target: u32, internalformat: u32, pname: u32, bufSize: i32, params: ^i32);
GetActiveAtomicCounterBufferiv:              proc "c" (program: u32, bufferIndex: u32, pname: u32, params: ^i32);
BindImageTexture:                            proc "c" (unit: u32, texture: u32, level: i32, layered: u8, layer: i32, access: u32, format: u32);
MemoryBarrier:                               proc "c" (barriers: u32);
TexStorage1D:                                proc "c" (target: u32, levels: i32, internalformat: u32, width: i32);
TexStorage2D:                                proc "c" (target: u32, levels: i32, internalformat: u32, width: i32, height: i32);
TexStorage3D:                                proc "c" (target: u32, levels: i32, internalformat: u32, width: i32, height: i32, depth: i32);
DrawTransformFeedbackInstanced:              proc "c" (mode: u32, id: u32, instancecount: i32);
DrawTransformFeedbackStreamInstanced:        proc "c" (mode: u32, id: u32, stream: u32, instancecount: i32);

load_4_2 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&DrawArraysInstancedBaseInstance,             "glDrawArraysInstancedBaseInstance");
    set_proc_address(&DrawElementsInstancedBaseInstance,           "glDrawElementsInstancedBaseInstance");
    set_proc_address(&DrawElementsInstancedBaseVertexBaseInstance, "glDrawElementsInstancedBaseVertexBaseInstance");
    set_proc_address(&GetInternalformativ,                         "glGetInternalformativ");
    set_proc_address(&GetActiveAtomicCounterBufferiv,              "glGetActiveAtomicCounterBufferiv");
    set_proc_address(&BindImageTexture,                            "glBindImageTexture");
    set_proc_address(&MemoryBarrier,                               "glMemoryBarrier");
    set_proc_address(&TexStorage1D,                                "glTexStorage1D");
    set_proc_address(&TexStorage2D,                                "glTexStorage2D");
    set_proc_address(&TexStorage3D,                                "glTexStorage3D");
    set_proc_address(&DrawTransformFeedbackInstanced,              "glDrawTransformFeedbackInstanced");
    set_proc_address(&DrawTransformFeedbackStreamInstanced,        "glDrawTransformFeedbackStreamInstanced");
}

// VERSION_4_3
ClearBufferData:                 proc "c" (target: u32, internalformat: u32, format: u32, type_: u32, data: rawptr);
ClearBufferSubData:              proc "c" (target: u32, internalformat: u32, offset: int, size: int, format: u32, type_: u32, data: rawptr);
DispatchCompute:                 proc "c" (num_groups_x: u32, num_groups_y: u32, num_groups_z: u32);
DispatchComputeIndirect:         proc "c" (indirect: int);
CopyImageSubData:                proc "c" (srcName: u32, srcTarget: u32, srcLevel: i32, srcX: i32, srcY: i32, srcZ: i32, dstName: u32, dstTarget: u32, dstLevel: i32, dstX: i32, dstY: i32, dstZ: i32, srcWidth: i32, srcHeight: i32, srcDepth: i32);
FramebufferParameteri:           proc "c" (target: u32, pname: u32, param: i32);
GetFramebufferParameteriv:       proc "c" (target: u32, pname: u32, params: ^i32);
GetInternalformati64v:           proc "c" (target: u32, internalformat: u32, pname: u32, bufSize: i32, params: ^i64);
InvalidateTexSubImage:           proc "c" (texture: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32);
InvalidateTexImage:              proc "c" (texture: u32, level: i32);
InvalidateBufferSubData:         proc "c" (buffer: u32, offset: int, length: int);
InvalidateBufferData:            proc "c" (buffer: u32);
InvalidateFramebuffer:           proc "c" (target: u32, numAttachments: i32, attachments: ^u32);
InvalidateSubFramebuffer:        proc "c" (target: u32, numAttachments: i32, attachments: ^u32, x: i32, y: i32, width: i32, height: i32);
MultiDrawArraysIndirect:         proc "c" (mode: u32, indirect: rawptr, drawcount: i32, stride: i32);
MultiDrawElementsIndirect:       proc "c" (mode: u32, type_: u32, indirect: rawptr, drawcount: i32, stride: i32);
GetProgramInterfaceiv:           proc "c" (program: u32, programInterface: u32, pname: u32, params: ^i32);
GetProgramResourceIndex:         proc "c" (program: u32, programInterface: u32, name: ^u8) -> u32;
GetProgramResourceName:          proc "c" (program: u32, programInterface: u32, index: u32, bufSize: i32, length: ^i32, name: ^u8);
GetProgramResourceiv:            proc "c" (program: u32, programInterface: u32, index: u32, propCount: i32, props: ^u32, bufSize: i32, length: ^i32, params: ^i32);
GetProgramResourceLocation:      proc "c" (program: u32, programInterface: u32, name: ^u8) -> i32;
GetProgramResourceLocationIndex: proc "c" (program: u32, programInterface: u32, name: ^u8) -> i32;
ShaderStorageBlockBinding:       proc "c" (program: u32, storageBlockIndex: u32, storageBlockBinding: u32);
TexBufferRange:                  proc "c" (target: u32, internalformat: u32, buffer: u32, offset: int, size: int);
TexStorage2DMultisample:         proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32, fixedsamplelocations: u8);
TexStorage3DMultisample:         proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32, depth: i32, fixedsamplelocations: u8);
TextureView:                     proc "c" (texture: u32, target: u32, origtexture: u32, internalformat: u32, minlevel: u32, numlevels: u32, minlayer: u32, numlayers: u32);
BindVertexBuffer:                proc "c" (bindingindex: u32, buffer: u32, offset: int, stride: i32);
VertexAttribFormat:              proc "c" (attribindex: u32, size: i32, type_: u32, normalized: u8, relativeoffset: u32);
VertexAttribIFormat:             proc "c" (attribindex: u32, size: i32, type_: u32, relativeoffset: u32);
VertexAttribLFormat:             proc "c" (attribindex: u32, size: i32, type_: u32, relativeoffset: u32);
VertexAttribBinding:             proc "c" (attribindex: u32, bindingindex: u32);
VertexBindingDivisor:            proc "c" (bindingindex: u32, divisor: u32);
DebugMessageControl:             proc "c" (source: u32, type_: u32, severity: u32, count: i32, ids: ^u32, enabled: u8);
DebugMessageInsert:              proc "c" (source: u32, type_: u32, id: u32, severity: u32, length: i32, buf: ^u8);
DebugMessageCallback:            proc "c" (callback: debug_proc_t, userParam: rawptr);
GetDebugMessageLog:              proc "c" (count: u32, bufSize: i32, sources: ^u32, types: ^u32, ids: ^u32, severities: ^u32, lengths: ^i32, messageLog: ^u8) -> u32;
PushDebugGroup:                  proc "c" (source: u32, id: u32, length: i32, message: ^u8);
PopDebugGroup:                   proc "c" ();
ObjectLabel:                     proc "c" (identifier: u32, name: u32, length: i32, label: ^u8);
GetObjectLabel:                  proc "c" (identifier: u32, name: u32, bufSize: i32, length: ^i32, label: ^u8);
ObjectPtrLabel:                  proc "c" (ptr: rawptr, length: i32, label: ^u8);
GetObjectPtrLabel:               proc "c" (ptr: rawptr, bufSize: i32, length: ^i32, label: ^u8);

load_4_3 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&ClearBufferData,                 "glClearBufferData");
    set_proc_address(&ClearBufferSubData,              "glClearBufferSubData");
    set_proc_address(&DispatchCompute,                 "glDispatchCompute");
    set_proc_address(&DispatchComputeIndirect,         "glDispatchComputeIndirect");
    set_proc_address(&CopyImageSubData,                "glCopyImageSubData");
    set_proc_address(&FramebufferParameteri,           "glFramebufferParameteri");
    set_proc_address(&GetFramebufferParameteriv,       "glGetFramebufferParameteriv");
    set_proc_address(&GetInternalformati64v,           "glGetInternalformati64v");
    set_proc_address(&InvalidateTexSubImage,           "glInvalidateTexSubImage");
    set_proc_address(&InvalidateTexImage,              "glInvalidateTexImage");
    set_proc_address(&InvalidateBufferSubData,         "glInvalidateBufferSubData");
    set_proc_address(&InvalidateBufferData,            "glInvalidateBufferData");
    set_proc_address(&InvalidateFramebuffer,           "glInvalidateFramebuffer");
    set_proc_address(&InvalidateSubFramebuffer,        "glInvalidateSubFramebuffer");
    set_proc_address(&MultiDrawArraysIndirect,         "glMultiDrawArraysIndirect");
    set_proc_address(&MultiDrawElementsIndirect,       "glMultiDrawElementsIndirect");
    set_proc_address(&GetProgramInterfaceiv,           "glGetProgramInterfaceiv");
    set_proc_address(&GetProgramResourceIndex,         "glGetProgramResourceIndex");
    set_proc_address(&GetProgramResourceName,          "glGetProgramResourceName");
    set_proc_address(&GetProgramResourceiv,            "glGetProgramResourceiv");
    set_proc_address(&GetProgramResourceLocation,      "glGetProgramResourceLocation");
    set_proc_address(&GetProgramResourceLocationIndex, "glGetProgramResourceLocationIndex");
    set_proc_address(&ShaderStorageBlockBinding,       "glShaderStorageBlockBinding");
    set_proc_address(&TexBufferRange,                  "glTexBufferRange");
    set_proc_address(&TexStorage2DMultisample,         "glTexStorage2DMultisample");
    set_proc_address(&TexStorage3DMultisample,         "glTexStorage3DMultisample");
    set_proc_address(&TextureView,                     "glTextureView");
    set_proc_address(&BindVertexBuffer,                "glBindVertexBuffer");
    set_proc_address(&VertexAttribFormat,              "glVertexAttribFormat");
    set_proc_address(&VertexAttribIFormat,             "glVertexAttribIFormat");
    set_proc_address(&VertexAttribLFormat,             "glVertexAttribLFormat");
    set_proc_address(&VertexAttribBinding,             "glVertexAttribBinding");
    set_proc_address(&VertexBindingDivisor,            "glVertexBindingDivisor");
    set_proc_address(&DebugMessageControl,             "glDebugMessageControl");
    set_proc_address(&DebugMessageInsert,              "glDebugMessageInsert");
    set_proc_address(&DebugMessageCallback,            "glDebugMessageCallback");
    set_proc_address(&GetDebugMessageLog,              "glGetDebugMessageLog");
    set_proc_address(&PushDebugGroup,                  "glPushDebugGroup");
    set_proc_address(&PopDebugGroup,                   "glPopDebugGroup");
    set_proc_address(&ObjectLabel,                     "glObjectLabel");
    set_proc_address(&GetObjectLabel,                  "glGetObjectLabel");
    set_proc_address(&ObjectPtrLabel,                  "glObjectPtrLabel");
    set_proc_address(&GetObjectPtrLabel,               "glGetObjectPtrLabel");
}

// VERSION_4_4
BufferStorage:     proc "c" (target: u32, size: int, data: rawptr, flags: u32);
ClearTexImage:     proc "c" (texture: u32, level: i32, format: u32, type_: u32, data: rawptr);
ClearTexSubImage:  proc "c" (texture: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32, format: u32, type_: u32, data: rawptr);
BindBuffersBase:   proc "c" (target: u32, first: u32, count: i32, buffers: ^u32);
BindBuffersRange:  proc "c" (target: u32, first: u32, count: i32, buffers: ^u32, offsets: ^int, sizes: ^int);
BindTextures:      proc "c" (first: u32, count: i32, textures: ^u32);
BindSamplers:      proc "c" (first: u32, count: i32, samplers: ^u32);
BindImageTextures: proc "c" (first: u32, count: i32, textures: ^u32);
BindVertexBuffers: proc "c" (first: u32, count: i32, buffers: ^u32, offsets: ^int, strides: ^i32);

load_4_4 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&BufferStorage,     "glBufferStorage");
    set_proc_address(&ClearTexImage,     "glClearTexImage");
    set_proc_address(&ClearTexSubImage,  "glClearTexSubImage");
    set_proc_address(&BindBuffersBase,   "glBindBuffersBase");
    set_proc_address(&BindBuffersRange,  "glBindBuffersRange");
    set_proc_address(&BindTextures,      "glBindTextures");
    set_proc_address(&BindSamplers,      "glBindSamplers");
    set_proc_address(&BindImageTextures, "glBindImageTextures");
    set_proc_address(&BindVertexBuffers, "glBindVertexBuffers");
}

// VERSION_4_5
ClipControl:                              proc "c" (origin: u32, depth: u32);
CreateTransformFeedbacks:                 proc "c" (n: i32, ids: ^u32);
TransformFeedbackBufferBase:              proc "c" (xfb: u32, index: u32, buffer: u32);
TransformFeedbackBufferRange:             proc "c" (xfb: u32, index: u32, buffer: u32, offset: int, size: int);
GetTransformFeedbackiv:                   proc "c" (xfb: u32, pname: u32, param: ^i32);
GetTransformFeedbacki_v:                  proc "c" (xfb: u32, pname: u32, index: u32, param: ^i32);
GetTransformFeedbacki64_v:                proc "c" (xfb: u32, pname: u32, index: u32, param: ^i64);
CreateBuffers:                            proc "c" (n: i32, buffers: ^u32);
NamedBufferStorage:                       proc "c" (buffer: u32, size: int, data: rawptr, flags: u32);
NamedBufferData:                          proc "c" (buffer: u32, size: int, data: rawptr, usage: u32);
NamedBufferSubData:                       proc "c" (buffer: u32, offset: int, size: int, data: rawptr);
CopyNamedBufferSubData:                   proc "c" (readBuffer: u32, writeBuffer: u32, readOffset: int, writeOffset: int, size: int);
ClearNamedBufferData:                     proc "c" (buffer: u32, internalformat: u32, format: u32, type_: u32, data: rawptr);
ClearNamedBufferSubData:                  proc "c" (buffer: u32, internalformat: u32, offset: int, size: int, format: u32, type_: u32, data: rawptr);
MapNamedBuffer:                           proc "c" (buffer: u32, access: u32) -> rawptr;
MapNamedBufferRange:                      proc "c" (buffer: u32, offset: int, length: int, access: u32) -> rawptr;
UnmapNamedBuffer:                         proc "c" (buffer: u32) -> u8;
FlushMappedNamedBufferRange:              proc "c" (buffer: u32, offset: int, length: int);
GetNamedBufferParameteriv:                proc "c" (buffer: u32, pname: u32, params: ^i32);
GetNamedBufferParameteri64v:              proc "c" (buffer: u32, pname: u32, params: ^i64);
GetNamedBufferPointerv:                   proc "c" (buffer: u32, pname: u32, params: ^rawptr);
GetNamedBufferSubData:                    proc "c" (buffer: u32, offset: int, size: int, data: rawptr);
CreateFramebuffers:                       proc "c" (n: i32, framebuffers: ^u32);
NamedFramebufferRenderbuffer:             proc "c" (framebuffer: u32, attachment: u32, renderbuffertarget: u32, renderbuffer: u32);
NamedFramebufferParameteri:               proc "c" (framebuffer: u32, pname: u32, param: i32);
NamedFramebufferTexture:                  proc "c" (framebuffer: u32, attachment: u32, texture: u32, level: i32);
NamedFramebufferTextureLayer:             proc "c" (framebuffer: u32, attachment: u32, texture: u32, level: i32, layer: i32);
NamedFramebufferDrawBuffer:               proc "c" (framebuffer: u32, buf: u32);
NamedFramebufferDrawBuffers:              proc "c" (framebuffer: u32, n: i32, bufs: ^u32);
NamedFramebufferReadBuffer:               proc "c" (framebuffer: u32, src: u32);
InvalidateNamedFramebufferData:           proc "c" (framebuffer: u32, numAttachments: i32, attachments: ^u32);
InvalidateNamedFramebufferSubData:        proc "c" (framebuffer: u32, numAttachments: i32, attachments: ^u32, x: i32, y: i32, width: i32, height: i32);
ClearNamedFramebufferiv:                  proc "c" (framebuffer: u32, buffer: u32, drawbuffer: i32, value: ^i32);
ClearNamedFramebufferuiv:                 proc "c" (framebuffer: u32, buffer: u32, drawbuffer: i32, value: ^u32);
ClearNamedFramebufferfv:                  proc "c" (framebuffer: u32, buffer: u32, drawbuffer: i32, value: ^f32);
ClearNamedFramebufferfi:                  proc "c" (framebuffer: u32, buffer: u32, drawbuffer: i32, depth: f32, stencil: i32);
BlitNamedFramebuffer:                     proc "c" (readFramebuffer: u32, drawFramebuffer: u32, srcX0: i32, srcY0: i32, srcX1: i32, srcY1: i32, dstX0: i32, dstY0: i32, dstX1: i32, dstY1: i32, mask: u32, filter: u32);
CheckNamedFramebufferStatus:              proc "c" (framebuffer: u32, target: u32) -> u32;
GetNamedFramebufferParameteriv:           proc "c" (framebuffer: u32, pname: u32, param: ^i32);
GetNamedFramebufferAttachmentParameteriv: proc "c" (framebuffer: u32, attachment: u32, pname: u32, params: ^i32);
CreateRenderbuffers:                      proc "c" (n: i32, renderbuffers: ^u32);
NamedRenderbufferStorage:                 proc "c" (renderbuffer: u32, internalformat: u32, width: i32, height: i32);
NamedRenderbufferStorageMultisample:      proc "c" (renderbuffer: u32, samples: i32, internalformat: u32, width: i32, height: i32);
GetNamedRenderbufferParameteriv:          proc "c" (renderbuffer: u32, pname: u32, params: ^i32);
CreateTextures:                           proc "c" (target: u32, n: i32, textures: ^u32);
TextureBuffer:                            proc "c" (texture: u32, internalformat: u32, buffer: u32);
TextureBufferRange:                       proc "c" (texture: u32, internalformat: u32, buffer: u32, offset: int, size: int);
TextureStorage1D:                         proc "c" (texture: u32, levels: i32, internalformat: u32, width: i32);
TextureStorage2D:                         proc "c" (texture: u32, levels: i32, internalformat: u32, width: i32, height: i32);
TextureStorage3D:                         proc "c" (texture: u32, levels: i32, internalformat: u32, width: i32, height: i32, depth: i32);
TextureStorage2DMultisample:              proc "c" (texture: u32, samples: i32, internalformat: u32, width: i32, height: i32, fixedsamplelocations: u8);
TextureStorage3DMultisample:              proc "c" (texture: u32, samples: i32, internalformat: u32, width: i32, height: i32, depth: i32, fixedsamplelocations: u8);
TextureSubImage1D:                        proc "c" (texture: u32, level: i32, xoffset: i32, width: i32, format: u32, type_: u32, pixels: rawptr);
TextureSubImage2D:                        proc "c" (texture: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, type_: u32, pixels: rawptr);
TextureSubImage3D:                        proc "c" (texture: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32, format: u32, type_: u32, pixels: rawptr);
CompressedTextureSubImage1D:              proc "c" (texture: u32, level: i32, xoffset: i32, width: i32, format: u32, imageSize: i32, data: rawptr);
CompressedTextureSubImage2D:              proc "c" (texture: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, imageSize: i32, data: rawptr);
CompressedTextureSubImage3D:              proc "c" (texture: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32, format: u32, imageSize: i32, data: rawptr);
CopyTextureSubImage1D:                    proc "c" (texture: u32, level: i32, xoffset: i32, x: i32, y: i32, width: i32);
CopyTextureSubImage2D:                    proc "c" (texture: u32, level: i32, xoffset: i32, yoffset: i32, x: i32, y: i32, width: i32, height: i32);
CopyTextureSubImage3D:                    proc "c" (texture: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, x: i32, y: i32, width: i32, height: i32);
TextureParameterf:                        proc "c" (texture: u32, pname: u32, param: f32);
TextureParameterfv:                       proc "c" (texture: u32, pname: u32, param: ^f32);
TextureParameteri:                        proc "c" (texture: u32, pname: u32, param: i32);
TextureParameterIiv:                      proc "c" (texture: u32, pname: u32, params: ^i32);
TextureParameterIuiv:                     proc "c" (texture: u32, pname: u32, params: ^u32);
TextureParameteriv:                       proc "c" (texture: u32, pname: u32, param: ^i32);
GenerateTextureMipmap:                    proc "c" (texture: u32);
BindTextureUnit:                          proc "c" (unit: u32, texture: u32);
GetTextureImage:                          proc "c" (texture: u32, level: i32, format: u32, type_: u32, bufSize: i32, pixels: rawptr);
GetCompressedTextureImage:                proc "c" (texture: u32, level: i32, bufSize: i32, pixels: rawptr);
GetTextureLevelParameterfv:               proc "c" (texture: u32, level: i32, pname: u32, params: ^f32);
GetTextureLevelParameteriv:               proc "c" (texture: u32, level: i32, pname: u32, params: ^i32);
GetTextureParameterfv:                    proc "c" (texture: u32, pname: u32, params: ^f32);
GetTextureParameterIiv:                   proc "c" (texture: u32, pname: u32, params: ^i32);
GetTextureParameterIuiv:                  proc "c" (texture: u32, pname: u32, params: ^u32);
GetTextureParameteriv:                    proc "c" (texture: u32, pname: u32, params: ^i32);
CreateVertexArrays:                       proc "c" (n: i32, arrays: ^u32);
DisableVertexArrayAttrib:                 proc "c" (vaobj: u32, index: u32);
EnableVertexArrayAttrib:                  proc "c" (vaobj: u32, index: u32);
VertexArrayElementBuffer:                 proc "c" (vaobj: u32, buffer: u32);
VertexArrayVertexBuffer:                  proc "c" (vaobj: u32, bindingindex: u32, buffer: u32, offset: int, stride: i32);
VertexArrayVertexBuffers:                 proc "c" (vaobj: u32, first: u32, count: i32, buffers: ^u32, offsets: ^int, strides: ^i32);
VertexArrayAttribBinding:                 proc "c" (vaobj: u32, attribindex: u32, bindingindex: u32);
VertexArrayAttribFormat:                  proc "c" (vaobj: u32, attribindex: u32, size: i32, type_: u32, normalized: u8, relativeoffset: u32);
VertexArrayAttribIFormat:                 proc "c" (vaobj: u32, attribindex: u32, size: i32, type_: u32, relativeoffset: u32);
VertexArrayAttribLFormat:                 proc "c" (vaobj: u32, attribindex: u32, size: i32, type_: u32, relativeoffset: u32);
VertexArrayBindingDivisor:                proc "c" (vaobj: u32, bindingindex: u32, divisor: u32);
GetVertexArrayiv:                         proc "c" (vaobj: u32, pname: u32, param: ^i32);
GetVertexArrayIndexediv:                  proc "c" (vaobj: u32, index: u32, pname: u32, param: ^i32);
GetVertexArrayIndexed64iv:                proc "c" (vaobj: u32, index: u32, pname: u32, param: ^i64);
CreateSamplers:                           proc "c" (n: i32, samplers: ^u32);
CreateProgramPipelines:                   proc "c" (n: i32, pipelines: ^u32);
CreateQueries:                            proc "c" (target: u32, n: i32, ids: ^u32);
GetQueryBufferObjecti64v:                 proc "c" (id: u32, buffer: u32, pname: u32, offset: int);
GetQueryBufferObjectiv:                   proc "c" (id: u32, buffer: u32, pname: u32, offset: int);
GetQueryBufferObjectui64v:                proc "c" (id: u32, buffer: u32, pname: u32, offset: int);
GetQueryBufferObjectuiv:                  proc "c" (id: u32, buffer: u32, pname: u32, offset: int);
MemoryBarrierByRegion:                    proc "c" (barriers: u32);
GetTextureSubImage:                       proc "c" (texture: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32, format: u32, type_: u32, bufSize: i32, pixels: rawptr);
GetCompressedTextureSubImage:             proc "c" (texture: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32, bufSize: i32, pixels: rawptr);
GetGraphicsResetStatus:                   proc "c" () -> u32;
GetnCompressedTexImage:                   proc "c" (target: u32, lod: i32, bufSize: i32, pixels: rawptr);
GetnTexImage:                             proc "c" (target: u32, level: i32, format: u32, type_: u32, bufSize: i32, pixels: rawptr);
GetnUniformdv:                            proc "c" (program: u32, location: i32, bufSize: i32, params: ^f64);
GetnUniformfv:                            proc "c" (program: u32, location: i32, bufSize: i32, params: ^f32);
GetnUniformiv:                            proc "c" (program: u32, location: i32, bufSize: i32, params: ^i32);
GetnUniformuiv:                           proc "c" (program: u32, location: i32, bufSize: i32, params: ^u32);
ReadnPixels:                              proc "c" (x: i32, y: i32, width: i32, height: i32, format: u32, type_: u32, bufSize: i32, data: rawptr);
GetnMapdv:                                proc "c" (target: u32, query: u32, bufSize: i32, v: ^f64);
GetnMapfv:                                proc "c" (target: u32, query: u32, bufSize: i32, v: ^f32);
GetnMapiv:                                proc "c" (target: u32, query: u32, bufSize: i32, v: ^i32);
GetnPixelMapusv:                          proc "c" (map_: u32, bufSize: i32, values: ^u16);
GetnPixelMapfv:                           proc "c" (map_: u32, bufSize: i32, values: ^f32);
GetnPixelMapuiv:                          proc "c" (map_: u32, bufSize: i32, values: ^u32);
GetnPolygonStipple:                       proc "c" (bufSize: i32, pattern: ^u8);
GetnColorTable:                           proc "c" (target: u32, format: u32, type_: u32, bufSize: i32, table: rawptr);
GetnConvolutionFilter:                    proc "c" (target: u32, format: u32, type_: u32, bufSize: i32, image: rawptr);
GetnSeparableFilter:                      proc "c" (target: u32, format: u32, type_: u32, rowBufSize: i32, row: rawptr, columnBufSize: i32, column: rawptr, span: rawptr);
GetnHistogram:                            proc "c" (target: u32, reset: u8, format: u32, type_: u32, bufSize: i32, values: rawptr);
GetnMinmax:                               proc "c" (target: u32, reset: u8, format: u32, type_: u32, bufSize: i32, values: rawptr);
TextureBarrier:                           proc "c" ();

load_4_5 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&ClipControl,                              "glClipControl");
    set_proc_address(&CreateTransformFeedbacks,                 "glCreateTransformFeedbacks");
    set_proc_address(&TransformFeedbackBufferBase,              "glTransformFeedbackBufferBase");
    set_proc_address(&TransformFeedbackBufferRange,             "glTransformFeedbackBufferRange");
    set_proc_address(&GetTransformFeedbackiv,                   "glGetTransformFeedbackiv");
    set_proc_address(&GetTransformFeedbacki_v,                  "glGetTransformFeedbacki_v");
    set_proc_address(&GetTransformFeedbacki64_v,                "glGetTransformFeedbacki64_v");
    set_proc_address(&CreateBuffers,                            "glCreateBuffers");
    set_proc_address(&NamedBufferStorage,                       "glNamedBufferStorage");
    set_proc_address(&NamedBufferData,                          "glNamedBufferData");
    set_proc_address(&NamedBufferSubData,                       "glNamedBufferSubData");
    set_proc_address(&CopyNamedBufferSubData,                   "glCopyNamedBufferSubData");
    set_proc_address(&ClearNamedBufferData,                     "glClearNamedBufferData");
    set_proc_address(&ClearNamedBufferSubData,                  "glClearNamedBufferSubData");
    set_proc_address(&MapNamedBuffer,                           "glMapNamedBuffer");
    set_proc_address(&MapNamedBufferRange,                      "glMapNamedBufferRange");
    set_proc_address(&UnmapNamedBuffer,                         "glUnmapNamedBuffer");
    set_proc_address(&FlushMappedNamedBufferRange,              "glFlushMappedNamedBufferRange");
    set_proc_address(&GetNamedBufferParameteriv,                "glGetNamedBufferParameteriv");
    set_proc_address(&GetNamedBufferParameteri64v,              "glGetNamedBufferParameteri64v");
    set_proc_address(&GetNamedBufferPointerv,                   "glGetNamedBufferPointerv");
    set_proc_address(&GetNamedBufferSubData,                    "glGetNamedBufferSubData");
    set_proc_address(&CreateFramebuffers,                       "glCreateFramebuffers");
    set_proc_address(&NamedFramebufferRenderbuffer,             "glNamedFramebufferRenderbuffer");
    set_proc_address(&NamedFramebufferParameteri,               "glNamedFramebufferParameteri");
    set_proc_address(&NamedFramebufferTexture,                  "glNamedFramebufferTexture");
    set_proc_address(&NamedFramebufferTextureLayer,             "glNamedFramebufferTextureLayer");
    set_proc_address(&NamedFramebufferDrawBuffer,               "glNamedFramebufferDrawBuffer");
    set_proc_address(&NamedFramebufferDrawBuffers,              "glNamedFramebufferDrawBuffers");
    set_proc_address(&NamedFramebufferReadBuffer,               "glNamedFramebufferReadBuffer");
    set_proc_address(&InvalidateNamedFramebufferData,           "glInvalidateNamedFramebufferData");
    set_proc_address(&InvalidateNamedFramebufferSubData,        "glInvalidateNamedFramebufferSubData");
    set_proc_address(&ClearNamedFramebufferiv,                  "glClearNamedFramebufferiv");
    set_proc_address(&ClearNamedFramebufferuiv,                 "glClearNamedFramebufferuiv");
    set_proc_address(&ClearNamedFramebufferfv,                  "glClearNamedFramebufferfv");
    set_proc_address(&ClearNamedFramebufferfi,                  "glClearNamedFramebufferfi");
    set_proc_address(&BlitNamedFramebuffer,                     "glBlitNamedFramebuffer");
    set_proc_address(&CheckNamedFramebufferStatus,              "glCheckNamedFramebufferStatus");
    set_proc_address(&GetNamedFramebufferParameteriv,           "glGetNamedFramebufferParameteriv");
    set_proc_address(&GetNamedFramebufferAttachmentParameteriv, "glGetNamedFramebufferAttachmentParameteriv");
    set_proc_address(&CreateRenderbuffers,                      "glCreateRenderbuffers");
    set_proc_address(&NamedRenderbufferStorage,                 "glNamedRenderbufferStorage");
    set_proc_address(&NamedRenderbufferStorageMultisample,      "glNamedRenderbufferStorageMultisample");
    set_proc_address(&GetNamedRenderbufferParameteriv,          "glGetNamedRenderbufferParameteriv");
    set_proc_address(&CreateTextures,                           "glCreateTextures");
    set_proc_address(&TextureBuffer,                            "glTextureBuffer");
    set_proc_address(&TextureBufferRange,                       "glTextureBufferRange");
    set_proc_address(&TextureStorage1D,                         "glTextureStorage1D");
    set_proc_address(&TextureStorage2D,                         "glTextureStorage2D");
    set_proc_address(&TextureStorage3D,                         "glTextureStorage3D");
    set_proc_address(&TextureStorage2DMultisample,              "glTextureStorage2DMultisample");
    set_proc_address(&TextureStorage3DMultisample,              "glTextureStorage3DMultisample");
    set_proc_address(&TextureSubImage1D,                        "glTextureSubImage1D");
    set_proc_address(&TextureSubImage2D,                        "glTextureSubImage2D");
    set_proc_address(&TextureSubImage3D,                        "glTextureSubImage3D");
    set_proc_address(&CompressedTextureSubImage1D,              "glCompressedTextureSubImage1D");
    set_proc_address(&CompressedTextureSubImage2D,              "glCompressedTextureSubImage2D");
    set_proc_address(&CompressedTextureSubImage3D,              "glCompressedTextureSubImage3D");
    set_proc_address(&CopyTextureSubImage1D,                    "glCopyTextureSubImage1D");
    set_proc_address(&CopyTextureSubImage2D,                    "glCopyTextureSubImage2D");
    set_proc_address(&CopyTextureSubImage3D,                    "glCopyTextureSubImage3D");
    set_proc_address(&TextureParameterf,                        "glTextureParameterf");
    set_proc_address(&TextureParameterfv,                       "glTextureParameterfv");
    set_proc_address(&TextureParameteri,                        "glTextureParameteri");
    set_proc_address(&TextureParameterIiv,                      "glTextureParameterIiv");
    set_proc_address(&TextureParameterIuiv,                     "glTextureParameterIuiv");
    set_proc_address(&TextureParameteriv,                       "glTextureParameteriv");
    set_proc_address(&GenerateTextureMipmap,                    "glGenerateTextureMipmap");
    set_proc_address(&BindTextureUnit,                          "glBindTextureUnit");
    set_proc_address(&GetTextureImage,                          "glGetTextureImage");
    set_proc_address(&GetCompressedTextureImage,                "glGetCompressedTextureImage");
    set_proc_address(&GetTextureLevelParameterfv,               "glGetTextureLevelParameterfv");
    set_proc_address(&GetTextureLevelParameteriv,               "glGetTextureLevelParameteriv");
    set_proc_address(&GetTextureParameterfv,                    "glGetTextureParameterfv");
    set_proc_address(&GetTextureParameterIiv,                   "glGetTextureParameterIiv");
    set_proc_address(&GetTextureParameterIuiv,                  "glGetTextureParameterIuiv");
    set_proc_address(&GetTextureParameteriv,                    "glGetTextureParameteriv");
    set_proc_address(&CreateVertexArrays,                       "glCreateVertexArrays");
    set_proc_address(&DisableVertexArrayAttrib,                 "glDisableVertexArrayAttrib");
    set_proc_address(&EnableVertexArrayAttrib,                  "glEnableVertexArrayAttrib");
    set_proc_address(&VertexArrayElementBuffer,                 "glVertexArrayElementBuffer");
    set_proc_address(&VertexArrayVertexBuffer,                  "glVertexArrayVertexBuffer");
    set_proc_address(&VertexArrayVertexBuffers,                 "glVertexArrayVertexBuffers");
    set_proc_address(&VertexArrayAttribBinding,                 "glVertexArrayAttribBinding");
    set_proc_address(&VertexArrayAttribFormat,                  "glVertexArrayAttribFormat");
    set_proc_address(&VertexArrayAttribIFormat,                 "glVertexArrayAttribIFormat");
    set_proc_address(&VertexArrayAttribLFormat,                 "glVertexArrayAttribLFormat");
    set_proc_address(&VertexArrayBindingDivisor,                "glVertexArrayBindingDivisor");
    set_proc_address(&GetVertexArrayiv,                         "glGetVertexArrayiv");
    set_proc_address(&GetVertexArrayIndexediv,                  "glGetVertexArrayIndexediv");
    set_proc_address(&GetVertexArrayIndexed64iv,                "glGetVertexArrayIndexed64iv");
    set_proc_address(&CreateSamplers,                           "glCreateSamplers");
    set_proc_address(&CreateProgramPipelines,                   "glCreateProgramPipelines");
    set_proc_address(&CreateQueries,                            "glCreateQueries");
    set_proc_address(&GetQueryBufferObjecti64v,                 "glGetQueryBufferObjecti64v");
    set_proc_address(&GetQueryBufferObjectiv,                   "glGetQueryBufferObjectiv");
    set_proc_address(&GetQueryBufferObjectui64v,                "glGetQueryBufferObjectui64v");
    set_proc_address(&GetQueryBufferObjectuiv,                  "glGetQueryBufferObjectuiv");
    set_proc_address(&MemoryBarrierByRegion,                    "glMemoryBarrierByRegion");
    set_proc_address(&GetTextureSubImage,                       "glGetTextureSubImage");
    set_proc_address(&GetCompressedTextureSubImage,             "glGetCompressedTextureSubImage");
    set_proc_address(&GetGraphicsResetStatus,                   "glGetGraphicsResetStatus");
    set_proc_address(&GetnCompressedTexImage,                   "glGetnCompressedTexImage");
    set_proc_address(&GetnTexImage,                             "glGetnTexImage");
    set_proc_address(&GetnUniformdv,                            "glGetnUniformdv");
    set_proc_address(&GetnUniformfv,                            "glGetnUniformfv");
    set_proc_address(&GetnUniformiv,                            "glGetnUniformiv");
    set_proc_address(&GetnUniformuiv,                           "glGetnUniformuiv");
    set_proc_address(&ReadnPixels,                              "glReadnPixels");
    set_proc_address(&GetnMapdv,                                "glGetnMapdv");
    set_proc_address(&GetnMapfv,                                "glGetnMapfv");
    set_proc_address(&GetnMapiv,                                "glGetnMapiv");
    set_proc_address(&GetnPixelMapfv,                           "glGetnPixelMapfv");
    set_proc_address(&GetnPixelMapuiv,                          "glGetnPixelMapuiv");
    set_proc_address(&GetnPixelMapusv,                          "glGetnPixelMapusv");
    set_proc_address(&GetnPolygonStipple,                       "glGetnPolygonStipple");
    set_proc_address(&GetnColorTable,                           "glGetnColorTable");
    set_proc_address(&GetnConvolutionFilter,                    "glGetnConvolutionFilter");
    set_proc_address(&GetnSeparableFilter,                      "glGetnSeparableFilter");
    set_proc_address(&GetnHistogram,                            "glGetnHistogram");
    set_proc_address(&GetnMinmax,                               "glGetnMinmax");
    set_proc_address(&TextureBarrier,                           "glTextureBarrier");
}


// VERSION_4_6

SpecializeShader:               proc "c" (shader: u32, pEntryPoint: ^u8, numSpecializationConstants: u32, pConstantIndex: ^u32, pConstantValue: ^u32);
MultiDrawArraysIndirectCount:   proc "c" (mode: i32, indirect: rawptr, drawcount: int, maxdrawcount, stride: i32);
MultiDrawElementsIndirectCount: proc "c" (mode: i32, type_: i32, indirect: rawptr, drawcount: int, maxdrawcount, stride: i32);
PolygonOffsetClamp:             proc "c" (factor, units, clamp: f32);

load_4_6 :: proc(set_proc_address: Set_Proc_Address_Type) {
    set_proc_address(&SpecializeShader,               "glSpecializeShader");
    set_proc_address(&MultiDrawArraysIndirectCount,   "glMultiDrawArraysIndirectCount");
    set_proc_address(&MultiDrawElementsIndirectCount, "glMultiDrawElementsIndirectCount");
    set_proc_address(&PolygonOffsetClamp,             "glPolygonOffsetClamp");
}

init :: proc(set_proc_address: Set_Proc_Address_Type) {
    // Placeholder for loading maximum supported version
}


// Helper for loading shaders into a program

Shader_Type :: enum i32 {
    FRAGMENT_SHADER        = 0x8B30,
    VERTEX_SHADER          = 0x8B31,
    GEOMETRY_SHADER        = 0x8DD9,
    COMPUTE_SHADER         = 0x91B9,
    TESS_EVALUATION_SHADER = 0x8E87,
    TESS_CONTROL_SHADER    = 0x8E88,
    SHADER_LINK            = 0x0000, // @Note: Not an OpenGL constant, but used for error checking.
}


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
        defer delete(error_message);

        log_func(id, i32(info_log_length), nil, &error_message[0]);
        fmt.eprintf("Error in %v:\n%s", type_, string(error_message[0:len(error_message)-1]));

        return true;
    }

    return false;
}

// Compiling shaders are identical for any shader (vertex, geometry, fragment, tesselation, (maybe compute too))
compile_shader_from_source :: proc(shader_data: string, shader_type: Shader_Type) -> (u32, bool) {
    shader_id := CreateShader(cast(u32)shader_type);
    length := i32(len(shader_data));
    src := cast(^u8)basic.TEMP_CSTRING(shader_data);
    ShaderSource(shader_id, 1, &src, &length);
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

load_compute_file :: proc(filename: string) -> (u32, bool) {
    cs_data, success_cs := os.read_entire_file(filename);
    if !success_cs do return 0, false;
    defer delete(cs_data);

    // Create the shaders
    compute_shader_id, ok1 := compile_shader_from_source(string(cs_data), Shader_Type.COMPUTE_SHADER);

    if !ok1 {
        return 0, false;
    }

    program_id, ok2 := create_and_link_program([]u32{compute_shader_id});
    if !ok2 {
        return 0, false;
    }

    return program_id, true;
}

load_shaders_file :: proc(vs_filename, fs_filename: string) -> (u32, bool) {
    vs_data, success_vs := os.read_entire_file(vs_filename);
    if !success_vs do return 0, false;
    defer delete(vs_data);
    fs_data, success_fs := os.read_entire_file(fs_filename);
    if !success_fs do return 0, false;
    defer delete(fs_data);


    return load_shaders_source(string(vs_data), string(fs_data));

}

load_shaders_source :: proc(vs_source, fs_source: string) -> (u32, bool) {


    // actual function from here
    vertex_shader_id, ok1 := compile_shader_from_source(vs_source, Shader_Type.VERTEX_SHADER);
    defer DeleteShader(vertex_shader_id);

    fragment_shader_id, ok2 := compile_shader_from_source(fs_source, Shader_Type.FRAGMENT_SHADER);
    defer DeleteShader(fragment_shader_id);

    if !ok1 || !ok2 {
        return 0, false;
    }

    program_id, ok := create_and_link_program([]u32{vertex_shader_id, fragment_shader_id});
    if !ok {
        return 0, false;
    }

    return program_id, true;
}

load_shaders :: load_shaders_file;


when os.OS == "windows" {
    update_shader_if_changed :: proc(vertex_name, fragment_name: string, _program: u32, last_vertex_time, last_fragment_time: os.File_Time) -> (u32, os.File_Time, os.File_Time, bool) {
        program := _program;
        current_vertex_time, errno := os.last_write_time_by_name(vertex_name); assert(errno == os.ERROR_NONE);
        current_fragment_time, errno2 := os.last_write_time_by_name(fragment_name); assert(errno2 == os.ERROR_NONE);

        updated := false;
        if current_vertex_time != last_vertex_time || current_fragment_time != last_fragment_time {
            new_program, success := load_shaders(vertex_name, fragment_name);
            if success {
                DeleteProgram(program);
                program = new_program;
                fmt.println("Updated shaders");
                updated = true;
            } else {
                fmt.println("Failed to update shaders");
            }
        }

        return program, current_vertex_time, current_fragment_time, updated;
    }
}



Uniform_Type :: enum i32 {
    FLOAT      = 0x1406,
    FLOAT_VEC2 = 0x8B50,
    FLOAT_VEC3 = 0x8B51,
    FLOAT_VEC4 = 0x8B52,

    DOUBLE      = 0x140A,
    DOUBLE_VEC2 = 0x8FFC,
    DOUBLE_VEC3 = 0x8FFD,
    DOUBLE_VEC4 = 0x8FFE,

    INT      = 0x1404,
    INT_VEC2 = 0x8B53,
    INT_VEC3 = 0x8B54,
    INT_VEC4 = 0x8B55,

    UNSIGNED_INT      = 0x1405,
    UNSIGNED_INT_VEC2 = 0x8DC6,
    UNSIGNED_INT_VEC3 = 0x8DC7,
    UNSIGNED_INT_VEC4 = 0x8DC8,

    BOOL      = 0x8B56,
    BOOL_VEC2 = 0x8B57,
    BOOL_VEC3 = 0x8B58,
    BOOL_VEC4 = 0x8B59,

    FLOAT_MAT2   = 0x8B5A,
    FLOAT_MAT3   = 0x8B5B,
    FLOAT_MAT4   = 0x8B5C,
    FLOAT_MAT2x3 = 0x8B65,
    FLOAT_MAT2x4 = 0x8B66,
    FLOAT_MAT3x2 = 0x8B67,
    FLOAT_MAT3x4 = 0x8B68,
    FLOAT_MAT4x2 = 0x8B69,
    FLOAT_MAT4x3 = 0x8B6A,

    DOUBLE_MAT2   = 0x8F46,
    DOUBLE_MAT3   = 0x8F47,
    DOUBLE_MAT4   = 0x8F48,
    DOUBLE_MAT2x3 = 0x8F49,
    DOUBLE_MAT2x4 = 0x8F4A,
    DOUBLE_MAT3x2 = 0x8F4B,
    DOUBLE_MAT3x4 = 0x8F4C,
    DOUBLE_MAT4x2 = 0x8F4D,
    DOUBLE_MAT4x3 = 0x8F4E,

    SAMPLER_1D                   = 0x8B5D,
    SAMPLER_2D                   = 0x8B5E,
    SAMPLER_3D                   = 0x8B5F,
    SAMPLER_CUBE                 = 0x8B60,
    SAMPLER_1D_SHADOW            = 0x8B61,
    SAMPLER_2D_SHADOW            = 0x8B62,
    SAMPLER_1D_ARRAY             = 0x8DC0,
    SAMPLER_2D_ARRAY             = 0x8DC1,
    SAMPLER_1D_ARRAY_SHADOW      = 0x8DC3,
    SAMPLER_2D_ARRAY_SHADOW      = 0x8DC4,
    SAMPLER_2D_MULTISAMPLE       = 0x9108,
    SAMPLER_2D_MULTISAMPLE_ARRAY = 0x910B,
    SAMPLER_CUBE_SHADOW          = 0x8DC5,
    SAMPLER_BUFFER               = 0x8DC2,
    SAMPLER_2D_RECT              = 0x8B63,
    SAMPLER_2D_RECT_SHADOW       = 0x8B64,

    INT_SAMPLER_1D                   = 0x8DC9,
    INT_SAMPLER_2D                   = 0x8DCA,
    INT_SAMPLER_3D                   = 0x8DCB,
    INT_SAMPLER_CUBE                 = 0x8DCC,
    INT_SAMPLER_1D_ARRAY             = 0x8DCE,
    INT_SAMPLER_2D_ARRAY             = 0x8DCF,
    INT_SAMPLER_2D_MULTISAMPLE       = 0x9109,
    INT_SAMPLER_2D_MULTISAMPLE_ARRAY = 0x910C,
    INT_SAMPLER_BUFFER               = 0x8DD0,
    INT_SAMPLER_2D_RECT              = 0x8DCD,

    UNSIGNED_INT_SAMPLER_1D                   = 0x8DD1,
    UNSIGNED_INT_SAMPLER_2D                   = 0x8DD2,
    UNSIGNED_INT_SAMPLER_3D                   = 0x8DD3,
    UNSIGNED_INT_SAMPLER_CUBE                 = 0x8DD4,
    UNSIGNED_INT_SAMPLER_1D_ARRAY             = 0x8DD6,
    UNSIGNED_INT_SAMPLER_2D_ARRAY             = 0x8DD7,
    UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE       = 0x910A,
    UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY = 0x910D,
    UNSIGNED_INT_SAMPLER_BUFFER               = 0x8DD8,
    UNSIGNED_INT_SAMPLER_2D_RECT              = 0x8DD5,

    IMAGE_1D                   = 0x904C,
    IMAGE_2D                   = 0x904D,
    IMAGE_3D                   = 0x904E,
    IMAGE_2D_RECT              = 0x904F,
    IMAGE_CUBE                 = 0x9050,
    IMAGE_BUFFER               = 0x9051,
    IMAGE_1D_ARRAY             = 0x9052,
    IMAGE_2D_ARRAY             = 0x9053,
    IMAGE_CUBE_MAP_ARRAY       = 0x9054,
    IMAGE_2D_MULTISAMPLE       = 0x9055,
    IMAGE_2D_MULTISAMPLE_ARRAY = 0x9056,

    INT_IMAGE_1D                   = 0x9057,
    INT_IMAGE_2D                   = 0x9058,
    INT_IMAGE_3D                   = 0x9059,
    INT_IMAGE_2D_RECT              = 0x905A,
    INT_IMAGE_CUBE                 = 0x905B,
    INT_IMAGE_BUFFER               = 0x905C,
    INT_IMAGE_1D_ARRAY             = 0x905D,
    INT_IMAGE_2D_ARRAY             = 0x905E,
    INT_IMAGE_CUBE_MAP_ARRAY       = 0x905F,
    INT_IMAGE_2D_MULTISAMPLE       = 0x9060,
    INT_IMAGE_2D_MULTISAMPLE_ARRAY = 0x9061,

    UNSIGNED_INT_IMAGE_1D                   = 0x9062,
    UNSIGNED_INT_IMAGE_2D                   = 0x9063,
    UNSIGNED_INT_IMAGE_3D                   = 0x9064,
    UNSIGNED_INT_IMAGE_2D_RECT              = 0x9065,
    UNSIGNED_INT_IMAGE_CUBE                 = 0x9066,
    UNSIGNED_INT_IMAGE_BUFFER               = 0x9067,
    UNSIGNED_INT_IMAGE_1D_ARRAY             = 0x9068,
    UNSIGNED_INT_IMAGE_2D_ARRAY             = 0x9069,
    UNSIGNED_INT_IMAGE_CUBE_MAP_ARRAY       = 0x906A,
    UNSIGNED_INT_IMAGE_2D_MULTISAMPLE       = 0x906B,
    UNSIGNED_INT_IMAGE_2D_MULTISAMPLE_ARRAY = 0x906C,

    UNSIGNED_INT_ATOMIC_COUNTER = 0x92DB,
}

Uniform_Info :: struct {
    location: i32,
    size:     i32,
    kind:     Uniform_Type,
    name:     string, // NOTE: This will need to be freed
}

Uniforms :: map[string]Uniform_Info;

destroy_uniforms :: proc(u: Uniforms) {
    for _, v in u {
        delete(v.name);
    }
    delete(u);
}

get_uniforms_from_program :: proc(program: u32) -> (uniforms: Uniforms) {
    uniform_count: i32;
    GetProgramiv(program, ACTIVE_UNIFORMS, &uniform_count);

    if uniform_count > 0 do reserve(&uniforms, int(uniform_count));

    for i in 0..uniform_count-1 {
        using uniform_info: Uniform_Info;

        length: i32;
        cname: [256]u8;
        GetActiveUniform(program, u32(i), 256, &length, &size, cast(^u32)&kind, &cname[0]);

        location = GetUniformLocation(program, &cname[0]);
        name = strings.clone(string(cname[:length])); // @NOTE: These need to be freed
        uniforms[name] = uniform_info;
    }

    return uniforms;
}

get_uniform_location :: proc(program: u32, name: cstring) -> i32 {
    return GetUniformLocation(program, cast(^u8)name);
}