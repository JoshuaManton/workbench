package workbench

using import "core:runtime"
using import "core:fmt"
      import "core:mem";
      import "core:strconv"
      import "core:strings"
      import "core:os";
      import "core:sys/win32"


      import "gpu"
      import "laas"
using import "math";
using import "platform"
using import "logging"

import    "external/glfw"
import    "external/stb"
import    "external/imgui"
import gl "external/gl"

imgui_program: gpu.Shader_Program;

imgui_uniform_texture: gpu.Location;
imgui_uniform_projection: gpu.Location;

imgui_attrib_position: gpu.Location;
imgui_attrib_uv: gpu.Location;
imgui_attrib_color: gpu.Location;

imgui_vbo_handle: gpu.VBO;
imgui_ebo_handle: gpu.EBO;

// note(josh): @Cleanup: These are probably duplicates of fonts we already use in the game
imgui_font_default: ^imgui.Font;
imgui_font_mono:    ^imgui.Font;

init_dear_imgui :: proc() {
    // imgui.create_context();
    io := imgui.get_io();
    io.ime_window_handle = win32.get_desktop_window();

    io.key_map[imgui.Key.Tab]        = i32(platform.Input.Tab);
    io.key_map[imgui.Key.LeftArrow]  = i32(platform.Input.Left);
    io.key_map[imgui.Key.RightArrow] = i32(platform.Input.Right);
    io.key_map[imgui.Key.UpArrow]    = i32(platform.Input.Up);
    io.key_map[imgui.Key.DownArrow]  = i32(platform.Input.Down);
    io.key_map[imgui.Key.PageUp]     = i32(platform.Input.Page_Up);
    io.key_map[imgui.Key.PageDown]   = i32(platform.Input.Page_Down);
    io.key_map[imgui.Key.Home]       = i32(platform.Input.Home);
    io.key_map[imgui.Key.End]        = i32(platform.Input.End);
    io.key_map[imgui.Key.Delete]     = i32(platform.Input.Delete);
    io.key_map[imgui.Key.Backspace]  = i32(platform.Input.Backspace);
    io.key_map[imgui.Key.Enter]      = i32(platform.Input.Enter);
    io.key_map[imgui.Key.Escape]     = i32(platform.Input.Escape);
    io.key_map[imgui.Key.A]          = i32(platform.Input.A);
    io.key_map[imgui.Key.C]          = i32(platform.Input.C);
    io.key_map[imgui.Key.V]          = i32(platform.Input.V);
    io.key_map[imgui.Key.X]          = i32(platform.Input.X);
    io.key_map[imgui.Key.Y]          = i32(platform.Input.Y);
    io.key_map[imgui.Key.Z]          = i32(platform.Input.Z);

    vs ::
        `#version 330
        uniform mat4 ProjMtx;
        in vec2 Position;
        in vec2 UV;
        in vec4 Color;
        out vec2 Frag_UV;
        out vec4 Frag_Color;
        void main()
        {
           Frag_UV = UV;
           Frag_Color = Color;
           gl_Position = ProjMtx * vec4(Position.xy,0,1);
        }`;

    fs ::
        `#version 330
        uniform sampler2D Texture;
        in vec2 Frag_UV;
        in vec4 Frag_Color;
        out vec4 Out_Color;
        void main()
        {
           Out_Color = Frag_Color * texture( Texture, Frag_UV.st);
        }`;

	ok: bool;
    imgui_program, ok = gpu.load_shader_vert_frag(vs, fs);
    assert(ok);

    imgui_uniform_texture    = gpu.get_uniform_location(imgui_program, "Texture");
    imgui_uniform_projection = gpu.get_uniform_location(imgui_program, "ProjMtx");

    imgui_attrib_position = gpu.get_attrib_location(imgui_program, "Position");
    imgui_attrib_uv       = gpu.get_attrib_location(imgui_program, "UV");
    imgui_attrib_color    = gpu.get_attrib_location(imgui_program, "Color");

    imgui_vbo_handle = cast(gpu.VBO)gpu.gen_buffer();
    imgui_ebo_handle = cast(gpu.EBO)gpu.gen_buffer();

    gpu.bind_vbo(imgui_vbo_handle);
    gpu.bind_ebo(imgui_ebo_handle);

    font_default_data, ok1 := os.read_entire_file(tprint(WORKBENCH_PATH, "/resources/fonts/Roboto/Roboto-Regular.ttf"));          assert(ok1); defer delete(font_default_data);
    font_mono_data,    ok2 := os.read_entire_file(tprint(WORKBENCH_PATH, "/resources/fonts/Roboto_Mono/RobotoMono-Regular.ttf")); assert(ok2); defer delete(font_mono_data);

    imgui_font_default = imgui.font_atlas_add_font_from_memory_ttf(io.fonts, &font_default_data[0], cast(i32)(size_of(font_default_data[0]) * len(font_default_data)), 20);
    imgui_font_mono    = imgui.font_atlas_add_font_from_memory_ttf(io.fonts, &font_mono_data[0],    cast(i32)(size_of(font_mono_data[0])    * len(font_mono_data)),    16);


/*    //TODO(Hoej): Get from font catalog
    if custom_font {
        default_font = imgui.font_atlas_add_font_from_file_ttf(io.fonts, "data/fonts/Roboto-Medium.ttf", 14);
        if default_font == nil {
            fmt.println("Couldn't load data/fonts/Roboto-Medium.tff for dear imgui");
        } else {
            conf : imgui.FontConfig;
            imgui.font_config_default_constructor(&conf);
            conf.merge_mode = true;
            ICON_MIN_FA :: 0xf000;
            ICON_MAX_FA :: 0xf2e0;
            icon_ranges := []imgui.Wchar{ ICON_MIN_FA, ICON_MAX_FA, 0 };
            imgui.font_atlas_add_font_from_file_ttf(io.fonts, "data/fonts/fontawesome-webfont.ttf", 10, &conf, icon_ranges[:]);
        }

        conf : imgui.FontConfig;
        imgui.font_config_default_constructor(&conf);
        mono_font = imgui.font_atlas_add_font_default(io.fonts, &conf);

    } else {
        conf : imgui.FontConfig;
        imgui.font_config_default_constructor(&conf);
        default_font = imgui.font_atlas_add_font_default(io.fonts, &conf);
        mono_font = default_font;
    }
*/
    pixels : ^u8;
    width, height : i32;
    imgui.font_atlas_get_text_data_as_rgba32(io.fonts, &pixels, &width, &height);

    tex := gpu.gen_texture();
    gpu.bind_texture_2d(tex);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA,
                  width, height, 0, gl.RGBA, // todo(josh): @Incomplete: Make sure the 0 on this line, and the RGBA things are right
                  gl.UNSIGNED_BYTE, pixels);

    imgui.font_atlas_set_text_id(io.fonts, rawptr(uintptr(uint(tex))));

    //
    // Style
    //

    // WB STYLE
    // todo




    // BREW STYLE
    style := imgui.get_style();
    style.window_padding = imgui.Vec2{6, 6};
    style.window_rounding = 2;
    style.child_rounding = 2;
    style.frame_padding = imgui.Vec2{4 ,2};
    style.frame_rounding = 1;
    style.item_spacing = imgui.Vec2{8, 4};
    style.item_inner_spacing = imgui.Vec2{4, 4};
    style.touch_extra_padding = imgui.Vec2{0, 0};
    style.indent_spacing = 20;
    style.scrollbar_size = 12;
    style.scrollbar_rounding = 9;
    style.grab_min_size = 9;
    style.grab_rounding = 1;

    style.window_title_align = imgui.Vec2{0.48, 0.5};
    style.button_text_align = imgui.Vec2{0.5, 0.5};

    style.colors[imgui.Color.Text]                  = imgui.Vec4{1.00, 1.00, 1.00, 1.00};
    style.colors[imgui.Color.TextDisabled]          = imgui.Vec4{0.63, 0.63, 0.63, 1.00};
    style.colors[imgui.Color.WindowBg]              = imgui.Vec4{0.23, 0.23, 0.23, 0.98};
    style.colors[imgui.Color.ChildBg]               = imgui.Vec4{0.20, 0.20, 0.20, 1.00};
    style.colors[imgui.Color.PopupBg]               = imgui.Vec4{0.25, 0.25, 0.25, 0.96};
    style.colors[imgui.Color.Border]                = imgui.Vec4{0.18, 0.18, 0.18, 0.98};
    style.colors[imgui.Color.BorderShadow]          = imgui.Vec4{0.00, 0.00, 0.00, 0.04};
    style.colors[imgui.Color.FrameBg]               = imgui.Vec4{0.00, 0.00, 0.00, 0.29};
    style.colors[imgui.Color.TitleBg]               = imgui.Vec4{0.25, 0.25, 0.25, 0.98};
    style.colors[imgui.Color.TitleBgCollapsed]      = imgui.Vec4{0.12, 0.12, 0.12, 0.49};
    style.colors[imgui.Color.TitleBgActive]         = imgui.Vec4{0.33, 0.33, 0.33, 0.98};
    style.colors[imgui.Color.MenuBarBg]             = imgui.Vec4{0.11, 0.11, 0.11, 0.42};
    style.colors[imgui.Color.ScrollbarBg]           = imgui.Vec4{0.00, 0.00, 0.00, 0.08};
    style.colors[imgui.Color.ScrollbarGrab]         = imgui.Vec4{0.27, 0.27, 0.27, 1.00};
    style.colors[imgui.Color.ScrollbarGrabHovered]  = imgui.Vec4{0.78, 0.78, 0.78, 0.40};
    style.colors[imgui.Color.CheckMark]             = imgui.Vec4{0.78, 0.78, 0.78, 0.94};
    style.colors[imgui.Color.SliderGrab]            = imgui.Vec4{0.78, 0.78, 0.78, 0.94};
    style.colors[imgui.Color.Button]                = imgui.Vec4{0.42, 0.42, 0.42, 0.60};
    style.colors[imgui.Color.ButtonHovered]         = imgui.Vec4{0.78, 0.78, 0.78, 0.40};
    style.colors[imgui.Color.Header]                = imgui.Vec4{0.31, 0.31, 0.31, 0.98};
    style.colors[imgui.Color.HeaderHovered]         = imgui.Vec4{0.78, 0.78, 0.78, 0.40};
    style.colors[imgui.Color.HeaderActive]          = imgui.Vec4{0.80, 0.50, 0.50, 1.00};
    style.colors[imgui.Color.TextSelectedBg]        = imgui.Vec4{0.65, 0.35, 0.35, 0.26};
    // style.colors[imgui.Color.ModalWindowDimBg]      = imgui.Vec4{0.20, 0.20, 0.20, 0.35};





    // SOME STYLE I FOUND ONLINE
    // style := imgui.get_style();

    // style.window_padding = imgui.Vec2{15, 15};
    // style.window_rounding = 5;
    // style.frame_padding = imgui.Vec2{5, 5};
    // style.frame_rounding = 4;
    // style.item_spacing = imgui.Vec2{12, 8};
    // style.item_inner_spacing = imgui.Vec2{8, 6};
    // style.indent_spacing = 25;
    // style.scrollbar_size = 15;
    // style.scrollbar_rounding = 9;
    // style.grab_min_size = 5;
    // style.grab_rounding = 3;

    // style.colors[imgui.Color.Text] = imgui.Vec4{0.80, 0.80, 0.83, 1.00};
    // style.colors[imgui.Color.TextDisabled] = imgui.Vec4{0.24, 0.23, 0.29, 1.00};
    // style.colors[imgui.Color.WindowBg] = imgui.Vec4{0.06, 0.05, 0.07, 1.00};
    // style.colors[imgui.Color.ChildWindowBg] = imgui.Vec4{0.07, 0.07, 0.09, 1.00};
    // style.colors[imgui.Color.PopupBg] = imgui.Vec4{0.07, 0.07, 0.09, 1.00};
    // style.colors[imgui.Color.Border] = imgui.Vec4{0.80, 0.80, 0.83, 0.88};
    // style.colors[imgui.Color.BorderShadow] = imgui.Vec4{0.92, 0.91, 0.88, 0.00};
    // style.colors[imgui.Color.FrameBg] = imgui.Vec4{0.10, 0.09, 0.12, 1.00};
    // style.colors[imgui.Color.FrameBgHovered] = imgui.Vec4{0.24, 0.23, 0.29, 1.00};
    // style.colors[imgui.Color.FrameBgActive] = imgui.Vec4{0.56, 0.56, 0.58, 1.00};
    // style.colors[imgui.Color.TitleBg] = imgui.Vec4{0.10, 0.09, 0.12, 1.00};
    // style.colors[imgui.Color.TitleBgCollapsed] = imgui.Vec4{1.00, 0.98, 0.95, 0.75};
    // style.colors[imgui.Color.TitleBgActive] = imgui.Vec4{0.07, 0.07, 0.09, 1.00};
    // style.colors[imgui.Color.MenuBarBg] = imgui.Vec4{0.10, 0.09, 0.12, 1.00};
    // style.colors[imgui.Color.ScrollbarBg] = imgui.Vec4{0.10, 0.09, 0.12, 1.00};
    // style.colors[imgui.Color.ScrollbarGrab] = imgui.Vec4{0.80, 0.80, 0.83, 0.31};
    // style.colors[imgui.Color.ScrollbarGrabHovered] = imgui.Vec4{0.56, 0.56, 0.58, 1.00};
    // style.colors[imgui.Color.ScrollbarGrabActive] = imgui.Vec4{0.06, 0.05, 0.07, 1.00};
    // // style.colors[imgui.Color.ComboBg] = imgui.Vec4{0.19, 0.18, 0.21, 1.00};
    // style.colors[imgui.Color.CheckMark] = imgui.Vec4{0.80, 0.80, 0.83, 0.31};
    // style.colors[imgui.Color.SliderGrab] = imgui.Vec4{0.80, 0.80, 0.83, 0.31};
    // style.colors[imgui.Color.SliderGrabActive] = imgui.Vec4{0.06, 0.05, 0.07, 1.00};
    // style.colors[imgui.Color.Button] = imgui.Vec4{0.10, 0.09, 0.12, 1.00};
    // style.colors[imgui.Color.ButtonHovered] = imgui.Vec4{0.24, 0.23, 0.29, 1.00};
    // style.colors[imgui.Color.ButtonActive] = imgui.Vec4{0.56, 0.56, 0.58, 1.00};
    // style.colors[imgui.Color.Header] = imgui.Vec4{0.10, 0.09, 0.12, 1.00};
    // style.colors[imgui.Color.HeaderHovered] = imgui.Vec4{0.56, 0.56, 0.58, 1.00};
    // style.colors[imgui.Color.HeaderActive] = imgui.Vec4{0.06, 0.05, 0.07, 1.00};
    // style.colors[imgui.Color.Column] = imgui.Vec4{0.56, 0.56, 0.58, 1.00};
    // style.colors[imgui.Color.ColumnHovered] = imgui.Vec4{0.24, 0.23, 0.29, 1.00};
    // style.colors[imgui.Color.ColumnActive] = imgui.Vec4{0.56, 0.56, 0.58, 1.00};
    // style.colors[imgui.Color.ResizeGrip] = imgui.Vec4{0.00, 0.00, 0.00, 0.00};
    // style.colors[imgui.Color.ResizeGripHovered] = imgui.Vec4{0.56, 0.56, 0.58, 1.00};
    // style.colors[imgui.Color.ResizeGripActive] = imgui.Vec4{0.06, 0.05, 0.07, 1.00};
    // style.colors[imgui.Color.CloseButton] = imgui.Vec4{0.40, 0.39, 0.38, 0.16};
    // style.colors[imgui.Color.CloseButtonHovered] = imgui.Vec4{0.40, 0.39, 0.38, 0.39};
    // style.colors[imgui.Color.CloseButtonActive] = imgui.Vec4{0.40, 0.39, 0.38, 1.00};
    // style.colors[imgui.Color.PlotLines] = imgui.Vec4{0.40, 0.39, 0.38, 0.63};
    // style.colors[imgui.Color.PlotLinesHovered] = imgui.Vec4{0.25, 1.00, 0.00, 1.00};
    // style.colors[imgui.Color.PlotHistogram] = imgui.Vec4{0.40, 0.39, 0.38, 0.63};
    // style.colors[imgui.Color.PlotHistogramHovered] = imgui.Vec4{0.25, 1.00, 0.00, 1.00};
    // style.colors[imgui.Color.TextSelectedBg] = imgui.Vec4{0.25, 1.00, 0.00, 0.43};
    // style.colors[imgui.Color.ModalWindowDarkening] = imgui.Vec4{1.00, 0.98, 0.95, 0.73};
}

imgui_begin_new_frame :: proc(dt: f32) {
    io := imgui.get_io();
    io.display_size.x = current_window_width;
    io.display_size.y = current_window_height;

    if window_is_focused {
    	posx, posy := glfw.GetCursorPos(main_window);
        io.mouse_pos.x = cast(f32)posx;
        io.mouse_pos.y = cast(f32)posy;
        io.mouse_down[0] = glfw.GetMouseButton(main_window, cast(glfw.Mouse)Input.Mouse_Left) == glfw.Action.Press;
        io.mouse_down[1] = glfw.GetMouseButton(main_window, cast(glfw.Mouse)Input.Mouse_Right) == glfw.Action.Press;
        io.mouse_wheel   = mouse_scroll;

        io.key_ctrl  = win32.is_key_down(win32.Key_Code.Lcontrol) || win32.is_key_down(win32.Key_Code.Rcontrol);
        io.key_shift = win32.is_key_down(win32.Key_Code.Lshift)   || win32.is_key_down(win32.Key_Code.Rshift);
        io.key_alt   = win32.is_key_down(win32.Key_Code.Lmenu)    || win32.is_key_down(win32.Key_Code.Rmenu);
        io.key_super = win32.is_key_down(win32.Key_Code.Lwin)     || win32.is_key_down(win32.Key_Code.Rwin);

        for i in 0..511 {
            io.keys_down[i] = get_input_imgui(cast(Input)i);
        }

    } else {
        io.mouse_pos = imgui.Vec2{-math.F32_MAX, -math.F32_MAX};

        io.mouse_down[0] = false;
        io.mouse_down[1] = false;
        io.mouse_wheel   = 0;
        io.key_ctrl  = false;
        io.key_shift = false;
        io.key_alt   = false;
        io.key_super = false;

        for i in 0..511 {
            io.keys_down[i] = false;
        }
    }

    // ctx.imgui_state.mouse_wheel_delta = 0;
    io.delta_time = dt;
    imgui.new_frame();
}

imgui_render :: proc(render_to_screen : bool) {
    imgui.render();
    if !render_to_screen {
        return;
    }
    data := imgui.get_draw_data();
    io := imgui.get_io();

    width  := i32(io.display_size.x * io.display_framebuffer_scale.x);
    height := i32(io.display_size.y * io.display_framebuffer_scale.y);
    if height == 0 || width == 0 {
        return;
    }
    // imgui.draw_data_scale_clip_rects(data, io.display_framebuffer_scale);

    //@TODO(Hoej): BACKUP STATE!
    lastViewport : [4]i32;
    lastScissor  : [4]i32;

    cull    := gpu.get_int(gl.CULL_FACE);
    depth   := gpu.get_int(gl.DEPTH_TEST);
    scissor := gpu.get_int(gl.SCISSOR_TEST);
    blend   := gpu.get_int(gl.BLEND);

    gl.GetIntegerv(gl.VIEWPORT, &lastViewport[0]);
    gl.GetIntegerv(gl.SCISSOR_BOX, &lastScissor[0]);

    gl.Enable(gl.BLEND);
    gl.BlendEquation(gl.FUNC_ADD);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.Disable(gl.CULL_FACE);
    gl.Disable(gl.DEPTH_TEST);
    gl.Enable(gl.SCISSOR_TEST);
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL);

    gl.Viewport(0, 0, width, height);
    ortho_projection := math.Mat4
    {
        { 2.0/io.display_size.x,                    0.0,  0.0, 0.0 },
        {                   0.0, 2.0/-io.display_size.y,  0.0, 0.0 },
        {                   0.0,                    0.0, -1.0, 0.0 },
        {                    -1,                      1,  0.0, 1.0 },
    };

    old_program := gpu.get_current_shader();
    defer gpu.use_program(old_program);

    gpu.use_program(imgui_program);
    gpu.uniform_int(imgui_program, "Texture", i32(0));
    gpu.uniform_mat4(imgui_program, "ProjMtx", &ortho_projection);

    vao_handle := gpu.gen_vao();
    gpu.bind_vao(vao_handle);
    gpu.bind_vbo(imgui_vbo_handle);

    gl.EnableVertexAttribArray(cast(u32)imgui_attrib_position);
    gl.EnableVertexAttribArray(cast(u32)imgui_attrib_uv);
    gl.EnableVertexAttribArray(cast(u32)imgui_attrib_color);

    gl.VertexAttribPointer(cast(u32)imgui_attrib_position, 2, gl.FLOAT,         gl.FALSE, size_of(imgui.DrawVert), cast(rawptr)offset_of(imgui.DrawVert, pos));
    gl.VertexAttribPointer(cast(u32)imgui_attrib_uv,       2, gl.FLOAT,         gl.FALSE, size_of(imgui.DrawVert), cast(rawptr)offset_of(imgui.DrawVert, uv));
    gl.VertexAttribPointer(cast(u32)imgui_attrib_color,    4, gl.UNSIGNED_BYTE, gl.TRUE,  size_of(imgui.DrawVert), cast(rawptr)offset_of(imgui.DrawVert, col));

    new_list := mem.slice_ptr(data.cmd_lists, int(data.cmd_lists_count));
    for list in new_list {
        idx_buffer_offset : ^imgui.DrawIdx = nil;

        gpu.bind_vbo(imgui_vbo_handle);
        gl.BufferData(gl.ARRAY_BUFFER,
                       cast(int)(imgui.draw_list_get_vertex_buffer_size(list) * size_of(imgui.DrawVert)),
                       imgui.draw_list_get_vertex_ptr(list, 0),
                       gl.STREAM_DRAW);

        gpu.bind_ebo(imgui_ebo_handle);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER,
                       cast(int)(imgui.draw_list_get_index_buffer_size(list) * size_of(imgui.DrawIdx)),
                       imgui.draw_list_get_index_ptr(list, 0),
                       gl.STREAM_DRAW);

        for j : i32 = 0; j < imgui.draw_list_get_cmd_size(list); j += 1 {
            cmd := imgui.draw_list_get_cmd_ptr(list, j);
            gpu.bind_texture_2d(gpu.TextureId(uint(uintptr(cmd.texture_id))));
            gl.Scissor(i32(cmd.clip_rect.x), height - i32(cmd.clip_rect.w), i32(cmd.clip_rect.z - cmd.clip_rect.x), i32(cmd.clip_rect.w - cmd.clip_rect.y));
            gl.DrawElements(gl.TRIANGLES, i32(cmd.elem_count), gl.UNSIGNED_SHORT, idx_buffer_offset);
            //idx_buffer_offset += cmd.elem_count;
            idx_buffer_offset = mem.ptr_offset(idx_buffer_offset, int(cmd.elem_count));

        }
    }

    gpu.delete_vao(vao_handle);

    //TODO: Restore state

    if blend   == 1 { gl.Enable(gl.BLEND);        } else { gl.Disable(gl.BLEND);        }
    if cull    == 1 { gl.Enable(gl.CULL_FACE);    } else { gl.Disable(gl.CULL_FACE);    }
    if depth   == 1 { gl.Enable(gl.DEPTH_TEST);   } else { gl.Disable(gl.DEPTH_TEST);   }
    if scissor == 1 { gl.Enable(gl.SCISSOR_TEST); } else { gl.Disable(gl.SCISSOR_TEST); }
    gl.Viewport(lastViewport[0], lastViewport[1], lastViewport[2], lastViewport[3]);
    gl.Scissor(lastScissor[0], lastScissor[1], lastScissor[2], lastScissor[3]);
}

begin_panel :: proc(label : string, pos, size : imgui.Vec2) -> bool {
    imgui.set_next_window_pos(pos, imgui.Set_Cond.Always);
    imgui.set_next_window_size(size, imgui.Set_Cond.Always);
    return imgui.begin(label, nil, imgui.Window_Flags.NoTitleBar      |
                             imgui.Window_Flags.NoMove                |
                             imgui.Window_Flags.NoResize              |
                             imgui.Window_Flags.NoBringToFrontOnFocus);
}

columns_reset :: proc() {
    imgui.columns(count = 1, border = false);
}



imgui_struct_window :: inline proc(value: ^$T) {
    imgui.push_font(imgui_font_mono);
    defer imgui.pop_font();

    imgui.begin(tprint(type_info_of(T)));
    defer imgui.end();

    imgui_struct_ti("", value, type_info_of(T));
}

imgui_struct :: inline proc(value: ^$T, name: string, do_header := true) {
    imgui.push_font(imgui_font_mono);
    defer imgui.pop_font();

    imgui_struct_ti(name, value, type_info_of(T), "", do_header);
}

_imgui_struct_block_field_start :: proc(name: string, typename: string) -> bool {
    // if name != "" {
        header: string;
        if name != "" {
            header = tprint(name, ": ", typename);
        }
        else {
            header = tprint(typename);
        }
        if imgui.collapsing_header(header) {
            imgui.indent();
            return true;
        }
        return false;
    // }
    // return true;
}
_imgui_struct_block_field_end :: proc(name: string) {
    // if name != "" {
        imgui.unindent();
    // }
}

_readonly: bool;
imgui_struct_ti :: proc(name: string, data: rawptr, ti: ^Type_Info, tags: string = "", do_header := true, type_name: string = "") {
    imgui.push_id(name);
    defer imgui.pop_id();

    if strings.contains(tags, "imgui_readonly") {
        imgui.label_text(name, tprint(any{data, ti.id}));
        return;
    }

    if strings.contains(tags, "imgui_hidden") {
        return;
    }

    has_range_constraint: bool;
    range_min: f32;
    range_max: f32;
    if strings.contains(tags, "imgui_range") {
        has_range_constraint = true;
        range_idx := strings.index(tags, "imgui_range");
        assert(range_idx >= 0);
        range_str := tags[range_idx:];
        range_lexer := laas.make_lexer(range_str);
        laas.get_next_token(&range_lexer, nil);
        laas.expect_symbol(&range_lexer, '=');
        range_min_str := laas.expect_string(&range_lexer);
        laas.expect_symbol(&range_lexer, ':');
        range_max_str := laas.expect_string(&range_lexer);

        range_min = parse_f32(range_min_str);
        range_max = parse_f32(range_max_str);
    }

    switch kind in &ti.variant {
        case Type_Info_Integer: {
            if kind.signed {
                switch ti.size {
                    case 8: new_data := cast(i32)(cast(^i64)data)^; imgui.input_int(name, &new_data); (cast(^i64)data)^ = cast(i64)new_data;
                    case 4: new_data := cast(i32)(cast(^i32)data)^; imgui.input_int(name, &new_data); (cast(^i32)data)^ = cast(i32)new_data;
                    case 2: new_data := cast(i32)(cast(^i16)data)^; imgui.input_int(name, &new_data); (cast(^i16)data)^ = cast(i16)new_data;
                    case 1: new_data := cast(i32)(cast(^i8 )data)^; imgui.input_int(name, &new_data); (cast(^i8 )data)^ = cast(i8 )new_data;
                    case: assert(false, tprint(ti.size));
                }
            }
            else {
                switch ti.size {
                    case 8: new_data := cast(i32)(cast(^u64)data)^; imgui.input_int(name, &new_data); (cast(^u64)data)^ = cast(u64)new_data;
                    case 4: new_data := cast(i32)(cast(^u32)data)^; imgui.input_int(name, &new_data); (cast(^u32)data)^ = cast(u32)new_data;
                    case 2: new_data := cast(i32)(cast(^u16)data)^; imgui.input_int(name, &new_data); (cast(^u16)data)^ = cast(u16)new_data;
                    case 1: new_data := cast(i32)(cast(^u8 )data)^; imgui.input_int(name, &new_data); (cast(^u8 )data)^ = cast(u8 )new_data;
                    case: assert(false, tprint(ti.size));
                }
            }
        }
        case Type_Info_Float: {
            switch ti.size {
                case 8: {
                    new_data := cast(f32)(cast(^f64)data)^;
                    imgui.push_item_width(100);
                    imgui.input_float(tprint(name, "##non_range"), &new_data);
                    imgui.pop_item_width();
                    if has_range_constraint {
                        imgui.same_line();
                        imgui.push_item_width(200);
                        imgui.slider_float(name, &new_data, range_min, range_max);
                        imgui.pop_item_width();
                    }
                    (cast(^f64)data)^ = cast(f64)new_data;
                }
                case 4: {
                    new_data := cast(f32)(cast(^f32)data)^;
                    imgui.push_item_width(100);
                    imgui.input_float(tprint(name, "##non_range"), &new_data);
                    imgui.pop_item_width();
                    if has_range_constraint {
                        imgui.same_line();
                        imgui.push_item_width(200);
                        imgui.slider_float(name, &new_data, range_min, range_max);
                        imgui.pop_item_width();
                    }
                    (cast(^f32)data)^ = cast(f32)new_data;
                }
                case: assert(false, tprint(ti.size));
            }
        }
        case Type_Info_String: {
            assert(ti.size == size_of(string));
            // todo(josh): arbitrary string length, right now there is a max length
            // https://github.com/ocornut/imgui/issues/1008
            text_edit_buffer: [256]u8;
            bprint(text_edit_buffer[:], (cast(^string)data)^);

            if imgui.input_text(name, text_edit_buffer[:], .EnterReturnsTrue) {
                result := text_edit_buffer[:];
                for b, i in text_edit_buffer {
                    if b == '\x00' {
                        result = text_edit_buffer[:i];
                        break;
                    }
                }
                str := strings.clone(cast(string)result);
                (cast(^string)data)^ = str; // @Leak
            }
        }
        case Type_Info_Boolean: {
            assert(ti.size == size_of(bool));
            imgui.checkbox(name, cast(^bool)data);
        }
        case Type_Info_Pointer: {
            result := tprint(name, " = ", "\"", data, "\"");
            imgui.text(result);
        }
        case Type_Info_Named: {
            imgui_struct_ti(name, data, kind.base, "", do_header, kind.name);
        }
        case Type_Info_Struct: {
            if !do_header || _imgui_struct_block_field_start(name, type_name) {
                defer if do_header do _imgui_struct_block_field_end(name);

                // if kind == &type_info_of(Quat).variant.(Type_Info_Named).base.variant.(Type_Info_Struct) {
                //     q := cast(^Quat)data;
                //     dir := quaternion_to_euler(q^);
                //     if imgui.input_float("##782783", &dir.x, 0, 0, -1, imgui.Input_Text_Flags.EnterReturnsTrue) {
                //         q^ = euler_angles(expand_to_tuple(dir));
                //     }
                //     if imgui.input_float("##42424", &dir.y, 0, 0, -1, imgui.Input_Text_Flags.EnterReturnsTrue) {
                //         q^ = euler_angles(expand_to_tuple(dir));
                //     }
                //     if imgui.input_float("##54512", &dir.z, 0, 0, -1, imgui.Input_Text_Flags.EnterReturnsTrue) {
                //         q^ = euler_angles(expand_to_tuple(dir));
                //     }
                // }

                for field_name, i in kind.names {
                    t := kind.types[i];
                    offset := kind.offsets[i];
                    data := mem.ptr_offset(cast(^byte)data, cast(int)offset);
                    tag := kind.tags[i];
                    imgui_struct_ti(field_name, data, t, tag);
                }
            }
        }
        case Type_Info_Enum: {
            if len(kind.values) > 0 {
                current_item_index : i32 = -1;
                #complete
                switch _ in kind.values[0] {
                    case u8:        for v, idx in kind.values { if (cast(^u8     )data)^ == v.(u8)      { current_item_index = cast(i32)idx; break; } }
                    case u16:       for v, idx in kind.values { if (cast(^u16    )data)^ == v.(u16)     { current_item_index = cast(i32)idx; break; } }
                    case u32:       for v, idx in kind.values { if (cast(^u32    )data)^ == v.(u32)     { current_item_index = cast(i32)idx; break; } }
                    case u64:       for v, idx in kind.values { if (cast(^u64    )data)^ == v.(u64)     { current_item_index = cast(i32)idx; break; } }
                    case uint:      for v, idx in kind.values { if (cast(^uint   )data)^ == v.(uint)    { current_item_index = cast(i32)idx; break; } }
                    case i8:        for v, idx in kind.values { if (cast(^i8     )data)^ == v.(i8)      { current_item_index = cast(i32)idx; break; } }
                    case i16:       for v, idx in kind.values { if (cast(^i16    )data)^ == v.(i16)     { current_item_index = cast(i32)idx; break; } }
                    case i32:       for v, idx in kind.values { if (cast(^i32    )data)^ == v.(i32)     { current_item_index = cast(i32)idx; break; } }
                    case i64:       for v, idx in kind.values { if (cast(^i64    )data)^ == v.(i64)     { current_item_index = cast(i32)idx; break; } }
                    case int:       for v, idx in kind.values { if (cast(^int    )data)^ == v.(int)     { current_item_index = cast(i32)idx; break; } }
                    case rune:      for v, idx in kind.values { if (cast(^rune   )data)^ == v.(rune)    { current_item_index = cast(i32)idx; break; } }
                    case uintptr:   for v, idx in kind.values { if (cast(^uintptr)data)^ == v.(uintptr) { current_item_index = cast(i32)idx; break; } }
                    case: panic(tprint(kind.values[0]));
                }

                item := current_item_index;
                imgui.combo(name, &item, kind.names, cast(i32)min(5, len(kind.names)));
                if item != current_item_index {
                    switch value in kind.values[item] {
                        case u8:        (cast(^u8     )data)^ = value;
                        case u16:       (cast(^u16    )data)^ = value;
                        case u32:       (cast(^u32    )data)^ = value;
                        case u64:       (cast(^u64    )data)^ = value;
                        case uint:      (cast(^uint   )data)^ = value;
                        case i8:        (cast(^i8     )data)^ = value;
                        case i16:       (cast(^i16    )data)^ = value;
                        case i32:       (cast(^i32    )data)^ = value;
                        case i64:       (cast(^i64    )data)^ = value;
                        case int:       (cast(^int    )data)^ = value;
                        case rune:      (cast(^rune   )data)^ = value;
                        case uintptr:   (cast(^uintptr)data)^ = value;
                        case: panic(tprint(value));
                    }
                }
            }
        }
        case Type_Info_Slice: {
            if !do_header || _imgui_struct_block_field_start(name, tprint("[]", kind.elem)) {
                defer if do_header do _imgui_struct_block_field_end(name);

                slice := (cast(^mem.Raw_Slice)data)^;
                for i in 0..slice.len-1 {
                    imgui.push_id(tprint(i));
                    defer imgui.pop_id();
                    imgui_struct_ti(tprint("[", i, "]"), mem.ptr_offset(cast(^byte)slice.data, i * kind.elem_size), kind.elem);
                }
            }
        }
        case Type_Info_Array: {
            if !do_header || _imgui_struct_block_field_start(name, tprint("[", kind.count, "]", kind.elem)) {
                defer if do_header do _imgui_struct_block_field_end(name);

                for i in 0..kind.count-1 {
                    imgui.push_id(tprint(i));
                    defer imgui.pop_id();
                    imgui_struct_ti(tprint("[", i, "]"), mem.ptr_offset(cast(^byte)data, i * kind.elem_size), kind.elem);
                }
            }
        }
        case Type_Info_Dynamic_Array: {
            if !do_header || _imgui_struct_block_field_start(name, tprint("[dynamic]", kind.elem)) {
                defer if do_header do _imgui_struct_block_field_end(name);

                array := (cast(^mem.Raw_Dynamic_Array)data)^;
                for i in 0..array.len-1 {
                    imgui.push_id(tprint(i));
                    defer imgui.pop_id();
                    imgui_struct_ti(tprint("[", i, "]"), mem.ptr_offset(cast(^byte)array.data, i * kind.elem_size), kind.elem);
                }
            }
        }
        case Type_Info_Any: {
            a := cast(^any)data;
            if a.data == nil do return;
            imgui_struct_ti(name, a.data, type_info_of(a.id));
        }
        case Type_Info_Union: {
            tag_ptr := uintptr(data) + kind.tag_offset;
            tag_any := any{rawptr(tag_ptr), kind.tag_type.id};

            current_tag: i32 = -1;
            switch i in tag_any {
                case u8:   current_tag = i32(i);
                case u16:  current_tag = i32(i);
                case u32:  current_tag = i32(i);
                case u64:  current_tag = i32(i);
                case i8:   current_tag = i32(i);
                case i16:  current_tag = i32(i);
                case i32:  current_tag = i32(i);
                case i64:  current_tag = i32(i);
                case: panic(fmt.tprint("Invalid union tag type: ", i));
            }

            item := cast(i32)current_tag;
            v := kind.variants;
            variant_names: [dynamic]string;
            append(&variant_names, "<none>");
            for v in kind.variants {
                append(&variant_names, tprint(v));
            }
            imgui.combo("tag", &item, variant_names[:], cast(i32)min(5, len(variant_names)));

            if item != current_tag {
                current_tag = item;
                // todo(josh): is zeroing a good idea here?
                mem.zero(data, ti.size);
                switch i in tag_any {
                    case u8:   (cast(^u8 )tag_ptr)^ = u8 (item);
                    case u16:  (cast(^u16)tag_ptr)^ = u16(item);
                    case u32:  (cast(^u32)tag_ptr)^ = u32(item);
                    case u64:  (cast(^u64)tag_ptr)^ = u64(item);
                    case i8:   (cast(^i8 )tag_ptr)^ = i8 (item);
                    case i16:  (cast(^i16)tag_ptr)^ = i16(item);
                    case i32:  (cast(^i32)tag_ptr)^ = i32(item);
                    case i64:  (cast(^i64)tag_ptr)^ = i64(item);
                    case: panic(fmt.tprint("Invalid union tag type: ", i));
                }
            }

            if current_tag > 0 {
                data_ti := kind.variants[current_tag-1];
                imgui_struct_ti(name, data, data_ti, "", true, type_name);
            }
        }
        case: imgui.text(tprint("UNHANDLED TYPE: ", kind));
    }
}