package ecs

DEVELOPER :: true;

using import "core:fmt"
      import rt "core:runtime"
      import "core:mem"
      import "core:strings"
      import "core:os"

      import wb "shared:workbench"
using import    "shared:workbench/math"
      import    "shared:workbench/wbml"
      import    "shared:workbench/laas"
using import    "shared:workbench/types"
using import    "shared:workbench/basic"
using import    "shared:workbench/logging"
      import    "shared:workbench/gpu"
      import    "shared:workbench/reflection"
      import    "shared:workbench/external/imgui"

/*

--- Lifetime
{
    init   :: proc()
    deinit :: proc()
}

--- Scenes
{
    load_scene   :: proc(folder_path: string)
    save_scene   :: proc()
    unload_scene :: proc()
    update       :: proc(dt: f32)
    render       :: proc()

    draw_scene_window :: proc()
}

--- Components and Entities
{
    add_component_type :: proc($Type: typeid, update_proc: proc(^Type, f32), render_proc: proc(^Type), init_proc: proc(^Type) = nil, deinit_proc: proc(^Type) = nil)

    make_entity    :: proc(name := "Entity", requested_id: Entity = 0) -> Entity
    destroy_entity :: proc(eid: Entity)
    destroy_entity_immediate :: proc(eid: Entity)

    add_component    :: proc(eid: Entity, $T: typeid, loc := #caller_location) -> ^T
    get_component    :: proc(eid: Entity, $T: typeid, loc := #caller_location) -> (^T, bool)
    remove_component :: proc(eid: Entity, $T: typeid) -> bool

    get_component_storage :: proc($T: typeid) -> []T

    load_entity_from_file :: proc(filepath: string) -> Entity
}

*/

init :: proc() {
    add_component_type(Transform, nil, nil);
}

deinit :: proc() {
    unload_scene();
    for id, type in component_types {
        delete_component_type(type^);
        free(type);
    }
    delete(component_types);
}



//
// Scenes
//

load_scene :: proc(folder_path: string) {
    assert(scene == nil);

    scene = new(Scene);
    scene.folder_path = strings.clone(folder_path);

    filepaths := get_all_filepaths_recursively(folder_path);
    // todo(josh): @Leak filepaths
    // note(josh): contents of filepaths get given to entities

    for filepath in filepaths {
        if !string_ends_with(filepath, ".e") {
            delete(filepath);
        }
        else {
            load_entity_from_file(filepath);
        }
    }
}

save_scene :: proc() {
    assert(scene != nil);

    // delete
    {
        for file in scene.entity_files_to_destroy_on_save {
            assert(file != "");
            ok := wb.delete_file(file);
            if ok {
                logln("Deleted entity file: ", file);
            }
            else {
                logln("Error: Couldn't find entity file: ", file);
            }
        }
        // todo(josh): I think we are @Leaking the file names. investigate
        clear(&scene.entity_files_to_destroy_on_save);
    }

    for eid, data in scene.entity_datas {
        sb: strings.Builder;
        defer strings.destroy_builder(&sb);

        sbprint(&sb, eid, " ", data.name, "\n");
        for c in data.components {
            comp_data, ok2 := component_types[c];
            assert(ok2);

            sbprint(&sb, comp_data.ti, "\n");

            _comp, found :=_get_component_internal(eid, c);
            assert(found);
            comp := cast(^Component_Base)_comp;
            assert(comp != nil);
            wbml.serialize_with_type_info("", comp, comp_data.ti, &sb, 0);
        }

        entity_file_name := tprint(scene.folder_path, "/", data.name, "-", eid, ".e");
        if data.serialized_file_on_disk != "" {
            if entity_file_name != data.serialized_file_on_disk {
                logln("Entity file changed from ", data.serialized_file_on_disk, " to ", entity_file_name, " Deleting old one.");
                wb.delete_file(data.serialized_file_on_disk);
                // todo(josh): @Leak data.serialized_file_on_disk
                data.serialized_file_on_disk = aprint(entity_file_name); // todo(josh): @Leak figure out the lifetime of this allocation
            }
        }
        else {
            data.serialized_file_on_disk = aprint(entity_file_name);
        }

        assert(data.serialized_file_on_disk != "");
        os.write_entire_file(data.serialized_file_on_disk, transmute([]u8)strings.to_string(sb));
    }
}

unload_scene :: proc() {
    for id, comp_type in component_types {
        comp_type.storage.len = 0;
        clear(&comp_type.reusable_indices);
    }

    if scene == nil do return;

    delete(scene.folder_path);
    for eid, data in scene.entity_datas {
        delete_entity_data(data^);
        free(data);
    }
    delete(scene.entity_datas);
    for data in scene.entity_datas_pool do free(data);
    delete(scene.entity_datas_pool);
    delete(scene.active_entities);
    delete(scene.entities_to_destroy);
    delete(scene.entity_files_to_destroy_on_save);
    free(scene);
    scene = nil;
}

update :: proc(dt: f32) {
    if scene == nil do return;

    // destroy entities
    {
        for eid in scene.entities_to_destroy {
            destroy_entity_immediate(eid);
        }

        clear(&scene.entities_to_destroy);
    }

    // update components
    {
        for tid, data in component_types {
            if data.update_proc != nil {
                for i in 0..<data.storage.len {
                    ptr := mem.ptr_offset(cast(^u8)data.storage.data, i * data.ti.size);
                    comp := cast(^Component_Base)ptr;
                    if comp.e == 0   do continue;
                    if !comp.enabled do continue;

                    entity, ok := scene.entity_datas[comp.e];
                    assert(ok);
                    if !entity.enabled do continue;

                    data.update_proc(ptr, dt);
                }
            }
        }
    }
}

render :: proc() {
    if scene == nil do return;

    for tid, data in component_types {
        if data.render_proc != nil {
            for i in 0..<data.storage.len {
                ptr := mem.ptr_offset(cast(^u8)data.storage.data, i * data.ti.size);
                comp := cast(^Component_Base)ptr;
                if comp.e == 0   do continue;
                if !comp.enabled do continue;

                entity, ok := scene.entity_datas[comp.e];
                assert(ok);
                if !entity.enabled do continue;

                data.render_proc(ptr);
            }
        }
    }
}



selected_entity: Entity;

draw_scene_window :: proc() {
    if imgui.begin("Scene") {
        // save/load panel
        {
            @static _scene_input_text: [1024]u8;
            imgui.input_text("", cast([]u8)_scene_input_text[:]);
            _scene_input_text[len(_scene_input_text)-1] = 0;
            scene_name := cast(string)cast(cstring)&_scene_input_text[0];

            // load / save
            {
                @static asking_to_save := false;
                @static do_load_after_save := false;
                @static do_new_after_save := false;

                if imgui.button("Load") {
                    if scene_name == "" {
                        logln("You must provide a scene name to load.");
                    }
                    else {
                        asking_to_save = true;
                        do_load_after_save = true;
                        imgui.open_popup("Save scene");
                    }
                }

                imgui.same_line();
                if imgui.button("New") {
                    if scene_name == "" {
                        // todo(josh): allow new scenes without having to make a folder until you save
                        logln("You must provide a scene name to make a new scene.");
                    }
                    else {
                        asking_to_save = true;
                        do_new_after_save = true;
                        imgui.open_popup("Save scene");
                    }
                }

                if asking_to_save {
                    if scene == nil {
                        asking_to_save = false;
                    }
                    else {
                        if imgui.begin_popup("Save scene") {
                            defer imgui.end_popup();

                            imgui.text(tprint("Save current scene '", scene.folder_path, "'?"));
                            if imgui.button("Yes") {
                                save_scene();
                                unload_scene();
                                asking_to_save = false;
                                imgui.close_current_popup();
                            }
                            imgui.same_line();
                            if imgui.button("No") {
                                unload_scene();
                                asking_to_save = false;
                                imgui.close_current_popup();
                            }
                        }
                    }
                }
                else {
                    if do_load_after_save || do_new_after_save {
                        scene_folder := APRINT("scenes/", scene_name);
                        defer _scene_input_text = {};

                        if do_load_after_save {
                            do_load_after_save = false;
                            load_scene(scene_folder);
                        }
                        else if do_new_after_save {
                            do_new_after_save = false;
                            _, err := os.last_write_time_by_name(scene_folder);
                            if err == os.ERROR_NONE {
                                logln("Already have scene with the name ", scene_name);
                            }
                            else {
                                assert(err == os.ERROR_FILE_NOT_FOUND);
                                ok := wb.create_directory(scene_folder);
                                assert(ok, tprint("Couldn't create directory ", scene_folder));
                                load_scene(scene_folder);
                            }
                        }
                    }
                }
            }

            if scene != nil {
                imgui.same_line();
                if imgui.button("Save") {
                    save_scene();
                }
            }
        }

        if scene != nil {
            if imgui.button("Create Entity") {
                make_entity();
            }

            // todo(josh): clean up all these allocations. I was trying to use the frame_allocator but it wasn't working.
            entity_names: [dynamic]^u8;
            defer {
                for n in entity_names do free(n);
                delete(entity_names);
            }
            for eid in scene.active_entities {
                e, ok := scene.entity_datas[eid];
                assert(ok);
                str := strings.clone_to_cstring(e.name);
                append(&entity_names, cast(^u8)str);
            }

            @static _selected_entity: i32 = -1;
            imgui.list_box("Entities", &_selected_entity, &entity_names[0], cast(i32)len(entity_names), 30);
            if cast(int)_selected_entity > len(scene.active_entities) {
                _selected_entity = -1;
            }

            if _selected_entity >= 0 && cast(int)_selected_entity < len(scene.active_entities) {
                selected_entity = scene.active_entities[_selected_entity];
            }
            else {
                selected_entity = 0;
            }

            if imgui.begin("Inspector") {
                if selected_entity != 0 {
                    entity_to_clone: Entity;
                    e_data, ok := scene.entity_datas[selected_entity];
                    assert(ok);

                    imgui.push_id(tprint(e_data.name," - ", selected_entity)); defer imgui.pop_id();

                    @static entity_name_buffer: [64]u8;
                    if imgui.input_text("Name", entity_name_buffer[:], .EnterReturnsTrue) {
                        entity_name_buffer[len(entity_name_buffer)-1] = 0;
                        // note(josh): @Leak @Alloc, we stomp on the current name and leak it but that should be fine because this is debug only!!
                        e_data.name = aprint(cast(string)cast(cstring)&entity_name_buffer[0]);
                        entity_name_buffer = {};
                    }

                    imgui.checkbox("Enabled", &e_data.enabled);
                    imgui.same_line();
                    if imgui.button("Clone") {
                        entity_to_clone = selected_entity;
                    }

                    imgui.same_line();
                    if imgui.button("Destroy") {
                        destroy_entity(selected_entity);
                    }

                    for c in e_data.components {
                        component_data, ok := component_types[c];
                        assert(ok);

                        imgui.push_id(tprint(component_data.ti)); defer imgui.pop_id();

                        for i in 0..<component_data.storage.len {
                            ptr := cast(^Component_Base)mem.ptr_offset(cast(^u8)component_data.storage.data, i * component_data.ti.size);
                            if ptr.e == selected_entity {

                                if component_data.editor_imgui_proc != nil {
                                    component_data.editor_imgui_proc(ptr);
                                } else {
                                    wb.imgui_struct_ti("", ptr, component_data.ti);
                                }

                                break;
                            }
                        }
                    }



                    @static comp_name_buffer: [64]byte;
                    just_opened := false;
                    if imgui.button("+") {
                        comp_name_buffer = {};
                        imgui.open_popup("Add component");
                        just_opened = true;
                    }

                    if imgui.begin_popup("Add component") {
                        if just_opened do imgui.set_keyboard_focus_here(0);
                        imgui.input_text("Component", comp_name_buffer[:]);

                        for tid, data in component_types {
                            name := tprint(data.ti);
                            input := cast(string)cast(cstring)&comp_name_buffer[0];
                            name_lower  := string_to_lower(name);
                            input_lower := string_to_lower(input);

                            if len(input_lower) > 0 && string_starts_with(name_lower, input_lower) {
                                if imgui.button(name) {
                                    comp := cast(^Component_Base)_add_component_internal(selected_entity, tid);
                                    imgui.close_current_popup();
                                }
                            }
                        }
                        imgui.end_popup();
                    }

                    if entity_to_clone != 0 {
                        new_entity := make_entity();
                        to_clone_entity_data, ok := scene.entity_datas[entity_to_clone];
                        if !ok {
                            logln("entity_to_clone got deleted or something?");
                        }
                        else {
                            for c in to_clone_entity_data.components {
                                comp: ^Component_Base;
                                if c == type_info_of(Transform).id {
                                    comp, ok = _get_component_internal(new_entity, c);
                                    assert(ok);
                                }
                                else {
                                    comp = _add_component_internal(new_entity, c);
                                }
                                to_clone_component, ok := _get_component_internal(entity_to_clone, c);
                                assert(ok);
                                _copy_component_internal(comp, to_clone_component, type_info_of(c));
                            }
                        }
                    }
                }
            }
            imgui.end();
        }
    }
    imgui.end();
}



//
// Components and Entities
//

Entity :: int;

Component_Base :: struct {
    e: Entity "wbml_noserialize",
    enabled: bool,
}

Transform :: struct {
    using base: Component_Base,
    position: Vec3,
    rotation: Quat,
    scale: Vec3,

    parent: Entity,
}

add_component_type :: proc($Type: typeid, update_proc: proc(^Type, f32), render_proc: proc(^Type), init_proc: proc(^Type) = nil, deinit_proc: proc(^Type) = nil, editor_imgui_proc: proc(^Type) = nil) {
    when DEVELOPER {
        t: Type;
        assert(&t.base == &t);
    }

    if component_types == nil {
        component_types = make(map[typeid]^Component_Type, 1);
    }
    id := typeid_of(Type);
    assert(id notin component_types);

    component_types[id] = new_clone(Component_Type{
        type_info_of(Type),
        transmute(mem.Raw_Dynamic_Array)make([dynamic]Type, 0, 1),
        make([dynamic]int, 0, 1),
        cast(proc(rawptr, f32))update_proc,
        cast(proc(rawptr))render_proc,
        cast(proc(rawptr))init_proc,
        cast(proc(rawptr))deinit_proc,
        cast(proc(rawptr))editor_imgui_proc,
    });
}

make_entity :: proc(name := "Entity", requested_id: Entity = 0) -> Entity {
    assert(scene != nil);

    @static _last_entity_id: int;
    eid: Entity;
    if requested_id != 0 {
        eid = requested_id;
        _last_entity_id = max(_last_entity_id, requested_id);
    }
    else {
        _last_entity_id += 1;
        eid = _last_entity_id;
    }

    when DEVELOPER {
        for e in scene.active_entities {
            assert(e != eid, tprint("Duplicate entity ID!!!: ", e));
        }
        _, ok := scene.entity_datas[eid];
        assert(!ok, tprint("Duplicate entity ID that the previous check should have caught!!!: ", eid));
    }

    append(&scene.active_entities, eid);

    data: ^Entity_Data;
    if len(scene.entity_datas_pool) > 0 {
        data = pop(&scene.entity_datas_pool);
        data^ = {};
    }
    else {
        data = new(Entity_Data);
    }

    component_list: [dynamic]typeid;
    if len(scene.entity_component_list_pool) > 0 {
        component_list = pop(&scene.entity_component_list_pool);
        clear(&component_list);
    }
    else {
        component_list = make([dynamic]typeid, 0, 5);
    }
    assert(component_list != nil);
    data^ = Entity_Data{name, true, component_list, ""};
    scene.entity_datas[eid] = data;

    tf := add_component(eid, Transform);
    tf.rotation = Quat{0, 0, 0, 1};
    tf.scale = Vec3{1, 1, 1};

    return eid;
}

destroy_entity :: proc(eid: Entity) {
    assert(scene != nil);
    append(&scene.entities_to_destroy, eid);
}

destroy_entity_immediate :: proc(eid: Entity) {
    assert(scene != nil);

    data, ok := scene.entity_datas[eid];
    assert(ok); // todo(josh): maybe remove this assert and just return

    logln("destroying ", data.name);

    if data.serialized_file_on_disk != "" {
        append(&scene.entity_files_to_destroy_on_save, data.serialized_file_on_disk);
    }

    for c in data.components {
        component_data, ok := component_types[c];
        assert(ok);

        for i in 0..<component_data.storage.len {
            ptr := cast(^Component_Base)mem.ptr_offset(cast(^u8)component_data.storage.data, i * component_data.ti.size);
            if ptr.e == eid {
                append(&component_data.reusable_indices, i);
                ptr.e = 0;
            }
        }
    }

    assert(data.components != nil, "Entity didn't have any components??");
    clear(&data.components);
    append(&scene.entity_component_list_pool, data.components);



    for active, active_idx in scene.active_entities {
        if active == eid {
            unordered_remove(&scene.active_entities, active_idx);
            break;
        }
    }

    delete_key(&scene.entity_datas, eid);
    append(&scene.entity_datas_pool, data);
}

add_component_by_typeid :: proc(eid: Entity, tid: typeid, loc := #caller_location) -> ^Component_Base {
	ptr := _add_component_internal(eid, tid, loc);
	assert(ptr != nil);
	return ptr;
}
add_component :: proc(eid: Entity, $T: typeid, loc := #caller_location) -> ^T { // note(josh): volatile return value, do not store
    ptr := _add_component_internal(eid, typeid_of(T), loc);
    assert(ptr != nil);
    return cast(^T)ptr;
}

get_component :: proc(eid: Entity, $T: typeid, loc := #caller_location) -> (^T, bool) {
    ptr, ok := _get_component_internal(eid, typeid_of(T));
    return cast(^T)ptr, ok;
}

remove_component :: proc(eid: Entity, $T: typeid) -> bool {
    unimplemented();
    return {};
}

get_component_storage :: proc($T: typeid) -> []T {
    data, ok := component_types[typeid_of(T)];
    assert(ok, tprint("Couldn't find component type: ", type_info_of(T)));
    da := transmute([dynamic]T)data.storage;
    return da[:];
}

load_entity_from_file :: proc(filepath: string) -> Entity {
    // load file
    data, ok := os.read_entire_file(filepath);
    assert(ok);
    defer delete(data);

    // eat entity id
    lexer := laas.make_lexer(cast(string)data);
    eid_token, ok2 := laas.expect(&lexer, laas.Number);
    eid := transmute(Entity)eid_token.int_value;

    // eat entity name
    name_token, name_ok := laas.expect(&lexer, laas.Identifier);
    entity_name := "Entity";
    if !name_ok {
        logln("Entity ", eid, " didn't have a name in the file.");
    }
    else {
        entity_name = strings.clone(name_token.value);
    }

    // make it
    make_entity(entity_name, eid);

    // load the component data
    for {
        for laas.is_token(&lexer, laas.New_Line) do laas.eat(&lexer);
        component_name_ident, ok := laas.expect(&lexer, laas.Identifier);
        if !ok do break;

        nl, ok2 := laas.expect(&lexer, laas.New_Line);
        assert(ok2);

		ti := get_component_ti_from_name(component_name_ident.value);
		comp, found := _get_component_internal(eid, ti.id);
		if !found do comp = _add_component_internal(eid, ti.id);

        value := wbml.parse_value(&lexer);
        defer wbml.delete_node(value);
        wbml.write_value(value, comp, ti);
    }

    entity_data, ok4 := scene.entity_datas[eid];
    entity_data.serialized_file_on_disk = filepath;

    return eid;
}



//
// Internal
//

Scene :: struct {
    folder_path: string,

    entity_datas: map[Entity]^Entity_Data,
    entity_datas_pool: [dynamic]^Entity_Data,

    entity_component_list_pool: [dynamic][dynamic]typeid,

    active_entities:     [dynamic]int,
    entities_to_destroy: [dynamic]int,

    entity_files_to_destroy_on_save: [dynamic]string,
}

Entity_Data :: struct {
    name: string,
    enabled: bool,
    components: [dynamic]typeid,
    serialized_file_on_disk: string,
}
delete_entity_data :: proc(data: Entity_Data) {
    delete(data.name);
    delete(data.components);
    delete(data.serialized_file_on_disk);
}

Component_Type :: struct {
    ti: ^rt.Type_Info,
    storage: mem.Raw_Dynamic_Array,
    reusable_indices: [dynamic]int,

    update_proc: proc(rawptr, f32),
    render_proc: proc(rawptr),
    init_proc:   proc(rawptr),
    deinit_proc: proc(rawptr),
    editor_imgui_proc: proc(rawptr),
}
delete_component_type :: proc(type: Component_Type) {
    free(type.storage.data);
    delete(type.reusable_indices);
}

scene: ^Scene;
component_types: map[typeid]^Component_Type;

_add_component_internal :: proc(eid: Entity, tid: typeid, loc := #caller_location) -> ^Component_Base {
    assert(scene != nil);
    assert(eid != 0);

    ti := type_info_of(tid);

    if _, already_exists := _get_component_internal(eid, tid); already_exists {
        logln("Error: Cannot add more than one of the same component: ", ti, loc);
        return nil;
    }

    data, ok := component_types[tid];
    assert(ok, tprint("Couldn't find component type: ", ti));

    ptr: rawptr;
    if len(data.reusable_indices) > 0 {
        i := pop(&data.reusable_indices);
        ptr = mem.ptr_offset(cast(^u8)data.storage.data, i * ti.size);
    }
    else {
        if data.storage.len >= data.storage.cap {
            new_cap := data.storage.cap * 2;
            new_data := mem.alloc(new_cap * ti.size);
            mem.copy(new_data, data.storage.data, data.storage.len * ti.size);
            free(data.storage.data);
            data.storage.data = new_data;
            data.storage.cap = new_cap;
        }
        data.storage.len += 1;
        ptr = mem.ptr_offset(cast(^u8)data.storage.data, ti.size * (data.storage.len-1));
    }

    mem.zero(ptr, ti.size);

    base := cast(^Component_Base)ptr;
    base.e = eid;
    base.enabled = true;

    if data.init_proc != nil {
        data.init_proc(base);
    }

    e_data, ok2 := scene.entity_datas[eid];
    assert(ok2);
    append(&e_data.components, tid);

    return base;
}

_get_component_internal :: proc(eid: Entity, tid: typeid) -> (^Component_Base, bool) {
    if eid == 0 do return nil, false;

    ti := type_info_of(tid);
    data, ok := component_types[tid];
    assert(ok, tprint("Couldn't find component type: ", ti));

    for i in 0..<data.storage.len {
        ptr := cast(^Component_Base)mem.ptr_offset(cast(^u8)data.storage.data, i * ti.size);
        if ptr.e == eid {
            return ptr, true;
        }
    }
    return nil, false;
}

_copy_component_internal :: proc(dst: ^Component_Base, src: ^Component_Base, ti: ^rt.Type_Info) {
    tmp := dst^;
    deep_copy_except_pointers(dst, src, ti);
    dst^ = tmp;

    deep_copy_except_pointers :: proc(dst: rawptr, src: rawptr, ti: ^rt.Type_Info) {
        switch kind in ti.variant {
            case rt.Type_Info_Integer: {
                mem.copy(dst, src, ti.size);
            }
            case rt.Type_Info_Float: {
                mem.copy(dst, src, ti.size);
            }
            case rt.Type_Info_Rune: {
                mem.copy(dst, src, ti.size);
            }
            case rt.Type_Info_Boolean: {
                mem.copy(dst, src, ti.size);
            }
            case rt.Type_Info_Pointer: {
                mem.copy(dst, src, ti.size);
            }
            case rt.Type_Info_Array: {
                mem.copy(dst, src, ti.size);
            }
            case rt.Type_Info_Dynamic_Array: {
                array := (cast(^mem.Raw_Dynamic_Array)src)^;
                size := kind.elem_size * array.len;
                if size > 0 {
                    n := make([dynamic]u8, size);
                    mem.copy(&n[0], array.data, size);
                    (cast(^mem.Raw_Dynamic_Array)dst)^ = transmute(mem.Raw_Dynamic_Array)n;
                }
            }
            case rt.Type_Info_Slice: {
                slice := (cast(^mem.Raw_Slice)src)^;
                size := kind.elem_size * slice.len;
                if size > 0 {
                    n := make([]u8, size);
                    mem.copy(&n[0], slice.data, size);
                    (cast(^mem.Raw_Slice)dst)^ = transmute(mem.Raw_Slice)n;
                }
            }
            case rt.Type_Info_String: {
                str := strings.clone((cast(^string)src)^);
                (cast(^string)dst)^ = str;
            }
            case rt.Type_Info_Struct: {
                for t, i in kind.types {
                    tag := kind.tags[i];
                    if strings.contains(tag, "ecs_nocopyonclone") do continue;

                    offset := kind.offsets[i];
                    deep_copy_except_pointers(mem.ptr_offset(cast(^u8)dst, cast(int)offset), mem.ptr_offset(cast(^u8)src, cast(int)offset), t);
                }
            }
            case rt.Type_Info_Union: {
                unimplemented();
            }
            case rt.Type_Info_Enum: {
                mem.copy(dst, src, ti.size);
            }
            case rt.Type_Info_Named: deep_copy_except_pointers(dst, src, kind.base);
            case: panic(tprint(kind));
        }
    }
}

get_component_ti_from_name :: proc(name: string) -> ^rt.Type_Info {
	for tid, data in component_types {
		if tprint(data.ti) == name do return data.ti;
	}
	assert(false, tprint("Couldnt find: ", name)); // todo(josh): handle components that exist on an entity but have been deleted
	return nil;
}



@private
@(deferred_out=delete_APRINT)
APRINT :: proc(args: ..any) -> string {
    return aprint(..args);
}

@private
delete_APRINT :: proc(str: string) {
    delete(str);
}
