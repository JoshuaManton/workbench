package cube

import wb "shared:workbench"
import "shared:workbench/platform"
import "shared:workbench/math"

import "shared:workbench/logging"
import "shared:workbench/types"

main :: proc() {
	wb.make_simple_window(
		1280, 720,
		60,
		wb.Workspace{"cube", main_init, main_update, main_render, main_end});
}



cube_model: wb.Model;
cube_rotation := math.Quat{0, 0, 0, 1};

main_init :: proc() {
	// load cube model
	cube_model = wb.create_cube_model();

	// setup camera
	wb.main_camera.position = math.Vec3{0, 4, 8};
	wb.main_camera.rotation = math.degrees_to_quaternion(math.Vec3{-30, 0, 0});
	wb.main_camera.is_perspective = true;
	wb.main_camera.size = 75;
	wb.main_camera.clear_color = {.05, .1, .6, 1};
}

main_update :: proc(dt: f32) {
	if platform.get_input_down(.Escape) do wb.exit();

	cube_rotation = math.quat_mul(cube_rotation, math.euler_angles(0 * dt, 1 * dt, 1.5 * dt));
}

main_render :: proc(dt: f32) {
	wb.set_sun_data(math.degrees_to_quaternion(math.Vec3{-60, -60, 0}), types.Colorf{1, 1, 1, 1}, 1);

	default_material := wb.Material{0.9, 0.9, 0.2};

	// draw ground
	wb.submit_draw_command(wb.create_draw_command(cube_model, wb.get_shader("lit"), math.Vec3{0, -2, 0}, {10, 1, 10}, math.Quat{0, 0, 0, 1}, types.Colorf{0.035, 1, 0, 1}, {}, default_material));

	// draw rotating cube
	wb.submit_draw_command(wb.create_draw_command(cube_model, wb.get_shader("lit"), math.Vec3{}, {1, 1, 1}, cube_rotation, types.Colorf{1, 0.8, 0, 1}, {}, default_material));

	// draw light
	light_position := math.Vec3{math.sin(wb.time) * 3, 2, math.cos(wb.time) * 3};
	light_color := types.Colorf{1, 0, 1, 1};
	wb.push_point_light(light_position, light_color, 100);
	wb.submit_draw_command(wb.create_draw_command(cube_model, wb.get_shader("lit"), light_position, {.5, .5, .5}, math.Quat{0, 0, 0, 1}, light_color, {}, default_material));
}

main_end :: proc() {
	wb.delete_model(cube_model);
}
