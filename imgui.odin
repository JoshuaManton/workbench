package workbench

using import "core:runtime"
using import "core:fmt"

import "core:mem";
import "core:strconv"
using import "core:math";
import "core:os";
import "core:sys/win32"

import    "external/glfw"
import    "external/imgui"
import gl "external/gl"

imgui_program: Shader_Program;

imgui_uniform_texture: Location;
imgui_uniform_projection: Location;

imgui_attrib_position: Location;
imgui_attrib_uv: Location;
imgui_attrib_color: Location;

imgui_vbo_handle: VBO;
imgui_ebo_handle: EBO;

// note(josh): @Cleanup: These are probably duplicates of fonts we already use in the game
imgui_font_default: ^imgui.Font;
imgui_font_mono:    ^imgui.Font;

_init_dear_imgui :: proc() {
    // imgui.create_context();
    io := imgui.get_io();
    io.ime_window_handle = win32.get_desktop_window();

    io.key_map[imgui.Key.Tab]        = i32(Input.Tab);
    io.key_map[imgui.Key.LeftArrow]  = i32(Input.Left);
    io.key_map[imgui.Key.RightArrow] = i32(Input.Right);
    io.key_map[imgui.Key.UpArrow]    = i32(Input.Up);
    io.key_map[imgui.Key.DownArrow]  = i32(Input.Down);
    io.key_map[imgui.Key.PageUp]     = i32(Input.Page_Up);
    io.key_map[imgui.Key.PageDown]   = i32(Input.Page_Down);
    io.key_map[imgui.Key.Home]       = i32(Input.Home);
    io.key_map[imgui.Key.End]        = i32(Input.End);
    io.key_map[imgui.Key.Delete]     = i32(Input.Delete);
    io.key_map[imgui.Key.Backspace]  = i32(Input.Backspace);
    io.key_map[imgui.Key.Enter]      = i32(Input.Enter);
    io.key_map[imgui.Key.Escape]     = i32(Input.Escape);
    io.key_map[imgui.Key.A]          = i32(Input.A);
    io.key_map[imgui.Key.C]          = i32(Input.C);
    io.key_map[imgui.Key.V]          = i32(Input.V);
    io.key_map[imgui.Key.X]          = i32(Input.X);
    io.key_map[imgui.Key.Y]          = i32(Input.Y);
    io.key_map[imgui.Key.Z]          = i32(Input.Z);

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
    imgui_program, ok = load_shader_text(vs, fs);
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

    imgui_font_default = imgui.font_atlas_add_font_from_file_ttf(io.fonts, "resources/fonts/OpenSans-Regular.ttf", 20);
    imgui_font_mono    = imgui.font_atlas_add_font_from_file_ttf(io.fonts, "resources/fonts/Inconsolata.ttf", 16);


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

imgui_begin_new_frame :: proc() {
    io := imgui.get_io();
    io.display_size.x = current_window_width;
    io.display_size.y = current_window_height;

    if window_is_focused {
    	posx, posy := glfw.GetCursorPos(main_window);
        io.mouse_pos.x = cast(f32)posx;
        io.mouse_pos.y = cast(f32)posy;
        io.mouse_down[0] = glfw.GetMouseButton(main_window, cast(glfw.Mouse)Input.Mouse_Left) == glfw.Action.Press;
        io.mouse_down[1] = glfw.GetMouseButton(main_window, cast(glfw.Mouse)Input.Mouse_Right) == glfw.Action.Press;
        io.mouse_down[2] = glfw.GetMouseButton(main_window, cast(glfw.Mouse)Input.Mouse_Middle) == glfw.Action.Press;
        io.mouse_wheel   = cursor_scroll;

        io.key_ctrl  = win32.is_key_down(win32.Key_Code.Lcontrol) || win32.is_key_down(win32.Key_Code.Rcontrol);
        io.key_shift = win32.is_key_down(win32.Key_Code.Lshift)   || win32.is_key_down(win32.Key_Code.Rshift);
        io.key_alt   = win32.is_key_down(win32.Key_Code.Lmenu)    || win32.is_key_down(win32.Key_Code.Rmenu);
        io.key_super = win32.is_key_down(win32.Key_Code.Lwin)     || win32.is_key_down(win32.Key_Code.Rwin);

        for i in 0..511 {
            io.keys_down[i] = get_input(cast(Input)i);
        }
        
    } else {
        io.mouse_pos = imgui.Vec2{-math.F32_MAX, -math.F32_MAX};

        io.mouse_down[0] = false;
        io.mouse_down[1] = false;
        io.mouse_down[2] = false;
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
    io.delta_time = fixed_delta_time;
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

    _imgui_struct_internal("", value, type_info_of(T));
}

imgui_struct :: inline proc(value: ^$T, name: string) {
    imgui.push_font(imgui_font_mono);
    defer imgui.pop_font();

    _imgui_struct_internal(name, value, type_info_of(T));
}

_imgui_struct_block_field_start :: proc(name: string, typename: string) -> bool {
    if name != "" {
        if imgui.collapsing_header(tprint(name, ": ", typename, " {")) {
            imgui.indent();
            return true;
        }
        else {
            imgui.same_line();
            imgui.text(" ... }");
        }
        return false;
    }
    return true;
}
_imgui_struct_block_field_end :: proc(name: string) {
    if name != "" {
        imgui.unindent();
        imgui.text("}");
    }
}

_imgui_struct_internal :: proc(name: string, data: rawptr, ti: ^Type_Info, type_name: string = "") {
    simple_field :: proc(name: string, data: rawptr, $T: typeid) {
        value: string;

        _, is_pointer := type_info_of(T).variant.(Type_Info_Pointer);
        if T == string {
            value = tprint("\"", (cast(^T)data)^, "\"");
        }
        else if T == f32 || T == f64 {
            value = tprintf("%.8f", (cast(^T)data)^,);
        }
        else if is_pointer && (cast(^^byte)data)^ == nil {
            value = "nil";
        }
        else {
            value = tprint((cast(^T)data)^);
        }

        result := tprint(name, " = ", value);
        imgui.text(result);
    }

    switch kind in ti.variant {
        case Type_Info_Integer: {
            if kind.signed {
                switch ti.size {
                    case 8: simple_field(name, data, i64);
                    case 4: simple_field(name, data, i32);
                    case 2: simple_field(name, data, i16);
                    case 1: simple_field(name, data, i8);
                    case: assert(false, tprint(ti.size));
                }
            }
            else {
                switch ti.size {
                    case 8: simple_field(name, data, u64);
                    case 4: simple_field(name, data, u32);
                    case 2: simple_field(name, data, u16);
                    case 1: simple_field(name, data, u8);
                    case: assert(false, tprint(ti.size));
                }
            }
        }
        case Type_Info_Float: {
            switch ti.size {
                case 8: simple_field(name, data, f64);
                case 4: simple_field(name, data, f32);
                case: assert(false, tprint(ti.size));
            }
        }
        case Type_Info_String: {
            assert(ti.size == size_of(string));
            simple_field(name, data, string);
        }
        case Type_Info_Boolean: {
            assert(ti.size == size_of(bool));
            simple_field(name, data, bool);
        }
        case Type_Info_Pointer: {
            simple_field(name, data, ^byte);
        }
        case Type_Info_Named: {
            _imgui_struct_internal(name, data, kind.base, kind.name);
        }
        case Type_Info_Struct: {
            if _imgui_struct_block_field_start(name, type_name) {
                defer _imgui_struct_block_field_end(name);
                for field_name, i in kind.names {
                    t := kind.types[i];
                    offset := kind.offsets[i];
                    data := mem.ptr_offset(cast(^byte)data, cast(int)offset);
                    _imgui_struct_internal(field_name, data, t);
                }
            }
        }
        case Type_Info_Enum: {
            for value, val_idx in kind.values {
                switch kind3 in value {
                    case i8:  if (cast(^i8) data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                    case i16: if (cast(^i16)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                    case i32: if (cast(^i32)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                    case i64: if (cast(^i64)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                    case int: if (cast(^int)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                    case u8:  if (cast(^u8) data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                    case u16: if (cast(^u16)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                    case u32: if (cast(^u32)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                    case u64: if (cast(^u64)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                }
            }
        }
        case Type_Info_Slice: {
            if _imgui_struct_block_field_start(name, tprint("[]", kind.elem)) {
                defer _imgui_struct_block_field_end(name);

                slice := (cast(^mem.Raw_Slice)data)^;
                for i in 0..slice.len-1 {
                    imgui.push_id(tprint(i));
                    defer imgui.pop_id();
                    _imgui_struct_internal(tprint("[", i, "]"), mem.ptr_offset(cast(^byte)slice.data, i * kind.elem_size), kind.elem);
                }
            }
        }
        case Type_Info_Array: {
            if _imgui_struct_block_field_start(name, tprint("[", kind.count, "]", kind.elem)) {
                defer _imgui_struct_block_field_end(name);

                for i in 0..kind.count-1 {
                    imgui.push_id(tprint(i));
                    defer imgui.pop_id();
                    _imgui_struct_internal(tprint("[", i, "]"), mem.ptr_offset(cast(^byte)data, i * kind.elem_size), kind.elem);
                }
            }
        }
        case Type_Info_Dynamic_Array: {
            if _imgui_struct_block_field_start(name, tprint("[dynamic]", kind.elem)) {
                defer _imgui_struct_block_field_end(name);

                array := (cast(^mem.Raw_Dynamic_Array)data)^;
                for i in 0..array.len-1 {
                    imgui.push_id(tprint(i));
                    defer imgui.pop_id();
                    _imgui_struct_internal(tprint("[", i, "]"), mem.ptr_offset(cast(^byte)array.data, i * kind.elem_size), kind.elem);
                }
            }
        }
        case: imgui.text(tprint("UNHANDLED TYPE: ", kind));
    }
}

Node_Editor_Data :: struct {
    show_grid : bool,
    node_selected : int,
    scrolling : Vec2,
    open_context_menu : bool,
    node_hovered_in_list : int,
    node_hovered_in_scene : int
}

MAX_CONNECTIONS :: 5;
Node :: struct {
    id      : int,
    name    : string,
    pos     : Vec2,
    size    : Vec2,
    inputs  : [5]int,
    outputs : [5]int,

    derived : any,
}

get_input_slot_pos :: inline proc(using node : Node, slot_num : int) -> Vec2 {
    return Vec2{
        pos.x, 
        pos.y + size.y * (f32(slot_num) + 1) / (f32(len(inputs)) + 1)};
}

get_output_slot_pos :: inline proc(using node : Node, slot_num : int) -> Vec2 {
    return Vec2{
        pos.x + size.x, 
        pos.y + size.y * (f32(slot_num) + 1) / (f32(len(outputs)) + 1)};
}

NODE_SLOT_RADIUS : f32 = 4.0;
NODE_WINDOW_PADDING := Vec2{8.0, 8.0};
all_node_editor_data : map[string]Node_Editor_Data;
imgui_node_editor :: proc(name : string, nodes : map[int]Node) {

    simple_field :: proc(name: string, data: rawptr, $T: typeid) {
        value: string;

        _, is_pointer := type_info_of(T).variant.(Type_Info_Pointer);

        if T == string {
            value = tprint("\"", (cast(^T)data)^, "\"");
        }
        else if T == f32 || T == f64 {
            value = tprintf("%.2f", (cast(^T)data)^,);
        }
        else if is_pointer && (cast(^^byte)data)^ == nil {
            value = "nil";
        }
        else {
            value = tprint((cast(^T)data)^);
        }

        result := tprint(name, " = ", value);
        logln(result);
        imgui.text(result);
    }

    draw_node_recursive :: proc(name : string, any_data : any) {
        data := any_data.data;
        ti := type_info_of(any_data.id);
        switch kind in ti.variant {
            case Type_Info_Integer: {
                if kind.signed {
                    switch ti.size {
                        case 8: simple_field(name, data, i64);
                        case 4: simple_field(name, data, i32);
                        case 2: simple_field(name, data, i16);
                        case 1: simple_field(name, data, i8);
                        case: assert(false, tprint(ti.size));
                    }
                }
                else {
                    switch ti.size {
                        case 8: simple_field(name, data, u64);
                        case 4: simple_field(name, data, u32);
                        case 2: simple_field(name, data, u16);
                        case 1: simple_field(name, data, u8);
                        case: assert(false, tprint(ti.size));
                    }
                }
            }
            case Type_Info_Float: {
                switch ti.size {
                    case 8: simple_field(name, data, f64);
                    case 4: simple_field(name, data, f32);
                    case: assert(false, tprint(ti.size));
                }
            }
            case Type_Info_String: {
                assert(ti.size == size_of(string));
                simple_field(name, data, string);
            }
            case Type_Info_Boolean: {
                assert(ti.size == size_of(bool));
                simple_field(name, data, bool);
            }
            case Type_Info_Pointer: {
                simple_field(name, data, ^byte);
            }
            case Type_Info_Named: {
                draw_node_recursive(name, any{data, kind.base.id});
            }
            case Type_Info_Struct: {
                imgui.indent(); {
                    defer imgui.unindent();
                    for field_name, i in kind.names {
                        t := kind.types[i];
                        offset := kind.offsets[i];
                        data := mem.ptr_offset(cast(^byte)data, cast(int)offset);
                        draw_node_recursive(field_name, any{data, t.id});
                    }
                }
            }
            case Type_Info_Enum: {
                for value, val_idx in kind.values {
                    switch kind3 in value {
                        case i8:  if (cast(^i8) data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                        case i16: if (cast(^i16)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                        case i32: if (cast(^i32)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                        case i64: if (cast(^i64)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                        case int: if (cast(^int)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                        case u8:  if (cast(^u8) data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                        case u16: if (cast(^u16)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                        case u32: if (cast(^u32)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                        case u64: if (cast(^u64)data)^ == kind3 do simple_field(name, &kind.names[val_idx], string);
                    }
                }
            }
            case Type_Info_Slice: {
                {//if _imgui_struct_block_field_start(name, tprint("[]", kind.elem)) {
                   // defer _imgui_struct_block_field_end(name);

                    slice := (cast(^mem.Raw_Slice)data)^;
                    for i in 0..slice.len-1 {
                        imgui.push_id(tprint(i));
                        defer imgui.pop_id();
                        draw_node_recursive(tprint("[", i, "]"), any{mem.ptr_offset(cast(^byte)slice.data, i * kind.elem_size), kind.elem.id});
                    }
                }
            }
            case Type_Info_Array: {
                {//if _imgui_struct_block_field_start(name, tprint("[", kind.count, "]", kind.elem)) {
                  //  defer _imgui_struct_block_field_end(name);

                    for i in 0..kind.count-1 {
                        imgui.push_id(tprint(i));
                        defer imgui.pop_id();
                        draw_node_recursive(tprint("[", i, "]"), any{mem.ptr_offset(cast(^byte)data, i * kind.elem_size), kind.elem.id});
                    }
                }
            }
            case Type_Info_Dynamic_Array: {
                {//if _imgui_struct_block_field_start(name, tprint("[dynamic]", kind.elem)) {
                   // defer _imgui_struct_block_field_end(name);

                    array := (cast(^mem.Raw_Dynamic_Array)data)^;
                    for i in 0..array.len-1 {
                        imgui.push_id(tprint(i));
                        defer imgui.pop_id();
                        draw_node_recursive(tprint("[", i, "]"), any{mem.ptr_offset(cast(^byte)array.data, i * kind.elem_size), kind.elem.id});
                    }
                }
            }
            case: imgui.text(tprint("UNHANDLED TYPE: ", kind));
        }
    }

    draw_node :: proc(node : Node) {
        draw_node_recursive(node.name, node.derived);
    }

    node_editor_data, ok := all_node_editor_data[name];
    defer all_node_editor_data[name] = node_editor_data;
    if !ok {
        node_editor_data = Node_Editor_Data{false, -1, {0,0}, false, -1, -1};
    }

    using node_editor_data;

    if imgui.begin(name) {
        defer imgui.end();

        imgui.begin_child("NodeList", {100,0}); {
            defer imgui.end_child();
            
            imgui.text("Nodes");
            imgui.separator();
            for _, node in nodes {
                imgui.push_id(node.id);
                defer imgui.pop_id();

                if imgui.selectable(node.name, node.id == node_selected) do
                    node_selected = node.id;

                if imgui.is_item_hovered() {
                    node_hovered_in_list = node.id;
                    open_context_menu |= imgui.is_mouse_clicked(1, false);
                }
            }
        }

        imgui.same_line();
        imgui.begin_group(); {
            defer imgui.end_group();

            imgui.text("Hold right mouse to scroll (%.2f, %.2f)", scrolling.x, scrolling.y);
            imgui.same_line(imgui.get_window_width() - 100);
            imgui.checkbox("Show Grid", &show_grid);
            
            imgui.push_style_var(imgui.Style_Var.FramePadding, imgui.Vec2{1,1});
            defer imgui.pop_style_var();
            
            imgui.push_style_var(imgui.Style_Var.WindowPadding, imgui.Vec2{0,0});
            defer imgui.pop_style_var();
            
            imgui.push_style_color(imgui.Color.ChildWindowBg, imgui.Vec4{0.1,0.1,0.12,0.9});
            defer imgui.pop_style_color();

            imgui.begin_child("Scrolling Region", {0,0}, true, imgui.Window_Flags.NoScrollbar | imgui.Window_Flags.NoMove); {
                defer imgui.end_child();
                
                imgui.push_item_width(120);
                defer imgui.pop_item_width();

                cursor_pos := imgui.get_cursor_screen_pos();
                offset := Vec2{cursor_pos.x, cursor_pos.y};
                offset.x = offset.x + scrolling.x;
                offset.y = offset.y + scrolling.y;

                draw_list := imgui.get_window_draw_list();
                if show_grid {
                    colr := imgui.Vec4{0.6,0.6,0.6,0.3};
                    grid_color := imgui.color_convert_float4_to_u32(colr);
                    grid_size : f32 = 64.0;
                    win_pos := cursor_pos;
                    canvas_size := imgui.get_window_size();

                    for x := mod_f32(scrolling.x, grid_size); x < canvas_size.x; x += grid_size{
                        imgui.draw_list_add_line(draw_list, 
                            {win_pos.x + x, win_pos.y}, 
                            {x + win_pos.x, canvas_size.y + win_pos.y}, 
                            grid_color, 
                            0.5);
                    }

                    for y := mod_f32(scrolling.y, grid_size); y < canvas_size.y; y += grid_size{
                        imgui.draw_list_add_line(draw_list, 
                            {win_pos.x, win_pos.y + y}, 
                            {canvas_size.x + win_pos.x, y + win_pos.y}, 
                            grid_color, 
                            0.5);
                    }
                }

                imgui.draw_list_channels_split(draw_list, 2);
                imgui.draw_list_channels_set_current(draw_list, 0);

                for id, _ in nodes {
                    node := nodes[id];
                    defer nodes[id] = node;


                    for target, link_slot in node.inputs {
                        if target < 0 do break;
                        input_node := nodes[target];
                        output_node := node;

                        input_slot := 0;
                        for t,s in input_node.outputs {
                            if t == node.id {
                                input_slot = s;
                                break;
                            }
                        }

                        _p1 := offset + get_output_slot_pos(input_node, input_slot);
                        _p2 := offset + get_input_slot_pos(output_node, link_slot);
                        
                        p1a : imgui.Vec2 = imgui.Vec2{_p1.x, _p1.y};
                        p1b : imgui.Vec2 = imgui.Vec2{p1a.x + 50, p1a.y};
                        p2a : imgui.Vec2 = imgui.Vec2{_p2.x, _p2.y};
                        p2b : imgui.Vec2 = imgui.Vec2{p2a.x - 50, p2a.y};

                        colr := imgui.Vec4{0.7,0.5,0.0,1};

                        imgui.draw_list_add_bezier_curve(
                            draw_list, p1a, p1b, p2b, p2a, imgui.color_convert_float4_to_u32(colr), 2.0, 20);
                    }

                    imgui.push_id(node.id);
                    defer imgui.pop_id();

                    node_rect_min := offset + node.pos;
                    imgui.draw_list_channels_set_current(draw_list, 1);
                    old_any_active := imgui.is_any_item_active();
                    imgui.set_cursor_screen_pos({node_rect_min.x + NODE_WINDOW_PADDING.x, node_rect_min.y + NODE_WINDOW_PADDING.y});

                    imgui.begin_group(); {
                        defer imgui.end_group();
                        imgui.text("%s", node.name);
                        draw_node(node);
                    }

                    node_widgets_active := !old_any_active && imgui.is_any_item_active();
                    rect_size : imgui.Vec2;
                    imgui.get_item_rect_size(&rect_size);
                    node.size = Vec2{rect_size.x + (NODE_WINDOW_PADDING.x * 2), rect_size.y + (NODE_WINDOW_PADDING.y * 2)};
                    node_rect_max := node_rect_min + node.size;

                    imgui.draw_list_channels_set_current(draw_list, 0);
                    imgui.set_cursor_screen_pos(imgui.Vec2{node_rect_min.x, node_rect_min.y});
                    imgui.invisible_button("node", imgui.Vec2{node.size.x, node.size.y});
                    if imgui.is_item_hovered() {
                        node_hovered_in_scene = node.id;
                        open_context_menu |= imgui.is_mouse_clicked(1, false);
                    }

                    node_moving_active := imgui.is_item_active();
                    if node_widgets_active || node_moving_active do
                        node_selected = node.id;
                    if node_moving_active && imgui.is_mouse_dragging()
                    {
                        mouse_delta := imgui.get_io().mouse_delta;
                        node.pos = node.pos + Vec2{mouse_delta.x, mouse_delta.y};
                    }

                    node_bg_color : u32;
                    col1 := imgui.Vec4{0.4,0.4,0.4,1};
                    col2 := imgui.Vec4{0.35,0.35,0.35,1};
                    if (node_hovered_in_list == node.id || 
                        node_hovered_in_scene == node.id || 
                        (node_hovered_in_list == -1 && node_selected == node.id)) do node_bg_color = imgui.color_convert_float4_to_u32(col1); 
                    else do node_bg_color = imgui.color_convert_float4_to_u32(col2);

                    col3 := imgui.Vec4{0.5,0.5,0.5,1};
                    imgui.draw_list_add_rect_filled(draw_list, {node_rect_min.x, node_rect_min.y}, {node_rect_max.x, node_rect_max.y}, node_bg_color, 4.0, 2.0);
                    imgui.draw_list_add_rect(draw_list, {node_rect_min.x, node_rect_min.y}, {node_rect_max.x, node_rect_max.y}, imgui.color_convert_float4_to_u32(col3), 4.0, 2.0, 2.0);
                    
                    for slot_idx in 0 .. len(node.inputs)-1 {
                        col := imgui.Vec4{0.6,0.6,0.6,1};
                        p := offset + get_input_slot_pos(node, slot_idx);
                        imgui.draw_list_add_circle_filled(draw_list, imgui.Vec2{p.x, p.y}, NODE_SLOT_RADIUS, imgui.color_convert_float4_to_u32(col), 10);
                    }

                    for slot_idx in 0 .. len(node.outputs)-1 {
                        col := imgui.Vec4{0.6,0.6,0.6,1};
                        p := offset + get_output_slot_pos(node, slot_idx);
                        imgui.draw_list_add_circle_filled(draw_list, imgui.Vec2{p.x, p.y}, NODE_SLOT_RADIUS, imgui.color_convert_float4_to_u32(col), 10);
                    }
                }

                imgui.draw_list_channels_merge(draw_list);

                // if !imgui.is_any_item_hovered() && imgui.is_mouse_clicked(1, false) {
                //  node_selected = -1; 
                //  node_hovered_in_list = -1;
                //  node_hovered_in_scene = -1;
                //  open_context_menu = true;
                // }

                // if open_context_menu {
                //  imgui.open_popup("context_menu");
                //  if node_hovered_in_list != -1 do node_selected = node_hovered_in_list;
                //  if node_hovered_in_scene != -1 do node_selected = node_hovered_in_scene;
                // }

                // imgui.push_style_var(imgui.Style_Var.WindowPadding, imgui.Vec2{8,8});
                // defer imgui.pop_style_var();

                // if imgui.begin_popup("context_menu") {
                //  defer imgui.end_popup();

                //  node, ok := nodes[node_selected];
                //  _scene_pos : imgui.Vec2;
                //  imgui.get_mouse_pos_on_opening_current_popup(&_scene_pos);
                //  scene_pos := Vec2{_scene_pos.x - offset.x, _scene_pos.y - offset.y};
                //  if ok {
                //      imgui.text("Node '%s", node.name);
                //      imgui.separator();
                //      if imgui.menu_item("Rename..", "", nil, false) {}
                //      if imgui.menu_item("Delete", "", nil, false) {}
                //      if imgui.menu_item("Copy", "", nil, false) {}
                //  } else {
                //      if imgui.menu_item("Add") {
                //          current_node_num += 1;
                //          nodes[current_node_num] = Node{current_node_num, "New Node", scene_pos, Vec2{50,50}, 0.5, {0.5,0.5,0.5}, 0,0};
                //      }
                //      if imgui.menu_item("Paste", "", nil, false) {}
                //  }
                // }

                if imgui.is_window_hovered() && !imgui.is_any_item_active() && imgui.is_mouse_dragging(2, 0.1) {
                    mouse_delta := imgui.get_io().mouse_delta;
                    scrolling = scrolling + Vec2{mouse_delta.x,mouse_delta.y};
                }
            }
        }
    }
}