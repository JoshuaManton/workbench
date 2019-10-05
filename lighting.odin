package workbench

using import "core:math"

using import "basic"
using import "types"
using import "logging"

      import "gpu"

Material :: struct {
	ambient:  Colorf,
	diffuse:  Colorf,
	specular: Colorf,
	shine:    f32,
}

MAX_LIGHTS :: 100;
point_light_positions:   [MAX_LIGHTS]Vec3;
point_light_colors:      [MAX_LIGHTS]Colorf;
point_light_intensities: [MAX_LIGHTS]f32;
num_point_lights: i32;

directional_light_directions:  [MAX_LIGHTS]Vec3;
directional_light_colors:      [MAX_LIGHTS]Colorf;
directional_light_intensities: [MAX_LIGHTS]f32;
num_directional_lights: i32;

push_point_light :: proc(position: Vec3, color: Colorf, intensity: f32) {
	if num_point_lights >= MAX_LIGHTS {
		logln("Too many lights! The max is ", MAX_LIGHTS);
		return;
	}

	point_light_positions  [num_point_lights] = position;
	point_light_colors     [num_point_lights] = color;
	point_light_intensities[num_point_lights] = intensity;
	num_point_lights += 1;
}

push_directional_light :: proc(direction: Vec3, color: Colorf, intensity: f32) {
	if num_directional_lights >= MAX_LIGHTS {
		logln("Too many lights! The max is ", MAX_LIGHTS);
		return;
	}

	directional_light_directions [num_directional_lights] = direction;
	directional_light_colors     [num_directional_lights] = color;
	directional_light_intensities[num_directional_lights] = intensity;
	num_directional_lights += 1;
}

flush_lights_to_shader :: proc(program: gpu.Shader_Program) {
	if num_point_lights > 0 {
		gpu.uniform3fv(program, "point_light_positions",   num_point_lights, &point_light_positions[0].x);
		gpu.uniform4fv(program, "point_light_colors",      num_point_lights, &point_light_colors[0].r);
		gpu.uniform1fv(program, "point_light_intensities", num_point_lights, &point_light_intensities[0]);
		gpu.uniform1i (program, "num_point_lights",        num_point_lights);
	}

	if num_directional_lights > 0 {
		gpu.uniform3fv(program, "directional_light_directions",  num_directional_lights, &directional_light_directions[0].x);
		gpu.uniform4fv(program, "directional_light_colors",      num_directional_lights, &directional_light_colors[0].r);
		gpu.uniform1fv(program, "directional_light_intensities", num_directional_lights, &directional_light_intensities[0]);
		gpu.uniform1i (program, "num_directional_lights",        num_directional_lights);
	}
}

set_current_material :: proc(program: gpu.Shader_Program, material: Material) {
	gpu.uniform_vec4 (program, "material.ambient",  transmute(Vec4)material.ambient);
	gpu.uniform_vec4 (program, "material.diffuse",  transmute(Vec4)material.diffuse);
	gpu.uniform_vec4 (program, "material.specular", transmute(Vec4)material.specular);
	gpu.uniform_float(program, "material.shine",    material.shine);
}

clear_lights :: proc() {
	num_point_lights = 0;
	num_directional_lights = 0;
}



Shadow_Map :: struct {
	fbo: gpu.FBO,
}

SHADOW_DIM :: 1024;

make_shadow_map :: proc() -> Shadow_Map {
	depth_map := gpu.gen_texture();
	gpu.bind_texture2d(depth_map);
	gpu.tex_image2d(.Texture2D, 0, .Depth_Component, SHADOW_DIM, SHADOW_DIM, 0, .Depth_Component, .Float, nil);
	gpu.tex_parameteri(.Texture2D, .Mag_Filter, .Nearest);
	gpu.tex_parameteri(.Texture2D, .Min_Filter, .Nearest);
	gpu.tex_parameteri(.Texture2D, .Wrap_S, .Repeat);
	gpu.tex_parameteri(.Texture2D, .Wrap_T, .Repeat);

	fbo := gpu.gen_framebuffer();
	gpu.bind_fbo(fbo);
	gpu.framebuffer_texture2d(.Depth, depth_map);
	gpu.draw_buffer(0);
	gpu.read_buffer(0);
	gpu.assert_framebuffer_complete();

	gpu.bind_fbo(0);
	gpu.bind_texture2d(0);

	sm := Shadow_Map{fbo};
	return sm;
}

shadow_prerender :: proc(sm: Shadow_Map) {
	gpu.viewport(0, 0, SHADOW_DIM, SHADOW_DIM);
	gpu.bind_fbo(sm.fbo);
	gpu.clear_screen(.Depth_Buffer);
}