package workbench

import "core:sys/win32"
import "core:strings"
import "core:os"
import rt "core:runtime"
import "core:mem"
import "core:fmt"
import "gpu"
import "wbml"
import "profiler"
import "laas"
import "basic"

// todo(josh): @Leak: we don't currently delete assets when their file is deleted, we just remove the Loaded_Asset which is just a path and timestamp :DeleteAssetWhenFileIsDeleted

@(private)
initted := false;

asset_handlers: [dynamic]Asset_Handler;
tracked_files: map[string]Tracked_File;
yielded_files: [dynamic]string;

Tracked_File :: struct {
	path: string,
	last_write_time: os.File_Time,
	reference_count: int,
	asset: any, // may be null, only loaded if reference_count > 0
}

Asset_Load_Proc   :: #type proc([]byte, Asset_Load_Context) -> (rawptr, Asset_Load_Result);
Asset_Delete_Proc :: #type proc(asset: rawptr);
Asset_Handler :: struct {
	extensions: []string,
	type_info: ^rt.Type_Info,
	load_proc: Asset_Load_Proc,
	delete_proc: Asset_Delete_Proc,
}

Asset_Load_Context :: struct {
	file_name: string,
	extension: string,
}

init_asset_system :: proc() {
	assert(!initted);
	initted = true;

	add_asset_handler(Texture,      {"png"},                       catalog_load_texture,  catalog_delete_texture);
	add_asset_handler(Font,         {"ttf"},                       catalog_load_font,     catalog_delete_font);
	add_asset_handler(Model,        {"fbx"},                       catalog_load_model,    catalog_delete_model);
	add_asset_handler(Shader_Asset, {"shader", "compute", "glsl"}, catalog_load_shader,   catalog_delete_shader);
	// add_asset_handler(Cubemap_Spec, {"wb_cubemap"},                catalog_load_cubemap,  catalog_delete_cubemap);
}

add_asset_handler :: proc($Type: typeid, extensions: []string, load_proc: proc([]byte, Asset_Load_Context) -> (^Type, Asset_Load_Result), delete_proc: proc(^Type)) {
	ti := type_info_of(Type);
	for handler in asset_handlers {
		if handler.type_info == ti {
			panic(tprint("Duplicate handlers for type: ", ti));
		}
	}

	append(&asset_handlers, Asset_Handler{extensions, ti, cast(Asset_Load_Proc)load_proc, cast(Asset_Delete_Proc)delete_proc});
}

/*
//todo(josh): deletion

delete_all_assets :: proc() {
	for ti, handler in catalog.handlers {
		for _, asset in handler.assets {
			handler.delete_proc(asset);
		}
		delete(handler.assets);
	}
	delete(catalog.handlers);
}

delete_asset_catalog :: proc() {


	for f in catalog.loaded_files {
		delete_loaded_file(f);
	}
	delete(catalog.loaded_files);

	for e in catalog.errors {
		delete(e);
	}
	delete(catalog.errors);
}

delete_loaded_file :: proc(file: Loaded_File) {
	delete(file.path);
}
*/

track_asset_folder :: proc(path: string, loc := #caller_location) {
	files := basic.get_all_filepaths_recursively(path);
	defer delete(files); // note(josh): dont delete the elements in `files` because they get stored in Asset_Catalog.loaded_files

	filepath_loop:
	for filepath in files {
		name, nameok := basic.get_file_name(filepath);
		assert(nameok, filepath);
		ext, extok := basic.get_file_extension(filepath);
		assert(extok, filepath);
		name_and_ext, neok := basic.get_file_name_and_extension(filepath);
		assert(neok, filepath);

		// make sure there is a handler for this asset type. if there isn't, we don't care about it
		handler_loop:
		for handler in asset_handlers {
			for handler_ext in handler.extensions {
				if handler_ext == ext {
					if name in tracked_files {
						logln("Name collision: ", name);
						continue filepath_loop; // @Leak the filepath
					}

					// now that we know there's a handler for this asset type, add it to the list of tracked files
					last_write_time, err := os.last_write_time_by_name(filepath);
					assert(err == 0);
					tracked_files[name] = Tracked_File{filepath, last_write_time, 0, nil};
					continue filepath_loop;
				}
			}
		}
	}

	// todo(josh): replace this with proper reference counting, we are just loading everything by default
	for name, tracked_file in tracked_files {
		add_reference(name);
	}

	flush_reference_changes();
}

// note(josh): use this procedure sparingly, it doesn't work for hotloading, it is meant for manually jamming assets into the asset system
force_add_asset :: proc($Type: typeid, name: string, asset: ^Type) {
	assert(name notin tracked_files);
	tracked_files[strings.clone(name)] = Tracked_File{"", 0, 1, any{asset, typeid_of(Type)}};
}

add_reference :: proc(name: string) {
	assert(name in tracked_files);
	tracked_file := &tracked_files[name];
	tracked_file.reference_count += 1;
}

subtract_reference :: proc(name: string) {
	assert(name in tracked_files);
	tracked_file := &tracked_files[name];
	tracked_file.reference_count += 1;
}

flush_reference_changes :: proc() {
	to_load: [dynamic]string;
	defer delete(to_load);

	for name, file in &tracked_files {
		if file.reference_count > 0 && file.asset == nil {
			append(&to_load, name);
		}
		else if file.reference_count == 0 && file.asset != nil {
			unload_asset(file.asset);
			file.asset = nil;
		}
	}

	for len(to_load) > 0 {
		for idx := len(to_load)-1; idx >= 0; idx -= 1 {
			name := to_load[idx];
			file := &tracked_files[name];

			// load the asset
			asset, result := load_asset_from_file(file.path);
			switch result {
				case .Ok: {
					file.asset = asset;
					unordered_remove(&to_load, idx);
				}
				case .Error: {
					logln("Error loading file: ", file.path);
					unordered_remove(&to_load, idx);
				}
				case .Yield: {
					// logln("Yielding file: ", file.path);
				}
				case .No_Handler: {
					logln("No handler for file: ", file.path);
					unimplemented();
				}
				case: panic(tprint(result));
			}
		}
	}
}

try_get_asset :: proc($Type: typeid, name: string) -> (Type, bool) {
	if name == "" do return {}, false;

	tracked_file, ok := tracked_files[name];
	if !ok do return {}, false;

	if tracked_file.asset == nil do return {}, false;

	if asset, ok := tracked_file.asset.(Type); ok {
		return asset, true;
	}

	return {}, false;
}

get_asset :: proc($Type: typeid, name: string, loc := #caller_location) -> Type {
	asset, ok := try_get_asset(Type, name);
	assert(ok, fmt.tprint("Couldn't find asset: ", name, loc));
	return asset;
}

try_get_texture :: proc(name: string) -> (Texture, bool) {
	return try_get_asset(Texture, name);
}
get_texture :: inline proc(name: string) -> Texture {
	return get_asset(Texture, name);
}

try_get_model :: proc(name: string) -> (Model, bool) {
	return try_get_asset(Model, name);
}
get_model :: inline proc(name: string) -> Model {
	return get_asset(Model, name);
}

try_get_font :: proc(name: string) -> (Font, bool) {
	return try_get_asset(Font, name);
}
get_font :: inline proc(name: string) -> Font {
	return get_asset(Font, name);
}

try_get_shader :: proc(name: string) -> (gpu.Shader_Program, bool) {
	asset, ok := try_get_asset(Shader_Asset, name);
	if ok do return asset.id, true;
	return {}, false;
}
get_shader :: inline proc(name: string) -> gpu.Shader_Program {
	return get_asset(Shader_Asset, name).id;
}



Asset_Load_Result :: enum {
	Ok,
	Error,
	No_Handler,
	Yield,
}

load_asset_from_file :: proc(filepath: string) -> (any, Asset_Load_Result) {
	name, nameok := basic.get_file_name(filepath);
	assert(nameok, filepath);
	ext, extok := basic.get_file_extension(filepath);
	assert(extok, filepath);
	name_and_ext, neok := basic.get_file_name_and_extension(filepath);
	assert(neok, filepath);

	// load the file data
	data, fileok := os.read_entire_file(filepath);
	defer delete(data);
	if !fileok {
		logln("Error: os.read_entire_file() of ", filepath, " returned false. Yielding.");
		return nil, .Yield;
	}
	if len(data) == 0 {
		logln("Error: os.read_entire_file() of ", filepath, " returned 0 length. Yielding.");
		return nil, .Yield;
	}

	// find the handler type and call the load proc
	handler_loop:
	for handler in &asset_handlers {
		for handler_extension in handler.extensions {
			if handler_extension == ext {
				asset, result := handler.load_proc(data, Asset_Load_Context{name, ext});

				switch result {
					case .Ok: {
						return any{asset, handler.type_info.id}, result;
					}
					case .Error: {
						assert(asset == nil);
						return nil, result;
					}
					case .Yield: {
						assert(asset == nil);
						return nil, result;
					}
					case .No_Handler: {
						panic("Handler load proc should never return No_Handler");
						return nil, result;
					}
					case: panic(tprint(result));
				}

				unreachable();
				return {}, {};
			}
		}
	}

	panic(tprint("No handler for extension: ", ext));
	return {}, {};
}

unload_asset :: proc(asset: any) {
	assert(asset != nil);
	raw_any := transmute(mem.Raw_Any)asset;
	ti := type_info_of(raw_any.id);
	handler, ok := try_get_asset_handler(ti);
	assert(ok);
	handler.delete_proc(raw_any.data);

	try_get_asset_handler :: proc(ti: ^rt.Type_Info) -> (Asset_Handler, bool) {
		for handler in asset_handlers {
			if handler.type_info == ti do return handler, true;
		}
		return {}, false;
	}
}

check_for_file_updates :: proc() {
	profiler.TIMED_SECTION(&wb_profiler);
	for name, tracked_file in &tracked_files {
		if tracked_file.asset == nil do continue;

		if tracked_file.path != "" { // note(josh): some assets are put into the asset system manually and thus don't have a matching file on disk
			new_last_write_time, err := os.last_write_time_by_name(tracked_file.path);
			if err != 0 {
				// the file was deleted!!

				// :DeleteAssetWhenFileIsDeleted

				logln("File was deleted, leaking the asset: ", tracked_file.path);
				tracked_file.asset = nil;
			}
			else {
				if new_last_write_time > tracked_file.last_write_time {
					asset, result := load_asset_from_file(tracked_file.path);
					switch result {
						case .Ok: {
							assert(tracked_file.asset != nil);
							unload_asset(tracked_file.asset);
							tracked_file.asset = asset;
							tracked_file.last_write_time = new_last_write_time;
							logln("File updated: ", tracked_file.path);
						}
						case .Error: {
							tracked_file.last_write_time = new_last_write_time;
							logln("Error loading file: ", tracked_file.path);
						}
						case .No_Handler: panic("load_proc should never return No_Handler");
						case .Yield:      logln("Yielding file: ", tracked_file.path);
					}
				}
			}
		}
	}
}



// todo(josh): we currently individually allocate each asset which is a little wasteful, could back these by an arena or something

catalog_load_texture :: proc(data: []byte, ctx: Asset_Load_Context) -> (^Texture, Asset_Load_Result) {
	texture := create_texture_from_png_data(data);
	return new_clone(texture), .Ok;
}
catalog_delete_texture :: proc(texture: ^Texture) {
	delete_texture(texture^);
	free(texture);
}



catalog_load_font :: proc(data: []byte, ctx: Asset_Load_Context) -> (^Font, Asset_Load_Result) {
	font := load_font(data, 128); // todo(josh): multiple sizes for fonts? probably would be good
	return new_clone(font), .Ok;
}
catalog_delete_font :: proc(font: ^Font) {
	delete_font(font^);
	free(font);
}



catalog_load_model :: proc(data: []byte, ctx: Asset_Load_Context) -> (^Model, Asset_Load_Result) {
	model := load_model_from_memory(data, ctx.file_name);
	return new_clone(model), .Ok;
}
catalog_delete_model :: proc(model: ^Model) {
	delete_model(model^);
	free(model);
}



// Cubemap_Asset :: struct {
// 	texture: Texture,
// }

// catalog_load_cubemap :: proc(data: []byte, ctx: Asset_Load_Context) -> (^Cubemap_Asset, Asset_Load_Result) {
// 	Cubemap_Spec :: struct {
// 		front, back, left, right, top, bottom: string,
// 	};

// 	spec := wbml.deserialize(Cubemap_Spec, data);


// 	texture := create_cubemap();

// 	unimplemented();
// 	return {}, {};
// }
// catalog_delete_cubemap :: proc(spec: ^Cubemap_Asset) {
// 	delete_texture(spec.texture);
// 	free(spec);
// }



Shader_Asset :: struct {
	id: gpu.Shader_Program,
	text: string,
}

catalog_load_shader :: proc(data: []byte, ctx: Asset_Load_Context) -> (^Shader_Asset, Asset_Load_Result) {
	switch ctx.extension {
		case "shader": {
			shader, result := parse_shader(cast(string)data, ctx);
			if result != .Ok {
				return nil, result;
			}
			return new_clone(shader), .Ok;
		}
		case "compute": {
			shader, ok := gpu.load_shader_compute(cast(string)data);
			if !ok {
				return nil, .Error;
			}
			return new_clone(Shader_Asset{shader, strings.clone(cast(string)data)}), .Ok; // todo(josh): this clone() is kinda lame but the asset system deletes file data by default. a way to override that might be nice?
		}
		case "glsl": {
			// .glsl is not meant to be a shader all on its own but rather purely for @include-ing
			return new_clone(Shader_Asset{0, strings.clone(cast(string)data)}), .Ok; // todo(josh): this clone() is kinda lame but the asset system deletes file data by default. a way to override that might be nice?
		}
		case: {
			panic(ctx.extension);
		}
	}
	unreachable();
	return {}, .Error;
}
catalog_delete_shader :: proc(shader: ^Shader_Asset) {
	// todo(josh): figure out why deleting shaders was causing errors
	// gpu.delete_shader(catalog.shaders[name]);
	delete(shader.text);
	free(shader);
}

parse_shader :: proc(text: string, ctx: Asset_Load_Context) -> (Shader_Asset, Asset_Load_Result) {

	process_includes :: proc(builder: ^strings.Builder, text: string, ctx: Asset_Load_Context) -> Asset_Load_Result {
		assert(builder != nil);

		lines := strings.split(text, "\n");
		defer delete(lines);
		for line in lines {
			if basic.string_starts_with(line, "@include") {
				rest_of_line := line[len("@include "):];
				assert(len(rest_of_line) > 0);
				lexer := laas.make_lexer(rest_of_line);
				file_to_include := laas.expect_string(&lexer);
				file_name, fnok := basic.get_file_name(file_to_include);
				assert(fnok, file_name);

				shader_asset, ok := try_get_asset(Shader_Asset, file_name);
				if !ok {
					return .Yield;
				}

				result := process_includes(builder, shader_asset.text, ctx);
				if result != .Ok {
					return result;
				}
			}
			else {
				fmt.sbprint(builder, line, "\n");
			}
		}

		return .Ok;
	}

	all_text_builder: strings.Builder; // note(josh): we don't destroy this builder because the text is stored in the Shader_Asset. we DO destroy it in the case of a Yield though
	result := process_includes(&all_text_builder, text, ctx);
	if result == .Yield {
		strings.destroy_builder(&all_text_builder);
		return {}, .Yield;
	}

	assert(result == .Ok);

	all_text := strings.to_string(all_text_builder);

	vertex_builder:   strings.Builder; defer strings.destroy_builder(&vertex_builder);
	fragment_builder: strings.Builder; defer strings.destroy_builder(&fragment_builder);
	geometry_builder: strings.Builder; defer strings.destroy_builder(&geometry_builder);
	current_builder: ^strings.Builder;

	lines := strings.split(all_text, "\n");
	defer delete(lines);
	for line in lines {
		if basic.string_starts_with(line, "@vert") {
			current_builder = &vertex_builder;
		}
		else if basic.string_starts_with(line, "@frag") {
			current_builder = &fragment_builder;
		}
		else if basic.string_starts_with(line, "@geom") {
			current_builder = &geometry_builder;
		}
		else {
			if current_builder != nil {
				fmt.sbprint(current_builder, line, "\n");
			}
		}
	}

	vert_source := strings.to_string(vertex_builder);
	frag_source := strings.to_string(fragment_builder);
	geo_source := strings.to_string(geometry_builder);

	assert(vert_source != "");
	assert(frag_source != "");

	if geo_source != "" {
		shader, compileok := gpu.load_shader_vert_geo_frag(vert_source, geo_source, frag_source);
		if compileok {
			return Shader_Asset{shader, strings.to_string(all_text_builder)}, .Ok;
		}
	} else {
		shader, compileok := gpu.load_shader_vert_frag(strings.to_string(vertex_builder), strings.to_string(fragment_builder));
		if compileok {
			return Shader_Asset{shader, strings.to_string(all_text_builder)}, .Ok;
		}
	}

	logln("Error loading shader: '", ctx.file_name, "' failed to compile.");
	return {}, .Error;
}