package cube

using import "core:fmt"
      import "core:mem"
      import "core:os"

      import wb    "shared:workbench"
      import       "shared:workbench/platform"
      import       "shared:workbench/wbml"
using import       "shared:workbench/math"

using import "shared:workbench/logging"
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

	light_color: Colorf,
	light_intensity: f32,

	default_material: wb.Material,
}

main_init :: proc() {
	// load cube model
	cube_model = wb.create_cube_model();

	// load config
	{
		config_data, ok := os.read_entire_file("config.wbml");
		defer delete(config_data);

		// set defaults
		config = Config {
			cube_color = {1, 0.8, 0, 1},
			ground_color = {0.035, 1, 0, 1},

			sun_angles = Vec3{-60, -60, 0},
			sun_color = Colorf{1, 1, 1, 1},
			sun_intensity = 1,

			light_color = Colorf{1, 0, 1, 1},
			light_intensity = 100,

			default_material = wb.Material{{1, 1, 1, 1}, {1, 1, 1, 1}, {1, 1, 1, 1}, 8},
		};

		// apply file data overtop of defaults
		wbml.deserialize(config_data, &config);
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
	wb.set_sun_data(degrees_to_quaternion(config.sun_angles), config.sun_color, config.sun_intensity);

	light_position := Vec3{sin(wb.time) * 3, 2, cos(wb.time) * 3};
	wb.push_point_light(light_position, config.light_color, config.light_intensity);
	wb.submit_model(cube_model, wb.get_shader(&wb.wb_catalog, "lit"), {}, config.default_material, light_position, {.5, .5, .5}, Quat{0, 0, 0, 1}, config.light_color, {});

	// draw rotating cube
	wb.submit_model(cube_model, wb.get_shader(&wb.wb_catalog, "lit"), {}, config.default_material, Vec3{}, {1, 1, 1}, cube_rotation, config.cube_color, {});

	// draw ground
	wb.submit_model(cube_model, wb.get_shader(&wb.wb_catalog, "lit"), {}, config.default_material, Vec3{0, -2, 0}, {10, 1, 10}, Quat{0, 0, 0, 1}, config.ground_color, {});
}

main_end :: proc() {
	wb.delete_model(cube_model);

	// serialize config
	config_data := wbml.serialize(&config);
	defer delete(config_data);
	os.write_entire_file("config.wbml", cast([]u8)config_data);
}
