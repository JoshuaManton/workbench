/*
 *  @Name:     imgui
 *
 *  @Author:   Mikkel Hjortshoej
 *  @Email:    hjortshoej@handmade.network
 *  @Creation: 10-06-2017 18:33:45
 *
 *  @Last By:   Joshua Manton
 *  @Last Time: 13-09-2018 21:57:51 UTC-8
 *
 *  @Description:
 *
 */
package workbench

import "core:fmt";
import "core:mem";
import "core:math";
import "core:os";
import "core:sys/win32"

import    "shared:workbench/glfw"
import    "shared:odin-imgui"
import gl "shared:odin-gl"

default_font  : ^imgui.Font;
mono_font     : ^imgui.Font;


State :: struct {
    //Misc
    mouse_wheel_delta : i32,

    //Render
    main_program      : Shader_Program,
    vbo_handle        : VBO,
    ebo_handle        : EBO,
}

FrameState :: struct {
    deltatime     : f32,
    window_width  : int,
    window_height : int,
    window_focus  : bool,
    mouse_x       : int,
    mouse_y       : int,
    mouse_wheel   : int,
    left_mouse    : bool,
    right_mouse   : bool,
}

imgui_program: Shader_Program;

imgui_uniform_texture: Location;
imgui_uniform_projection: Location;

imgui_attrib_position: Location;
imgui_attrib_uv: Location;
imgui_attrib_color: Location;

imgui_vbo_handle: VBO;
imgui_ebo_handle: EBO;



_init_dear_imgui :: proc() {
    // imgui.create_context();
    io := imgui.get_io();
    io.ime_window_handle = win32.get_desktop_window();

    io.key_map[imgui.Key.Tab]        = i32(Key.Tab);
    io.key_map[imgui.Key.LeftArrow]  = i32(Key.Left);
    io.key_map[imgui.Key.RightArrow] = i32(Key.Right);
    io.key_map[imgui.Key.UpArrow]    = i32(Key.Up);
    io.key_map[imgui.Key.DownArrow]  = i32(Key.Down);
    io.key_map[imgui.Key.PageUp]     = i32(Key.Page_Up);
    io.key_map[imgui.Key.PageDown]   = i32(Key.Page_Down);
    io.key_map[imgui.Key.Home]       = i32(Key.Home);
    io.key_map[imgui.Key.End]        = i32(Key.End);
    io.key_map[imgui.Key.Delete]     = i32(Key.Delete);
    io.key_map[imgui.Key.Backspace]  = i32(Key.Backspace);
    io.key_map[imgui.Key.Enter]      = i32(Key.Enter);
    io.key_map[imgui.Key.Escape]     = i32(Key.Escape);
    io.key_map[imgui.Key.A]          = i32(Key.A);
    io.key_map[imgui.Key.C]          = i32(Key.C);
    io.key_map[imgui.Key.V]          = i32(Key.V);
    io.key_map[imgui.Key.X]          = i32(Key.X);
    io.key_map[imgui.Key.Y]          = i32(Key.Y);
    io.key_map[imgui.Key.Z]          = i32(Key.Z);

    vertexShaderString ::
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

    fragmentShaderString ::
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
    imgui_program, ok = load_shader_text(vertexShaderString, fragmentShaderString);
    assert(ok);

    imgui_uniform_texture    = get_uniform_location(imgui_program, "Texture");
    imgui_uniform_projection = get_uniform_location(imgui_program, "ProjMtx");

    imgui_attrib_position = get_attrib_location(imgui_program, "Position");
    imgui_attrib_uv       = get_attrib_location(imgui_program, "UV");
    imgui_attrib_color    = get_attrib_location(imgui_program, "Color");

    imgui_vbo_handle = cast(VBO)gen_buffer();
    imgui_ebo_handle = cast(EBO)gen_buffer();

    bind_buffer(imgui_vbo_handle);
    bind_buffer(imgui_ebo_handle);


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

    tex := gen_texture();
    bind_texture2d(tex);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA,
                  width, height, 0, gl.RGBA, // todo(josh): @Incomplete: Make sure the 0 on this line, and the RGBA things are right
                  gl.UNSIGNED_BYTE, pixels);

    imgui.font_atlas_set_text_id(io.fonts, rawptr(uintptr(uint(tex))));

    //
    // Style
    //

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

imgui_begin_new_frame :: proc() {
    io := imgui.get_io();
    io.display_size.x = current_window_width;
    io.display_size.y = current_window_height;

    if window_is_focused {
    	posx, posy := glfw.GetCursorPos(main_window);
        io.mouse_pos.x = cast(f32)posx;
        io.mouse_pos.y = cast(f32)posy;
        io.mouse_down[0] = get_mouse(Mouse.Left);
        io.mouse_down[1] = get_mouse(Mouse.Right);
        io.mouse_wheel   = cursor_scroll;

        io.key_ctrl  = win32.is_key_down(win32.Key_Code.Lcontrol) || win32.is_key_down(win32.Key_Code.Rcontrol);
        io.key_shift = win32.is_key_down(win32.Key_Code.Lshift)   || win32.is_key_down(win32.Key_Code.Rshift);
        io.key_alt   = win32.is_key_down(win32.Key_Code.Lmenu)    || win32.is_key_down(win32.Key_Code.Rmenu);
        io.key_super = win32.is_key_down(win32.Key_Code.Lwin)     || win32.is_key_down(win32.Key_Code.Rwin);

        for i in 0..256 {
            io.keys_down[i] = win32.is_key_down(win32.Key_Code(i));
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

        for i in 0..256 {
            io.keys_down[i] = false;
        }
    }

    // ctx.imgui_state.mouse_wheel_delta = 0;
    io.delta_time = client_target_delta_time;
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

    cull    := get_int(gl.CULL_FACE);
    depth   := get_int(gl.DEPTH_TEST);
    scissor := get_int(gl.SCISSOR_TEST);
    blend   := get_int(gl.BLEND);

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

    old_program := get_current_shader();
    defer use_program(old_program);

    use_program(imgui_program);
    uniform(imgui_program, "Texture", i32(0));
    uniform_matrix4fv(imgui_program, "ProjMtx", 1, false, &ortho_projection[0][0]);

    vao_handle := gen_vao();
    bind_vao(vao_handle);
    bind_buffer(imgui_vbo_handle);

    gl.EnableVertexAttribArray(cast(u32)imgui_attrib_position);
    gl.EnableVertexAttribArray(cast(u32)imgui_attrib_uv);
    gl.EnableVertexAttribArray(cast(u32)imgui_attrib_color);

    gl.VertexAttribPointer(cast(u32)imgui_attrib_position, 2, gl.FLOAT,         gl.FALSE, size_of(imgui.DrawVert), cast(rawptr)offset_of(imgui.DrawVert, pos));
    gl.VertexAttribPointer(cast(u32)imgui_attrib_uv,       2, gl.FLOAT,         gl.FALSE, size_of(imgui.DrawVert), cast(rawptr)offset_of(imgui.DrawVert, uv));
    gl.VertexAttribPointer(cast(u32)imgui_attrib_color,    4, gl.UNSIGNED_BYTE, gl.TRUE,  size_of(imgui.DrawVert), cast(rawptr)offset_of(imgui.DrawVert, col));

    new_list := mem.slice_ptr(data.cmd_lists, int(data.cmd_lists_count));
    for list in new_list {
        idx_buffer_offset : ^imgui.DrawIdx = nil;

        bind_buffer(imgui_vbo_handle);
        gl.BufferData(gl.ARRAY_BUFFER,
                       cast(int)(imgui.draw_list_get_vertex_buffer_size(list) * size_of(imgui.DrawVert)),
                       imgui.draw_list_get_vertex_ptr(list, 0),
                       gl.STREAM_DRAW);

        bind_buffer(imgui_ebo_handle);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER,
                       cast(int)(imgui.draw_list_get_index_buffer_size(list) * size_of(imgui.DrawIdx)),
                       imgui.draw_list_get_index_ptr(list, 0),
                       gl.STREAM_DRAW);

        for j : i32 = 0; j < imgui.draw_list_get_cmd_size(list); j += 1 {
            cmd := imgui.draw_list_get_cmd_ptr(list, j);
            bind_texture2d(Texture(uint(uintptr(cmd.texture_id))));
            gl.Scissor(i32(cmd.clip_rect.x), height - i32(cmd.clip_rect.w), i32(cmd.clip_rect.z - cmd.clip_rect.x), i32(cmd.clip_rect.w - cmd.clip_rect.y));
            gl.DrawElements(gl.TRIANGLES, i32(cmd.elem_count), gl.UNSIGNED_SHORT, idx_buffer_offset);
            //idx_buffer_offset += cmd.elem_count;
            idx_buffer_offset = mem.ptr_offset(idx_buffer_offset, int(cmd.elem_count));

        }
    }

    delete_vao(vao_handle);

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
    return imgui.begin(label, nil, imgui.Window_Flags.NoTitleBar            |
                             imgui.Window_Flags.NoMove                |
                             imgui.Window_Flags.NoResize              |
                             imgui.Window_Flags.NoBringToFrontOnFocus);
}

columns_reset :: proc() {
    imgui.columns(count = 1, border = false);
}