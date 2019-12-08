package cube

      import wb    "shared:workbench"
      import       "shared:workbench/platform"
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

main_init :: proc() {
	// load cube model
	cube_model = wb.create_cube_model();

	// setup camera
	wb.wb_camera.position = Vec3{0, 4, 8};
	wb.wb_camera.rotation = degrees_to_quaternion(Vec3{-30, 0, 0});
	wb.wb_camera.is_perspective = true;
	wb.wb_camera.size = 75;
	wb.wb_camera.clear_color = {.05, .1, .6, 1};
}

main_update :: proc(dt: f32) {
	if platform.get_input_down(.Escape) do wb.exit();

	cube_rotation = quat_mul(cube_rotation, euler_angles(0 * dt, 1 * dt, 1.5 * dt));
}

main_render :: proc(dt: f32) {
	wb.set_sun_data(degrees_to_quaternion(Vec3{-60, -60, 0}), Colorf{1, 1, 1, 1}, 1);

	default_material := wb.Material{{1, 1, 1, 1}, {1, 1, 1, 1}, {1, 1, 1, 1}, 8};

	// draw ground
	wb.submit_model(cube_model, wb.get_shader(&wb.wb_catalog, "lit"), {}, default_material, Vec3{0, -2, 0}, {10, 1, 10}, Quat{0, 0, 0, 1}, Colorf{0.035, 1, 0, 1}, {});

	// draw rotating cube
	wb.submit_model(cube_model, wb.get_shader(&wb.wb_catalog, "lit"), {}, default_material, Vec3{}, {1, 1, 1}, cube_rotation, Colorf{1, 0.8, 0, 1}, {});

	// draw light
	light_position := Vec3{sin(wb.time) * 3, 2, cos(wb.time) * 3};
	light_color := Colorf{1, 0, 1, 1};
	wb.push_point_light(light_position, light_color, 100);
	wb.submit_model(cube_model, wb.get_shader(&wb.wb_catalog, "lit"), {}, default_material, light_position, {.5, .5, .5}, Quat{0, 0, 0, 1}, light_color, {});
}

main_end :: proc() {
	wb.delete_model(cube_model);
}
