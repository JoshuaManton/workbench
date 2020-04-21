package workbench

import        "core:fmt"
import        "core:os"
import        "core:sort"
import rt     "core:runtime"
import        "core:strings"
import        "core:mem"

import ai     "external/assimp"
import "gpu"

//
// Loading
//

Loaded_Animation :: struct {
    name: string,
    target_name: string,
    channels: [dynamic]Anim_Channel,

    duration: f32,
    ticks_per_second: f32,
}

Anim_Channel :: struct {
    channel_idx: int,

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

        animation_channels := mem.slice_ptr(ai_animation.channels, cast(int) ai_animation.num_channels);
        for channel in animation_channels {
            node_name := strings.clone(strings.string_from_ptr(&channel.node_name.data[0], cast(int)channel.node_name.length));
            defer delete(node_name);

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
                bone_mapping[node_name],
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
    mesh_states: [dynamic]Mesh_State, // array of bones per mesh in the model
}

Mesh_State :: struct {
    state: [dynamic]Mat4,
}

init_animation_player :: proc(player: ^Animation_Player, model: Model) {
    model := model;
    player.animation_state.mesh_states = make([dynamic]Mesh_State, 0, len(model.meshes));
    for mesh in &model.meshes {
        arr := make([dynamic]Mat4, 0, len(mesh.skin.bones));

        for bone in mesh.skin.bones {
            append(&arr, bone.offset);
        }

        append(&player.animation_state.mesh_states, Mesh_State { arr });
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

sample_animation :: proc(mesh: Mesh, animation_name: string, time: f32, current_state: ^[dynamic]Mat4) {
    if !(animation_name in loaded_animations) do return;
    if len(current_state) < 1 do return;

    animation := loaded_animations[animation_name];
    read_animation_hierarchy(mesh, time, animation, mesh.skin.parent_node, identity(Mat4), current_state);
}

read_animation_hierarchy :: proc(mesh: Mesh, time: f32, animation: Loaded_Animation, node: ^Mesh_Node, parent_transform: Mat4, current_state: ^[dynamic]Mat4) {
    channel, exists := get_animation_channel(animation, node.bone_idx);
    node_transform := node.local_transform;

    if exists {

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

            next_pos_frame := (pos_frame + 1) % len(channel.pos_frames);

            current_frame := channel.pos_frames[pos_frame];
            next_frame := channel.pos_frames[next_pos_frame];

            delta_time := next_frame.time - current_frame.time;
            if delta_time == 0 do delta_time = 1;
            factor := (f64(time) - current_frame.time) / delta_time;

            start := current_frame.kind.(Anim_Frame_Pos).position;
            end := next_frame.kind.(Anim_Frame_Pos).position;
            delta := end - start;

            final_pos := start + (delta * f32(factor));

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
            next_scale_frame := (scale_frame + 1)  % len(channel.scale_frames);

            current_frame := channel.scale_frames[scale_frame];
            next_frame := channel.scale_frames[next_scale_frame];

            delta_time := next_frame.time - current_frame.time;
            if delta_time == 0 do delta_time = 1;
            factor := (f64(time) - current_frame.time) / delta_time;

            start := current_frame.kind.(Anim_Frame_Scale).scale;
            end := next_frame.kind.(Anim_Frame_Scale).scale;
            delta := end - start;

            final_scale := start + (delta * f32(factor));
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
            next_rot_frame := (rot_frame + 1)  % len(channel.rot_frames);

            current_frame := channel.rot_frames[rot_frame];
            next_frame := channel.rot_frames[next_rot_frame];

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
    bone := mesh.skin.bones[node.bone_idx];
    current_state[node.bone_idx] = mul(mul(mesh.skin.global_inverse, global_transform), bone.offset);

    for _, i in node.children {
        read_animation_hierarchy(mesh, time, animation, node.children[i], global_transform, current_state);
    }
}

get_animation_channel :: proc(using anim: Loaded_Animation, channel_id: int) -> (Anim_Channel, bool) {
    for channel in channels {
        if channel.channel_idx == channel_id {
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
