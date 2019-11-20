package workbench

using import "math"
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
point_light_colors:      [MAX_LIGHTS]Vec4;
point_light_intensities: [MAX_LIGHTS]f32;
num_point_lights: i32;

directional_light_directions:  [MAX_LIGHTS]Vec3;
directional_light_colors:      [MAX_LIGHTS]Vec4;
directional_light_intensities: [MAX_LIGHTS]f32;
directional_light_rotations:   [MAX_LIGHTS]Quat;
// directional_light_cameras:     [MAX_LIGHTS]Camera;
num_directional_lights: i32;

SHADOW_MAP_DIM :: 128;
shadow_camera_pool: [dynamic]Camera;
unpooled_shadow_cameras: [dynamic]Camera;

push_point_light :: proc(position: Vec3, color: Colorf, intensity: f32) {
	if num_point_lights >= MAX_LIGHTS {
		logln("Too many lights! The max is ", MAX_LIGHTS);
		return;
	}

	point_light_positions  [num_point_lights] = position;
	point_light_colors     [num_point_lights] = transmute(Vec4)color;
	point_light_intensities[num_point_lights] = intensity;
	num_point_lights += 1;
}

push_directional_light :: proc(position: Vec3, rotation: Quat, color: Colorf, intensity: f32) {
	if num_directional_lights >= MAX_LIGHTS {
		logln("Too many lights! The max is ", MAX_LIGHTS);
		return;
	}

	directional_light_directions [num_directional_lights] = quaternion_forward(rotation);
	directional_light_colors     [num_directional_lights] = transmute(Vec4)color;
	directional_light_intensities[num_directional_lights] = intensity;
	directional_light_rotations  [num_directional_lights] = rotation;
	num_directional_lights += 1;
}

flush_lights_to_shader :: proc(program: gpu.Shader_Program) {
	if num_point_lights > 0 {
		gpu.uniform_vec3_array(program,  "point_light_positions",   point_light_positions[:num_point_lights]);
		gpu.uniform_vec4_array(program,  "point_light_colors",      point_light_colors[:num_point_lights]);
		gpu.uniform_float_array(program, "point_light_intensities", point_light_intensities[:num_point_lights]);
	}
	gpu.uniform_int(program, "num_point_lights", num_point_lights);

	if num_directional_lights > 0 {
		gpu.uniform_vec3_array(program,  "directional_light_directions",  directional_light_directions[:num_directional_lights]);
		gpu.uniform_vec4_array(program,  "directional_light_colors",      directional_light_colors[:num_directional_lights]);
		gpu.uniform_float_array(program, "directional_light_intensities", directional_light_intensities[:num_directional_lights]);
	}
	gpu.uniform_int(program, "num_directional_lights", num_directional_lights);
}

set_current_material :: proc(program: gpu.Shader_Program, material: Material) {
	gpu.uniform_vec4 (program, "material.ambient",  transmute(Vec4)material.ambient);
	gpu.uniform_vec4 (program, "material.diffuse",  transmute(Vec4)material.diffuse);
	gpu.uniform_vec4 (program, "material.specular", transmute(Vec4)material.specular);
	gpu.uniform_float(program, "material.shine",    material.shine);
}

clear_lights :: proc() {
	num_point_lights = 0;

	// flush shadow cameras back to pool
	for c in unpooled_shadow_cameras {
		append(&shadow_camera_pool, c);
	}
	clear(&unpooled_shadow_cameras);
	// for idx in 0..<num_directional_lights {
	// 	append(&shadow_camera_pool, directional_light_cameras[idx]);
	// }
	num_directional_lights = 0;
}

get_directional_light_camera :: proc() -> ^Camera {
	camera: Camera;
	if len(shadow_camera_pool) == 0 {
		init_camera(&camera, false, 10, SHADOW_MAP_DIM, SHADOW_MAP_DIM, create_depth_framebuffer(SHADOW_MAP_DIM, SHADOW_MAP_DIM));
		// camera.position = Vec3{0, 5, 0};
		// camera.rotation = rotate_quat_by_degrees({0, 0, 0, 1}, Vec3{-45, -45, 0});
		camera.near_plane = 0.01;
		camera.far_plane = 50;
	}
	else {
		camera = pop(&shadow_camera_pool);
	}
	append(&unpooled_shadow_cameras, camera);
	return &unpooled_shadow_cameras[len(unpooled_shadow_cameras)-1];
}
