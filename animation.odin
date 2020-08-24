package workbench

import        "core:fmt"
import        "core:os"
import        "core:sort"
import rt     "core:runtime"
import        "core:strings"
import        "core:mem"

import ai     "external/assimp"
import "gpu"
import "external/imgui"
import "math"

//
// Loading
//

Loaded_Animation :: struct {
    name: string,
    target_name: string,
    channels: [dynamic]Anim_Channel,

    duration: f32,
    ticks_per_second: f32,

    bone_mapping: map[string]int,
}

Anim_Channel :: struct {
    name: string,
    channel_id: int,

    pos_frames: []Anim_Frame,
    scale_frames: []Anim_Frame,
    rot_frames: []Anim_Frame,
}

Anim_Frame :: struct {
    time: f64,

    kind: union {
        Anim_Frame_Pos,
        Anim_Frame_Rotation,
        Anim_Frame_Scale
    }
}

Anim_Frame_Pos :: struct {
    position: Vec3,
}
Anim_Frame_Rotation :: struct {
    rotation: Quat,
}
Anim_Frame_Scale :: struct {
    scale: Vec3,
}

loaded_animations: map[string]Loaded_Animation;

load_animations_from_ai_scene :: proc(scene: ^ai.Scene, model_name: string, bone_mapping: map[string]int) {
    ai_animations := mem.slice_ptr(scene.animations, cast(int) scene.num_animations);
    for _, anim_idx in ai_animations {
        ai_animation := ai_animations[anim_idx];

        animation := Loaded_Animation{};
        animation.channels = make([dynamic]Anim_Channel, 0, int(ai_animation.num_channels));
        animation.name = strings.clone(strings.string_from_ptr(&ai_animation.name.data[0], cast(int)ai_animation.name.length));
        animation.duration = f32(ai_animation.duration);
        animation.ticks_per_second = f32(ai_animation.ticks_per_second);
        animation.target_name = model_name;
        // animation.bone_mapping = bone_mapping;

        animation_channels := mem.slice_ptr(ai_animation.channels, cast(int) ai_animation.num_channels);
        for channel in animation_channels {
            node_name := strings.clone(strings.string_from_ptr(&channel.node_name.data[0], cast(int)channel.node_name.length));

            pos_frames := make([dynamic]Anim_Frame, 0, channel.num_position_keys);
            scale_frames := make([dynamic]Anim_Frame, 0, channel.num_scaling_keys);
            rot_frames := make([dynamic]Anim_Frame, 0, channel.num_rotation_keys);

            position_keys := mem.slice_ptr(channel.position_keys, cast(int) channel.num_position_keys);
            for pos_key in position_keys {
                append(&pos_frames, Anim_Frame{
                    pos_key.time,
                    Anim_Frame_Pos {ai_to_wb(pos_key.value)},
                });
            }

            rotation_keys := mem.slice_ptr(channel.rotation_keys, cast(int) channel.num_rotation_keys);
            for rot_key in rotation_keys {
                append(&rot_frames, Anim_Frame{
                    rot_key.time,
                    Anim_Frame_Rotation{ai_to_wb(rot_key.value)},
                });
            }

            scaling_keys := mem.slice_ptr(channel.scaling_keys, cast(int) channel.num_scaling_keys);
            for scale_key in scaling_keys {
                append(&scale_frames, Anim_Frame{
                    scale_key.time,
                    Anim_Frame_Scale{ai_to_wb(scale_key.value)},
                });
            }

            append(&animation.channels, Anim_Channel{
                node_name, 
                node_name in bone_mapping ? bone_mapping[node_name] : -1,
                pos_frames[:],
                scale_frames[:],
                rot_frames[:]
            });
        }

        loaded_animations[animation.name] = animation;
    }
}

//
// Playing
//

Animation_Player :: struct {
    current_animation: string,

    animation_state: Model_Animation_State,
    time: f32,
    running_time: f32,
}

Model_Animation_State :: struct {
    mesh_states: []Mesh_State, // array of bones per mesh in the model
}

Mesh_State :: struct {
    state: []Mat4,
}

init_animation_player :: proc(player: ^Animation_Player, model: Model) {
    model := model;
    player.animation_state.mesh_states = make([]Mesh_State, len(model.meshes));
    for mesh, i in &model.meshes {
        arr := make([]Mat4, len(mesh.skin.offsets));

        for bone, j in mesh.skin.offsets {
            arr[j] = bone;
        }

        player.animation_state.mesh_states[i] = Mesh_State { arr };
    }
}

destroy_animation_player :: proc(player: ^Animation_Player) {
    for mesh_state in player.animation_state.mesh_states {
        delete(mesh_state.state);
    }
    delete(player.animation_state.mesh_states);
    // note(josh): we don't delete `current_animation` here. that's the user's job
}

tick_animation :: proc(player: ^Animation_Player, model: Model, dt: f32) {
    assert(model.has_bones);

    if player.current_animation in loaded_animations {
        animation := loaded_animations[player.current_animation];

        player.running_time += dt;

        tps : f32 = 25.0;
        if animation.ticks_per_second != 0 {
            tps = animation.ticks_per_second;
        }
        time_in_ticks := player.running_time * tps;
        player.time = mod(time_in_ticks, animation.duration);
    }

    for mesh, i in model.meshes {
        sample_animation(mesh, player.current_animation, player.time, &player.animation_state.mesh_states[i].state);
    }
}

sample_animation :: proc(mesh: Mesh, animation_name: string, time: f32, current_state: ^[]Mat4) {
    if !(animation_name in loaded_animations) do return;
    if len(current_state^) < 1 do return;

    animation := loaded_animations[animation_name];
    read_animation_hierarchy(mesh, time, animation, mesh.skin.parent_node, identity(Mat4), current_state);
}

read_animation_hierarchy :: proc(mesh: Mesh, time: f32, animation: Loaded_Animation, node: ^Mesh_Node, parent_transform: Mat4, current_state: ^[]Mat4) {
    channel, exists := get_animation_channel(animation, node.index);
    node_transform := node.local_transform;

    if exists && node.index >= 0 {

        translation_transform := identity(Mat4);
        scale_transform := identity(Mat4);
        rotation_transform := identity(Mat4);

        // interpolate to position
        if len(channel.pos_frames) > 1 {
            pos_frame := 0;

            for frame, i in channel.pos_frames {
                if time < f32(frame.time) {
                    pos_frame = i;
                    break;
                }
            }

            prev_pos_frame := pos_frame-1;
            if prev_pos_frame < 0 do prev_pos_frame = len(channel.pos_frames)-1;

            current_frame := channel.pos_frames[prev_pos_frame];
            next_frame := channel.pos_frames[pos_frame];

            delta_time := next_frame.time - current_frame.time;
            if delta_time == 0 do delta_time = 1;
            factor := (f64(time) - current_frame.time) / delta_time;

            start := current_frame.kind.(Anim_Frame_Pos).position;
            end := next_frame.kind.(Anim_Frame_Pos).position;

            final_pos := lerp(start, end, f32(factor));

            translation_transform[3][0] = final_pos.x;
            translation_transform[3][1] = final_pos.y;
            translation_transform[3][2] = final_pos.z;
        } else if len(channel.pos_frames) == 1 {
            f := channel.pos_frames[0];
            translation_transform[3][0] = f.kind.(Anim_Frame_Pos).position.x;
            translation_transform[3][1] = f.kind.(Anim_Frame_Pos).position.y;
            translation_transform[3][2] = f.kind.(Anim_Frame_Pos).position.z;
        }

        // interpolate scale
        if len(channel.scale_frames) > 1 {
            scale_frame := 0;
            for frame, i in channel.scale_frames {
                if time < f32(frame.time) {
                    scale_frame = i;
                    break;
                }
            }
            prev_scale_frame := scale_frame-1;
            if prev_scale_frame < 0 do prev_scale_frame = len(channel.scale_frames)-1;

            current_frame := channel.scale_frames[prev_scale_frame];
            next_frame := channel.scale_frames[scale_frame];

            delta_time := next_frame.time - current_frame.time;
            if delta_time == 0 do delta_time = 1;
            factor := (f64(time) - current_frame.time) / delta_time;

            start := current_frame.kind.(Anim_Frame_Scale).scale;
            end := next_frame.kind.(Anim_Frame_Scale).scale;

            final_scale := lerp(start, end, f32(factor));

            scale_transform[0][0] = final_scale.x;
            scale_transform[1][1] = final_scale.y;
            scale_transform[2][2] = final_scale.z;
        } else if len(channel.scale_frames) == 1 {
            f := channel.scale_frames[0];
            scale_transform[0][0] = f.kind.(Anim_Frame_Scale).scale.x;
            scale_transform[1][1] = f.kind.(Anim_Frame_Scale).scale.y;
            scale_transform[2][2] = f.kind.(Anim_Frame_Scale).scale.z;
        }

        // interpolate rotation
        if len(channel.rot_frames) > 1 {
            rot_frame := 0;
            for frame, i in channel.rot_frames {
                if time < f32(frame.time) {
                    rot_frame = i;
                    break;
                }
            }
            prev_rot_frame := rot_frame-1;
            if prev_rot_frame < 0 do prev_rot_frame = len(channel.rot_frames)-1;

            current_frame := channel.rot_frames[prev_rot_frame];
            next_frame := channel.rot_frames[rot_frame];

            delta_time := next_frame.time - current_frame.time;
            if delta_time == 0 do delta_time = 1;
            factor := (f64(time) - current_frame.time) / delta_time;

            start := current_frame.kind.(Anim_Frame_Rotation).rotation;
            end := next_frame.kind.(Anim_Frame_Rotation).rotation;

            final_rot := quat_norm(slerp(start, end, f32(factor)));
            rotation_transform = quat_to_mat4(final_rot);

        } else if len(channel.rot_frames) == 1 {
            f := channel.rot_frames[0];
            rotation_transform = quat_to_mat4(f.kind.(Anim_Frame_Rotation).rotation);
        }

        node_transform = mul(mul(translation_transform, rotation_transform), scale_transform);
    }

    global_transform := mul(parent_transform, node_transform);
    if node.index >= 0 {
        bone := mesh.skin.offsets[node.index];
        current_state[node.index] = mul(mul(mesh.skin.global_inverse, global_transform), bone);
    }

    for _, i in node.children {
        read_animation_hierarchy(mesh, time, animation, node.children[i], global_transform, current_state);
    }
}

get_animation_channel :: proc(using anim: Loaded_Animation, channel_id: int) -> (Anim_Channel, bool) {
    for channel in channels {
        if channel.channel_id == channel_id {
            return channel, true;
        }
    }

    return {}, false;
}

get_animations_for_target :: proc(target: string) -> []string {
    anims : [dynamic]string;
    for id, anim in loaded_animations {
        if anim.target_name == target do append(&anims, id);
    }

    return anims[:];
}

frame_sort_proc :: proc(f1, f2: Anim_Frame) -> int {
    if f1.time > f2.time do return  1;
    if f1.time < f2.time do return -1;
    return 0;
}


// Animation Controller
Animation_Controller :: struct {
    player: Animation_Player,

    nodes: [dynamic]Node,
    transitions: [dynamic]Transition,
    last_node_id: int,
}

Node :: struct {
    // Display data
    id: int,
    name: string,
    pos, size: Vec2,
    in_count, out_count: int,

    // anim data
}

Transition :: struct {
    // Display data
    in_idx, in_slot, out_idx, out_slot: int,

    // anim transition data
}

get_input_slot_pos :: proc(using node: Node, slot_no: int) -> Vec2 { 
    return {pos.x, pos.y + size.y * (f32(slot_no + 1) / f32(in_count + 1))}; 
}
get_output_slot_pos :: proc(using node: Node, slot_no: int) -> Vec2 { 
    return {pos.x + size.x, pos.y + size.y * (f32(slot_no + 1) / f32(out_count + 1))}; 
}

draw_animation_controller_window :: proc(using animator: ^Animation_Controller, open: ^bool) {
    if !imgui.begin("Animator", open) {
        imgui.end();
        return;
    }

    io := imgui.get_io();

    @static last_animator_id := -1;
    @static selected_node := -1;
    @static scrolling := imgui.Vec2{0,0};
    @static transition_start_node := -1;

    open_context_menu := false;
    node_hovered_in_list := -1;
    node_hovered_in_scene := -1;

    imgui.begin_child("Node List", {100,0});
    imgui.text("Nodes");
    imgui.separator();
    for node in &nodes {
        imgui.push_id(node.id);
        defer imgui.pop_id();

        if imgui.selectable(node.name, node.id == selected_node) {
            selected_node = node.id;
        }
        if imgui.is_item_hovered() {
            node_hovered_in_list = node.id;
            open_context_menu |= imgui.is_mouse_clicked(1, false);
        }
    }
    imgui.end_child();
    
    imgui.same_line();
    imgui.begin_group();

    NODE_SLOT_RADIUS : f32 = 4.0;
    NODE_WINDOW_PADDING := imgui.Vec2{8,8};

    imgui.text(fmt.tprint("Hold middle mouse button to scroll (", scrolling.x, ",", scrolling.y, ")"));
    imgui.push_style_var(.FramePadding, imgui.Vec2{1, 1});
    imgui.push_style_color(.ChildBg, imgui.Vec4{0.2, 0.2, 0.2, 0.8});
    imgui.push_style_var(.WindowPadding, imgui.Vec2{0, 0});
    imgui.begin_child("scrolling_region", {0, 0}, true, .NoScrollbar | .NoMove);
    imgui.push_item_width(120);

    offset := imgui.get_cursor_screen_pos();
    offset.x += scrolling.x; 
    offset.y += scrolling.y;

    draw_list := imgui.get_window_draw_list();

    { // grid
        win_pos := imgui.get_cursor_screen_pos();
        canvas_sz := imgui.get_window_size();
        GRID_COLOR := imgui.Vec4{0.8,0.8,0.8,0.1};
        for x := math.mod_f32(scrolling.x, 64); x < canvas_sz.x; x += 64 {
            imgui.draw_list_add_line(draw_list, {x + win_pos.x, win_pos.y}, {x+win_pos.x, canvas_sz.y+win_pos.y}, imgui.get_color_u32(&GRID_COLOR), 0.01);
        }
        for y := math.mod_f32(scrolling.y, 64); y < canvas_sz.y; y += 64 {
            imgui.draw_list_add_line(draw_list, {win_pos.x, y+win_pos.y}, {canvas_sz.x+win_pos.x, y+win_pos.y}, imgui.get_color_u32(&GRID_COLOR), 0.01);
        }
    }

    imgui.draw_list_channels_split(draw_list, 2);
    imgui.draw_list_channels_set_current(draw_list, 0);
    for transition in transitions {
        input_node, output_node: ^Node;

        for n in &nodes {
            if n.id == transition.in_idx do input_node = &n;
            if n.id == transition.out_idx do output_node = &n;
        }

        _p1 := get_output_slot_pos(input_node^, transition.in_slot);
        p1 := imgui.Vec2{_p1.x + offset.x, _p1.y + offset.y};

        _p2 := get_input_slot_pos(output_node^, transition.out_slot);
        p2 := imgui.Vec2{_p2.x + offset.x, _p2.y + offset.y};

        LINE_COLOR := imgui.Vec4{0.8,0.8,0.4,1};
        imgui.draw_list_add_bezier_curve(draw_list, p1, {p1.x+50, p1.y}, {p2.x-50, p2.y}, p2, imgui.get_color_u32(&LINE_COLOR), 3, 16);
    }

    for node in &nodes {
        
        imgui.push_id(node.id);
        defer imgui.pop_id();

        node_rect_min := imgui.Vec2{offset.x + node.pos.x, offset.y + node.pos.y};
        imgui.draw_list_channels_set_current(draw_list, 1);
        old_any_active := imgui.is_any_item_active();
        imgui.set_cursor_screen_pos({node_rect_min.x + NODE_WINDOW_PADDING.x, node_rect_min.y + NODE_WINDOW_PADDING.y});
        imgui.begin_group();
        imgui.push_item_width(250);
        node.name = input_text("", node.name);
        imgui.pop_item_width();

        imgui.end_group();

        node_widgets_active := !old_any_active && imgui.is_any_item_active();
        rs : imgui.Vec2; imgui.get_item_rect_size(&rs);
        node.size = {rs.x + NODE_WINDOW_PADDING.x*2, rs.y + NODE_WINDOW_PADDING.y*2};

        node_rect_max := imgui.Vec2{node_rect_min.x + node.size.x, node_rect_min.y + node.size.y};

        imgui.draw_list_channels_set_current(draw_list, 0);
        imgui.set_cursor_screen_pos(node_rect_min);
        imgui.invisible_button("node", {node.size.x, node.size.y});
        if imgui.is_item_hovered() {
            node_hovered_in_scene = node.id;
            open_context_menu |= imgui.is_mouse_clicked(1, false);
        }

        node_moving_active := imgui.is_item_active();
        if node_moving_active || node_widgets_active {
            selected_node = node.id;
        }
        if node_moving_active && imgui.is_mouse_dragging(0) {
            node.pos = {node.pos.x + io.mouse_delta.x, node.pos.y + io.mouse_delta.y};
        }

        SELECTED := imgui.Vec4{0.25,0.25,0.25,1};
        NOT_SELECTED := imgui.Vec4{0.2,0.2,0.2,1};
        node_bg_colour := node_hovered_in_list == node.id || node_hovered_in_scene == node.id || (node_hovered_in_list == -1 && selected_node == node.id) ? imgui.get_color_u32(&SELECTED) : imgui.get_color_u32(&NOT_SELECTED);
        imgui.draw_list_add_rect_filled(draw_list, node_rect_min, node_rect_max, node_bg_colour, 4, 0);
        c := imgui.Vec4{0.4,0.4,0.4,1};
        imgui.draw_list_add_rect(draw_list, node_rect_min, node_rect_max, imgui.get_color_u32(&c), 4, 0, 1);

        SLOT_COLOR := imgui.Vec4{0.45,0.45,0.45,0.45};
        for slot in 0..<node.in_count {
            sp := get_input_slot_pos(node, slot);
            imgui.draw_list_add_circle_filled(draw_list, {offset.x + sp.x, offset.y + sp.y}, NODE_SLOT_RADIUS, imgui.get_color_u32(&SLOT_COLOR), 10);
        }

        for slot in 0..<node.out_count {
            sp := get_output_slot_pos(node, slot);
            imgui.draw_list_add_circle_filled(draw_list, {offset.x + sp.x, offset.y + sp.y}, NODE_SLOT_RADIUS, imgui.get_color_u32(&SLOT_COLOR), 10);
        }
    }

    imgui.draw_list_channels_merge(draw_list);

    open_node_context_menu := false;

    if imgui.is_mouse_released(1) {
        if imgui.is_window_hovered(.AllowWhenBlockedByPopup) && !imgui.is_any_item_hovered() {
            selected_node = -1;
            node_hovered_in_list = -1;
            node_hovered_in_scene = -1;
            open_context_menu = true;
        }
    }

    if transition_start_node != -1 {
        tsn : ^Node;
        slot := 0;
        for n in &nodes {
            if n.id == transition_start_node {
                tsn = &n;
                slot = n.out_count;
                break;
            }
        }

        mouse_pos : imgui.Vec2; imgui.get_mouse_pos(&mouse_pos);

        _p1 := get_output_slot_pos(tsn^, slot);
        p1 := imgui.Vec2{_p1.x + offset.x, _p1.y + offset.y};

        LINE_COLOR := imgui.Vec4{0.8,0.8,0.4,1};
        imgui.draw_list_add_bezier_curve(draw_list, p1, {p1.x+50, p1.y}, {p1.x-50, p1.y}, mouse_pos, imgui.get_color_u32(&LINE_COLOR), 3, 4);

        if imgui.is_mouse_clicked(0, false) && !started_transition_last_frame {
            target_node_id := -1;
            if node_hovered_in_scene != -1 do target_node_id = node_hovered_in_scene;
            if node_hovered_in_list != -1 do target_node_id = node_hovered_in_list;

            if target_node_id != -1 {
                target_node : ^Node;
                target_slot := 0;
                for n in &nodes {
                    if n.id == target_node_id {
                        target_node = &n;
                        target_slot = n.in_count;
                        break;
                    }
                }

                tsn.out_count += 1;
                target_node.in_count += 1;

                append(&transitions, Transition{
                    tsn.id, slot, target_node_id, target_slot
                });
            }

            transition_start_node = -1;
        }
        started_transition_last_frame = false;
    }

    if open_context_menu {
        imgui.open_popup("context_menu");
        if node_hovered_in_list != -1 do selected_node = node_hovered_in_list;
        if node_hovered_in_scene != -1 do selected_node = node_hovered_in_scene;
    }

    imgui.push_style_var(.WindowPadding, imgui.Vec2{8,8});
    if imgui.begin_popup("context_menu") {
        node : ^Node;
        for n in &nodes {
            if n.id == selected_node do node = &n;
        }

        scene_pos : imgui.Vec2; imgui.get_mouse_pos_on_opening_current_popup(&scene_pos);
        scene_pos.x -= offset.x;
        scene_pos.y -= offset.y;

        if node != nil {
            imgui.text(node.name);
            imgui.separator();
            if imgui.menu_item("New Transition") {
                logln(selected_node);
                if selected_node != -1 do transition_start_node = selected_node;
                started_transition_last_frame = true;
                logln(transition_start_node);
            }
        } else {
            if imgui.menu_item("Add") {
                last_node_id += 1;
                append(&nodes, Node{
                    last_node_id, "New Node", {scene_pos.x, scene_pos.y}, {}, 0, 0
                });
            }
        }
        imgui.end_popup();
    }
    imgui.pop_style_var();

    if !imgui.is_any_item_active() && imgui.is_mouse_dragging(2, 0) {
        scrolling = {scrolling.x + io.mouse_delta.x, scrolling.y + io.mouse_delta.y};
    }

    imgui.pop_item_width();
    imgui.end_child();
    imgui.pop_style_color();
    imgui.pop_style_var();
    imgui.pop_style_var();
    imgui.end_group();

    imgui.end();
}

started_transition_last_frame := false;

input_text :: proc(label, input: string) -> string {
    text_edit_buffer: [256]u8;
    fmt.bprint(text_edit_buffer[:], input);
    if imgui.input_text(label, text_edit_buffer[:]) {
        result := text_edit_buffer[:];
        for b, i in text_edit_buffer {
            if b == '\x00' {
                result = text_edit_buffer[:i];
                break;
            }
        }

        // @Leak
        return strings.clone(cast(string)result);
    }
    return input;    
}