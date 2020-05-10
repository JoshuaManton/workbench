package workbench

import "core:fmt"
import "core:sort"
import "core:strings"
import "core:mem"
import "core:os"

import "gpu"
import "profiler"
import "logging"
import "shared"

import "external/stb"
import "external/imgui"


//
// Internal
//

_screen_camera: Camera;
_default_camera: Camera;
main_camera: ^Camera;

wb_cube_model: Model;
wb_quad_model: Model;
wb_sphere_model: Model;

wb_skybox_model: Model;

debug_lines: [dynamic]Debug_Line;
debug_cubes: [dynamic]Debug_Cube;
debug_line_model: Model;

render_wireframes: bool;
visualize_bloom_texture: bool;
visualize_shadow_texture: bool;
visualize_shadow_cascades: bool;

init_draw :: proc(screen_width, screen_height: int) {
when shared.HEADLESS do return;
else
{
    profiler.TIMED_SECTION();

    init_camera(&_screen_camera, false, 10, screen_width, screen_height, create_framebuffer(screen_width, screen_height, default_fbo_options()));
    _screen_camera.clear_color = {1, 0, 1, 1};
    _screen_camera.auto_resize_framebuffer = true;

    options := default_fbo_options();
    options.num_color_buffers = 2;
    options.do_aa = true;
    init_camera(&_default_camera, true, 85, screen_width, screen_height, create_framebuffer(screen_width, screen_height, options));
    setup_bloom(&_default_camera);
    setup_shadow_maps(&_default_camera);
    _default_camera.clear_color = {.1, 0.7, 0.5, 1};
    _default_camera.auto_resize_framebuffer = true;
    push_camera_non_deferred(&_default_camera);

    add_mesh_to_model(&_internal_im_model, []Vertex2D{}, []u32{}, {});

    wb_cube_model = create_cube_model();
    wb_quad_model = create_quad_model();
    wb_sphere_model = create_sphere_model();
    wb_skybox_model = create_cube_model(2);
    add_mesh_to_model(&debug_line_model, []Vertex3D{}, []u32{}, {});

    render_settings = Render_Settings{
        gamma = 2.2,
        exposure = 1,

        do_bloom = true,
        bloom_threshhold = 5.0,
        bloom_blur_passes = 5,
        bloom_range = 10,
        bloom_weight = 0.25,

        do_shadows = true,
    };

    register_debug_program("Rendering", rendering_debug_program, nil);
    register_debug_program("Scene View", scene_view_debug_program, nil);
}
}
rendering_debug_program :: proc(_: rawptr) {
when shared.HEADLESS do return;
else
{
    if imgui.begin("Rendering") {
        imgui_struct(&main_camera.draw_mode, "Draw Mode");
        imgui_struct(&main_camera.polygon_mode, "Polygon Mode");
        imgui_struct(&render_settings, "Render Settings");
        imgui.checkbox("render_wireframes",  &render_wireframes);
        imgui.checkbox("visualize_bloom_texture",  &visualize_bloom_texture);
        imgui.checkbox("visualize_shadow_texture", &visualize_shadow_texture);
        imgui.checkbox("visualize_shadow_cascades", &visualize_shadow_cascades);
    }
    imgui.end();
}
}
scene_view_debug_program :: proc(_: rawptr) {
when shared.HEADLESS do return;
else
{
    if imgui.begin("Scene View") {
        window_size := imgui.get_window_size();

        imgui.image(rawptr(uintptr(main_camera.framebuffer.textures[0].gpu_id)),
            imgui.Vec2{window_size.x - 10, window_size.y - 30},
            imgui.Vec2{0,1},
            imgui.Vec2{1,0});
    }
    imgui.end();
}
}

update_draw :: proc() {
when shared.HEADLESS do return;
else
{
    clear(&debug_lines);
    clear(&debug_cubes);
}
}

// todo(josh): maybe put this in the Workspace?
post_render_proc: proc();
done_postprocessing_proc: proc();
on_render_object: proc(rawptr);

render_workspace :: proc(workspace: Workspace) {
when shared.HEADLESS do return;
else
{
    check_for_file_updates();
    TIMED_SECTION();

    PUSH_GPU_ENABLED(.Cull_Face, true);
    PUSH_GPU_ENABLED(.Multisample, true);

    camera_render(main_camera, workspace.render);

    old_main_camera := main_camera;

    // gpu.bind_fbo(.Read_Framebuffer, _screen_camera.framebuffer.fbo);
    // gpu.bind_fbo(.Draw_Framebuffer, 0);
    // gpu.blit_framebuffer(0, 0, 1920, 1080, 0, 0, 1920, 1080, .Color_Buffer, .Nearest);

    {
        PUSH_CAMERA(&_screen_camera);
        PUSH_POLYGON_MODE(.Fill);

        gpu.read_buffer(.Color0);
        // defer gpu.read_buffer(0);
        gpu.bind_fbo(.Read_Framebuffer, old_main_camera.framebuffer.fbo);
        gpu.bind_fbo(.Draw_Framebuffer, _screen_camera.framebuffer.fbo);
        gpu.blit_framebuffer(0, 0, cast(i32)old_main_camera.framebuffer.width, cast(i32)old_main_camera.framebuffer.height,
                             0, 0, cast(i32)_screen_camera.framebuffer.width,  cast(i32)_screen_camera.framebuffer.height,
                             .Color_Buffer, .Linear);

        // gpu.read_buffer(cast(u32)gpu.Framebuffer_Attachment.Color1);
        // gpu.blit_framebuffer(0, 0, cast(i32)old_main_camera.framebuffer.width, cast(i32)old_main_camera.framebuffer.height,
        //                      0, 0, cast(i32)_screen_camera.framebuffer.width,  cast(i32)_screen_camera.framebuffer.height,
        //                      .Color_Buffer, .Linear);
        // gpu.read_buffer(0);
    }

    // do gamma correction and draw to screen!
    gpu.bind_fbo(.Framebuffer, 0);
    shader_gamma := get_shader("gamma");
    gpu.use_program(shader_gamma);
    gpu.uniform_float(shader_gamma, "gamma", render_settings.gamma);
    gpu.uniform_float(shader_gamma, "exposure", render_settings.exposure);
    draw_texture(_screen_camera.framebuffer.textures[0], {0, 0}, {1, 1});

    // // gpu.use_program(get_shader("default"));
    // draw_texture(_screen_camera.framebuffer.textures[0], {0, 0}, {1, 1});

    imgui_render(true);
}
}

deinit_draw :: proc() {
when shared.HEADLESS do return;
else
{
    delete_camera(&_default_camera);

    // todo(josh): figure out why deleting shaders was causing errors
    // delete_asset_catalog(wb_catalog);

    delete_model(wb_cube_model);
    delete_model(wb_quad_model);

    // todo(josh): figure out why deleting shaders was causing errors
    // gpu.delete_shader(shader_rgba_3d);
    // gpu.delete_shader(shader_rgba_2d);
    // gpu.delete_shader(shader_text);
    // gpu.delete_shader(shader_texture_unlit);
    // gpu.delete_shader(shader_texture_lit);
    // gpu.delete_shader(shader_shadow_depth);
    // gpu.delete_shader(shader_framebuffer_gamma_corrected);

    delete_model(debug_line_model);
    // gpu.deinit();

    delete(debug_lines);
    delete(debug_cubes);

    unregister_debug_program("Rendering");
    unregister_debug_program("Scene View");
}
}