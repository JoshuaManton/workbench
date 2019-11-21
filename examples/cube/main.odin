package main

using import "core:fmt"
      import "core:mem"
      import "core:os"

      import wb    "shared:workbench"
      import       "shared:workbench/platform"
      import       "shared:workbench/wbml"
using import       "shared:workbench/math"
      import imgui "shared:workbench/external/imgui"

using import "shared:workbench/logging"
using import "shared:workbench/basic"
using import "shared:workbench/types"

main :: proc() {
	wb.make_simple_window(
		1280, 720,
		60,
		wb.Workspace{"cube", main_init, main_update, main_render, main_end});
}



cube_model: wb.Model;
cube_rotation := Quat{0, 0, 0, 1};
config: Config;

Config :: struct {
	cube_color: Colorf,
	ground_color: Colorf,

	sun_angles: Vec3,
	sun_color: Colorf,
	sun_intensity: f32,
}

main_init :: proc() {
	// load cube model
	cube_model = wb.create_cube_model();

	// load config
	{
		config_data, ok := os.read_entire_file("config.wbml");
		if !ok {
			config = Config {
				cube_color = {1, 0, 0, 1},
				ground_color = {0, 1, 0, 1},

				sun_angles = Vec3{-60, -90, 0},
				sun_color = Colorf{1, 1, 1, 1},
				sun_intensity = 100,
			};
		}
		else {
			wbml.deserialize(config_data, &config);
		}
	}

	// setup camera
	wb.wb_camera.position = Vec3{0, 4, 8};
	wb.wb_camera.rotation = degrees_to_quaternion(Vec3{-30, 0, 0});
	wb.wb_camera.is_perspective = true;
	wb.wb_camera.size = 75;
	wb.wb_camera.clear_color = {.05, .1, .6, 1};
}

main_update :: proc(dt: f32) {
	if platform.get_input_down(.Escape) do wb.exit();

	if platform.get_input(.Mouse_Right) {
		// handle WASD and mouse movement
		wb.do_camera_movement(&wb.wb_camera, dt, 5, 20, 1);
	}

	cube_rotation = quat_mul(cube_rotation, euler_angles(0 * dt, 1 * dt, 2 * dt));

	wb.imgui_struct(&config, "Config");
}

main_render :: proc(dt: f32) {
	wb.set_sun_data(Vec3{0, 10, 0}, degrees_to_quaternion(config.sun_angles), config.sun_color, config.sun_intensity);

	material := wb.Material{{.2, .2, .2, 1}, {.2, .2, .2, 1}, {1, 1, 1, 1}, 64};

	light_position := Vec3{sin(wb.time) * 3, 2, cos(wb.time) * 3};
	light_color := Colorf{50, .25, 0, 1};
	wb.push_point_light(light_position, light_color, 10);
	wb.submit_model(cube_model, wb.get_shader(&wb.wb_catalog, "lit"), {}, material, light_position, {.5, .5, .5}, Quat{0, 0, 0, 1}, light_color, {});


	// draw rotating cube
	wb.submit_model(cube_model, wb.get_shader(&wb.wb_catalog, "lit"), {}, material, Vec3{}, {1, 1, 1}, cube_rotation, config.cube_color, {});

	// draw ground
	wb.submit_model(cube_model, wb.get_shader(&wb.wb_catalog, "lit"), {}, material, Vec3{0, -2, 0}, {10, 1, 10}, Quat{0, 0, 0, 1}, config.ground_color, {});
}

main_end :: proc() {
	wb.delete_model(cube_model);

	// serialize config
	config_data := wbml.serialize(&config);
	os.write_entire_file("config.wbml", cast([]u8)config_data);
}
