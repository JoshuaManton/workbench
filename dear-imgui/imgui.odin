/*
 *  @Name:     brew_imgui
 *
 *  @Author:   Mikkel Hjortshoej
 *  @Email:    hjortshoej@handmade.network
 *  @Creation: 10-06-2017 18:33:45
 *
 *  @Last By:   Joshua Manton
 *  @Last Time: 13-09-2018 18:50:50 UTC-8
 *
 *  @Description:
 *
 */
package dear_imgui

import "core:fmt";
import "core:mem";
import "core:math";
import "core:os";
import "core:sys/win32"

import "shared:odin-imgui"

default_font  : ^imgui.Font;
mono_font     : ^imgui.Font;


State :: struct {
    //Misc
    mouse_wheel_delta : i32,

    //Render
    main_program      : gl.Program,
    vbo_handle        : gl.VBO,
    ebo_handle        : gl.EBO,
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


brew_style :: proc() {
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

    style.colors[imgui.Style_Color.Text]                  = imgui.Vec4{1.00, 1.00, 1.00, 1.00};
    style.colors[imgui.Style_Color.TextDisabled]          = imgui.Vec4{0.63, 0.63, 0.63, 1.00};
    style.colors[imgui.Style_Color.WindowBg]              = imgui.Vec4{0.23, 0.23, 0.23, 0.98};
    style.colors[imgui.Style_Color.ChildBg]               = imgui.Vec4{0.20, 0.20, 0.20, 1.00};
    style.colors[imgui.Style_Color.PopupBg]               = imgui.Vec4{0.25, 0.25, 0.25, 0.96};
    style.colors[imgui.Style_Color.Border]                = imgui.Vec4{0.18, 0.18, 0.18, 0.98};
    style.colors[imgui.Style_Color.BorderShadow]          = imgui.Vec4{0.00, 0.00, 0.00, 0.04};
    style.colors[imgui.Style_Color.FrameBg]               = imgui.Vec4{0.00, 0.00, 0.00, 0.29};
    style.colors[imgui.Style_Color.TitleBg]               = imgui.Vec4{0.25, 0.25, 0.25, 0.98};
    style.colors[imgui.Style_Color.TitleBgCollapsed]      = imgui.Vec4{0.12, 0.12, 0.12, 0.49};
    style.colors[imgui.Style_Color.TitleBgActive]         = imgui.Vec4{0.33, 0.33, 0.33, 0.98};
    style.colors[imgui.Style_Color.MenuBarBg]             = imgui.Vec4{0.11, 0.11, 0.11, 0.42};
    style.colors[imgui.Style_Color.ScrollbarBg]           = imgui.Vec4{0.00, 0.00, 0.00, 0.08};
    style.colors[imgui.Style_Color.ScrollbarGrab]         = imgui.Vec4{0.27, 0.27, 0.27, 1.00};
    style.colors[imgui.Style_Color.ScrollbarGrabHovered]  = imgui.Vec4{0.78, 0.78, 0.78, 0.40};
    style.colors[imgui.Style_Color.CheckMark]             = imgui.Vec4{0.78, 0.78, 0.78, 0.94};
    style.colors[imgui.Style_Color.SliderGrab]            = imgui.Vec4{0.78, 0.78, 0.78, 0.94};
    style.colors[imgui.Style_Color.Button]                = imgui.Vec4{0.42, 0.42, 0.42, 0.60};
    style.colors[imgui.Style_Color.ButtonHovered]         = imgui.Vec4{0.78, 0.78, 0.78, 0.40};
    style.colors[imgui.Style_Color.Header]                = imgui.Vec4{0.31, 0.31, 0.31, 0.98};
    style.colors[imgui.Style_Color.HeaderHovered]         = imgui.Vec4{0.78, 0.78, 0.78, 0.40};
    style.colors[imgui.Style_Color.HeaderActive]          = imgui.Vec4{0.80, 0.50, 0.50, 1.00};
    style.colors[imgui.Style_Color.TextSelectedBg]        = imgui.Vec4{0.65, 0.35, 0.35, 0.26};
    style.colors[imgui.Style_Color.ModalWindowDimBg]      = imgui.Vec4{0.20, 0.20, 0.20, 0.35};
}

init :: proc(state : ^State, wnd_handle : sys.WndHandle, style_proc : proc() = nil, custom_font := false) {
    imgui.create_context();
    io := imgui.get_io();
    io.ime_window_handle = wnd_handle;

    io.key_map[imgui.Key.Tab]        = i32(sys.VirtualKey.Tab);
    io.key_map[imgui.Key.LeftArrow]  = i32(sys.VirtualKey.Left);
    io.key_map[imgui.Key.RightArrow] = i32(sys.VirtualKey.Right);
    io.key_map[imgui.Key.UpArrow]    = i32(sys.VirtualKey.Up);
    io.key_map[imgui.Key.DownArrow]  = i32(sys.VirtualKey.Down);
    io.key_map[imgui.Key.PageUp]     = i32(sys.VirtualKey.Next);
    io.key_map[imgui.Key.PageDown]   = i32(sys.VirtualKey.Prior);
    io.key_map[imgui.Key.Home]       = i32(sys.VirtualKey.Home);
    io.key_map[imgui.Key.End]        = i32(sys.VirtualKey.End);
    io.key_map[imgui.Key.Delete]     = i32(sys.VirtualKey.Delete);
    io.key_map[imgui.Key.Backspace]  = i32(sys.VirtualKey.Back);
    io.key_map[imgui.Key.Enter]      = i32(sys.VirtualKey.Return);
    io.key_map[imgui.Key.Escape]     = i32(sys.VirtualKey.Escape);
    io.key_map[imgui.Key.A]          = i32(sys.VirtualKey.A);
    io.key_map[imgui.Key.C]          = i32(sys.VirtualKey.C);
    io.key_map[imgui.Key.V]          = i32(sys.VirtualKey.V);
    io.key_map[imgui.Key.X]          = i32(sys.VirtualKey.X);
    io.key_map[imgui.Key.Y]          = i32(sys.VirtualKey.Y);
    io.key_map[imgui.Key.Z]          = i32(sys.VirtualKey.Z);

    vertexShaderString ::
        `#version 130
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
        `#version 130
        uniform sampler2D Texture;
        in vec2 Frag_UV;
        in vec4 Frag_Color;
        out vec4 Out_Color;
        void main()
        {
           Out_Color = Frag_Color * texture( Texture, Frag_UV.st);
        }`;

    state.main_program    = gl.create_program();
    vertex_shader := gl.create_shader(gl.ShaderTypes.Vertex);
    gl.shader_source(vertex_shader, vertexShaderString);
    gl.compile_shader(vertex_shader);

    fragment_shader := gl.create_shader(gl.ShaderTypes.Fragment);
    gl.shader_source(fragment_shader, fragmentShaderString);
    gl.compile_shader(fragment_shader);
    gl.attach_shader(state.main_program, vertex_shader);
    state.main_program.vertex = vertex_shader;
    gl.attach_shader(state.main_program, fragment_shader);
    state.main_program.fragment = fragment_shader;
    gl.link_program(state.main_program);

    state.main_program.uniforms["Texture"] = gl.get_uniform_by_name(state.main_program, "Texture");
    state.main_program.uniforms["ProjMtx"] = gl.get_uniform_by_name(state.main_program, "ProjMtx");

    state.main_program.attributes["Position"] = gl.get_attrib_by_name(state.main_program, "Position");
    state.main_program.attributes["UV"]       = gl.get_attrib_by_name(state.main_program, "UV");
    state.main_program.attributes["Color"]    = gl.get_attrib_by_name(state.main_program, "Color");

    state.vbo_handle = gl.VBO(gl.gen_buffer());
    state.ebo_handle = gl.EBO(gl.gen_buffer());
    gl.bind_buffer(state.vbo_handle);
    gl.bind_buffer(state.ebo_handle);


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

    tex := gl.gen_texture();
    gl.bind_texture(gl.TextureTargets.Texture2D, tex);

    gl.tex_parameteri(gl.TextureTargets.Texture2D, gl.TextureParameters.MinFilter, gl.TextureParametersValues.Linear);
    gl.tex_parameteri(gl.TextureTargets.Texture2D, gl.TextureParameters.MagFilter, gl.TextureParametersValues.Linear);
    gl.tex_image2d(gl.TextureTargets.Texture2D, 0, gl.InternalColorFormat.RGBA,
                  width, height, gl.PixelDataFormat.RGBA,
                  gl.Texture2DDataType.UByte, pixels);
    imgui.font_atlas_set_text_id(io.fonts, rawptr(uintptr(uint(tex))));
    if style_proc != nil {
        style_proc();
    }
}

begin_new_frame :: proc(new_state : ^FrameState) {
    io := imgui.get_io();
    io.display_size.x = f32(new_state.window_width);
    io.display_size.y = f32(new_state.window_height);

    if new_state.window_focus {
        io.mouse_pos.x = f32(new_state.mouse_x);
        io.mouse_pos.y = f32(new_state.mouse_y);
        io.mouse_down[0] = new_state.left_mouse;
        io.mouse_down[1] = new_state.right_mouse;
        io.mouse_wheel   = f32(new_state.mouse_wheel);

        //io.mouse_wheel = f32(ctx.imgui_state.mouse_wheel_delta);

        io.key_ctrl =  win32.is_key_down(win32.Key_Code.Lcontrol) || win32.is_key_down(win32.Key_Code.Rcontrol);
        io.key_shift = win32.is_key_down(win32.Key_Code.Lshift)   || win32.is_key_down(win32.Key_Code.Rshift);
        io.key_alt =   win32.is_key_down(win32.Key_Code.Lmenu)    || win32.is_key_down(win32.Key_Code.Rmenu);
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
    io.delta_time = new_state.deltatime;
    imgui.new_frame();
}

render_proc :: proc(state : ^State, render_to_screen : bool, window_width, window_height : int) {
    imgui.render();
    if !render_to_screen {
        return;
    }
    data := imgui.get_draw_data();
    io := imgui.get_io();

    width  := i32(data.display_size.x * io.display_framebuffer_scale.x);
    height := i32(data.display_size.y * io.display_framebuffer_scale.y);
    if height == 0 || width == 0 {
        return;
    }
    imgui.draw_data_scale_clip_rects(data, io.display_framebuffer_scale);

    //@TODO(Hoej): BACKUP STATE!
    lastViewport : [4]i32;
    lastScissor  : [4]i32;

    cull := gl.get_integer(gl.GetIntegerNames.CullFace);
    depth := gl.get_integer(gl.GetIntegerNames.DepthTest);
    scissor := gl.get_integer(gl.GetIntegerNames.ScissorTest);
    blend := gl.get_integer(gl.GetIntegerNames.Blend);

    gl.get_integer(gl.GetIntegerNames.Viewport, lastViewport[:]);
    gl.get_integer(gl.GetIntegerNames.ScissorBox, lastScissor[:]);

    gl.enable(gl.Capabilities.Blend);
    gl.blend_equation(gl.BlendEquations.FuncAdd);
    gl.blend_func(gl.BlendFactors.SrcAlpha, gl.BlendFactors.OneMinusSrcAlpha);
    gl.disable(gl.Capabilities.CullFace);
    gl.disable(gl.Capabilities.DepthTest);
    gl.enable(gl.Capabilities.ScissorTest);
    gl.polygon_mode(gl.PolygonFace.FrontAndBack, gl.PolygonModes.Fill);

    gl.viewport(0, 0, width, height);
    L : f32 = data.display_pos.x;
    R : f32 = data.display_pos.x + data.display_size.x;
    T : f32 = data.display_pos.y;
    B : f32 = data.display_pos.y + data.display_size.y;
    ortho_projection := math.Mat4
    {
        { 2.0/(R-L),   0.0,          0.0, 0.0 },
        { 0.0,         2.0 / (T-B),  0.0, 0.0 },
        { 0.0,         0.0,         -1.0, 0.0 },
        { (R+L)/(L-R), (T+B)/(B-T),  0.0, 1.0 },
    };

    gl.use_program(state.main_program);
    gl.uniform(&state.main_program, "Texture", i32(0));
    gl.uniform(&state.main_program, "ProjMtx", ortho_projection, false);

    vao_handle := gl.gen_vertex_array();
    gl.bind_vertex_array(vao_handle);
    gl.bind_buffer(state.vbo_handle);

    gl.enable_vertex_attrib_array(state.main_program.attributes["Position"]);
    gl.enable_vertex_attrib_array(state.main_program.attributes["UV"]);
    gl.enable_vertex_attrib_array(state.main_program.attributes["Color"]);

    gl.vertex_attrib_pointer(state.main_program.attributes["Position"],   2, gl.VertexAttribDataType.Float, false, size_of(imgui.DrawVert), offset_of(imgui.DrawVert, pos));
    gl.vertex_attrib_pointer(state.main_program.attributes["UV"],         2, gl.VertexAttribDataType.Float, false, size_of(imgui.DrawVert), offset_of(imgui.DrawVert, uv));
    gl.vertex_attrib_pointer(state.main_program.attributes["Color"],      4, gl.VertexAttribDataType.UByte, true,  size_of(imgui.DrawVert), offset_of(imgui.DrawVert, col));

    new_list := mem.slice_ptr(data.cmd_lists, int(data.cmd_lists_count));
    for list in new_list {
        idx_buffer_offset : ^imgui.DrawIdx = nil;

        gl.bind_buffer(state.vbo_handle);
        gl.buffer_data(gl.BufferTargets.Array,
                       list.vtx_buffer.size * size_of(imgui.DrawVert),
                       list.vtx_buffer.data,
                       gl.BufferDataUsage.StreamDraw);

        gl.bind_buffer(state.ebo_handle);
        gl.buffer_data(gl.BufferTargets.ElementArray,
                       list.idx_buffer.size * size_of(imgui.DrawIdx),
                       list.idx_buffer.data,
                       gl.BufferDataUsage.StreamDraw);


        pos := data.display_pos;
        cmds := mem.slice_ptr(list.cmd_buffer.data,  int(list.cmd_buffer.size));
        for cmd, idx in cmds {
            if cmd.user_callback != nil {
                cmd.user_callback(list, &cmds[idx]);
            } else {
                clip := imgui.Vec4{
                    cmd.clip_rect.x - pos.x,
                    cmd.clip_rect.y - pos.y,
                    cmd.clip_rect.z - pos.x,
                    cmd.clip_rect.w - pos.y,
                };

                if clip.x < f32(width) && clip.y < f32(height) && clip.z >= 0 && clip.w >= 0 {
                    gl.scissor(
                        i32(clip.x),
                        height - i32(clip.w),
                        i32(clip.z - clip.x),
                        i32(clip.w - clip.y)
                    );

                    gl.bind_texture(gl.TextureTargets.Texture2D, gl.Texture(uint(uintptr(cmd.texture_id))));
                    gl.draw_elements(gl.DrawModes.Triangles,
                                     int(cmd.elem_count),
                                     gl.DrawElementsType.UShort,
                                     idx_buffer_offset);
                }
            }

            idx_buffer_offset = mem.ptr_offset(idx_buffer_offset, int(cmd.elem_count));

        }
    }

    gl.delete_vertex_array(&vao_handle);

    //TODO: Restore state

    if blend == 1 { gl.enable(gl.Capabilities.Blend); } else { gl.disable(gl.Capabilities.Blend); }
    if cull == 1 { gl.enable(gl.Capabilities.CullFace); } else { gl.disable(gl.Capabilities.CullFace); }
    if depth == 1 { gl.enable(gl.Capabilities.DepthTest); } else { gl.disable(gl.Capabilities.DepthTest); }
    if scissor == 1 { gl.enable(gl.Capabilities.ScissorTest); } else { gl.disable(gl.Capabilities.ScissorTest); }
    gl.viewport(lastViewport[0], lastViewport[1], lastViewport[2], lastViewport[3]);
    gl.scissor(lastScissor[0], lastScissor[1], lastScissor[2], lastScissor[3]);
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