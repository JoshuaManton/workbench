package workbench

import "core:sys/win32"
import "core:strings"
import "core:os"
import rt "core:runtime"
import "core:mem"
import "core:fmt"
import "gpu"
import "profiler"
import "laas"
import "basic"

// todo(josh): @Leak: we don't currently delete the asset, we just remove the Loaded_Asset which is just a path and timestamp :DeleteAssetWhenFileIsDeleted

Asset_Catalog :: struct {
	handlers: map[^rt.Type_Info]Asset_Handler,
	loaded_files: [dynamic]Loaded_File,
	errors: [dynamic]string,
	has_default_handlers: bool,
}
Loaded_File :: struct {
	path: string,
	last_write_time: os.File_Time,
}

Asset_Load_Proc   :: #type proc([]byte, Asset_Load_Context) -> (rawptr, Asset_Load_Result);
Asset_Delete_Proc :: #type proc(asset: rawptr);
Asset_Handler :: struct {
	assets: map[string]rawptr,

	extensions: []string,
	load_proc: Asset_Load_Proc,
	delete_proc: Asset_Delete_Proc,
}

Asset_Load_Context :: struct {
	file_name: string,
	extension: string,
	catalog: ^Asset_Catalog,
}

add_default_handlers :: proc(catalog: ^Asset_Catalog) {
	add_asset_handler(catalog, Texture,      {"png"},                       catalog_load_texture, catalog_delete_texture);
	add_asset_handler(catalog, Font,         {"ttf"},                       catalog_load_font,    catalog_delete_font);
	add_asset_handler(catalog, Model,        {"fbx"},                       catalog_load_model,   catalog_delete_model);
	add_asset_handler(catalog, Shader_Asset, {"shader", "compute", "glsl"}, catalog_load_shader,  catalog_delete_shader);
}

add_asset_handler :: proc(catalog: ^Asset_Catalog, $Type: typeid, extensions: []string, load_proc: proc([]byte, Asset_Load_Context) -> (^Type, Asset_Load_Result), delete_proc: proc(^Type)) {
	ti := type_info_of(Type);
	assert(ti notin catalog.handlers);
	catalog.handlers[ti] = Asset_Handler{make(map[string]rawptr, 10), extensions, cast(Asset_Load_Proc)load_proc, cast(Asset_Delete_Proc)delete_proc};
}

delete_asset_catalog :: proc(catalog: Asset_Catalog) {
	for ti, handler in catalog.handlers {
		for _, asset in handler.assets {
			handler.delete_proc(asset);
		}
		delete(handler.assets);
	}
	delete(catalog.handlers);

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

load_asset_folder :: proc(path: string, catalog: ^Asset_Catalog, loc := #caller_location) {
	if !catalog.has_default_handlers {
		catalog.has_default_handlers = true;
		add_default_handlers(catalog);
	}

	files := basic.get_all_filepaths_recursively(path);
	defer delete(files); // note(josh): dont delete the elements in `files` because they get stored in Asset_Catalog.loaded_files

	for file in files {
		last_write_time, err := os.last_write_time_by_name(file);
		assert(err == 0);
		append(&catalog.loaded_files, Loaded_File{file, last_write_time});
	}

	for len(files) > 0 {
		len_before := len(files);

		for e in catalog.errors {
			delete(e);
		}
		clear(&catalog.errors);

		for file_idx := len(files)-1; file_idx >= 0; file_idx -= 1 {
			filepath := files[file_idx];

			result := load_asset_from_file(catalog, filepath);
			switch result {
				case .Ok: {
					basic.slice_unordered_remove(&files, file_idx);
				}
				case .Error: {
				}
				case .Yield: {
				}
				case .No_Handler: {
					basic.slice_unordered_remove(&files, file_idx);
				}
				case: panic(tprint(result));
			}
		}

		len_after := len(files);
		if len_after >= len_before {
			catalog_flush_errors(catalog);
			break;
		}
	}
}

catalog_flush_errors :: proc(catalog: ^Asset_Catalog) {
	for e in catalog.errors {
		logln("Catalog error: ", e);
		delete(e);
	}
	clear(&catalog.errors);
}



Shader_Asset :: struct {
	id: gpu.Shader_Program,
	text: string,
}

Asset_Load_Result :: enum {
	Ok,
	Error,
	No_Handler,
	Yield,
}

load_asset_from_file :: proc(catalog: ^Asset_Catalog, filepath: string) -> Asset_Load_Result {
	name, nameok := basic.get_file_name(filepath);
	assert(nameok, filepath);
	ext, extok := basic.get_file_extension(filepath);
	assert(extok, filepath);
	name_and_ext, neok := basic.get_file_name_and_extension(filepath);
	assert(neok, filepath);

	data, fileok := os.read_entire_file(filepath);
	assert(fileok);
	defer delete(data);

	res := load_asset(catalog, name, ext, data);
	return res;
}

load_asset :: proc(catalog: ^Asset_Catalog, name: string, ext: string, data: []byte) -> Asset_Load_Result {
	handler_loop: for ti in catalog.handlers {
		handler := catalog.handlers[ti];
		defer catalog.handlers[ti] = handler; // ugh, PLEASE GIVE MAP POINTERS BILL

		for handler_extension in handler.extensions {
			if handler_extension == ext {
				asset, result := handler.load_proc(data, Asset_Load_Context{name, ext, catalog});
				switch result {
					case .Ok: {
						assert(asset != nil);
						if name in handler.assets {
							logln("New asset with name '", name, "'. Deleting old one.");
							handler.delete_proc(handler.assets[name]);
						}

						handler.assets[name] = asset;
					}
					case .Error: {
						assert(asset == nil);
					}
					case .Yield: {
						assert(asset == nil);
					}
					case .No_Handler: {
						panic("Handler load proc should never return No_Handler");
					}
					case: panic(tprint(result));
				}

				return result;
			}
		}
	}

	return .No_Handler;
}

add_asset :: proc($Type: typeid, catalog: ^Asset_Catalog, name: string, asset: ^Type) {
	ti := type_info_of(Type);
	handler, hok := catalog.handlers[ti];
	assert(hok);
	defer catalog.handlers[ti] = handler;

	assert(name notin handler.assets);
	handler.assets[name] = asset;
}

try_get_asset :: proc($Type: typeid, catalog: ^Asset_Catalog, name: string) -> (Type, bool) {
	ti := type_info_of(Type);
	handler, ok := catalog.handlers[ti];
	assert(ok, name);

	if asset, ok := handler.assets[name]; ok {
		return (cast(^Type)asset)^, true;
	}
	else {
		// fall back to the wb_catalog
		handler, ok := wb_catalog.handlers[ti];
		assert(ok);
		if asset, ok := handler.assets[name]; ok {
			return (cast(^Type)asset)^, true;
		}
	}

	return {}, false;
}

get_asset :: proc($Type: typeid, catalog: ^Asset_Catalog, name: string, loc := #caller_location) -> Type {
	asset, ok := try_get_asset(Type, catalog, name);
	assert(ok, fmt.tprint("Couldn't find asset: ", name, loc));
	return asset;
}



check_for_file_updates :: proc(catalog: ^Asset_Catalog) {
	profiler.TIMED_SECTION(&wb_profiler);
	for idx := len(catalog.loaded_files)-1; idx >= 0; idx -= 1 {
		file := &catalog.loaded_files[idx];
		new_last_write_time, err := os.last_write_time_by_name(file.path);
		if err != 0 {
			// the file was deleted!!

			// :DeleteAssetWhenFileIsDeleted

			delete_loaded_file(file^);
			unordered_remove(&catalog.loaded_files, idx);
		}
		else {
			if new_last_write_time > file.last_write_time {
				logln("file update: ", file.path);
				file.last_write_time = new_last_write_time;
				load_asset_from_file(catalog, file.path);
			}
		}
	}

	catalog_flush_errors(catalog);
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

				shader_asset, ok := try_get_asset(Shader_Asset, ctx.catalog, file_name);
				if !ok {
					catalog_error(ctx.catalog, "Couldn't find file for include: '", file_to_include, "' in shader '", ctx.file_name, "'.");
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

	catalog_error(ctx.catalog, "Shader '", ctx.file_name, "' failed to compile.");
	return {}, .Error;
}

catalog_error :: proc(catalog: ^Asset_Catalog, args: ..any) {
	append(&catalog.errors, fmt.aprint(..args));
}



try_get_texture :: proc(catalog: ^Asset_Catalog, name: string) -> (Texture, bool) {
	return try_get_asset(Texture, catalog, name);
}
get_texture :: inline proc(catalog: ^Asset_Catalog, name: string) -> Texture {
	return get_asset(Texture, catalog, name);
}

try_get_model :: proc(catalog: ^Asset_Catalog, name: string) -> (Model, bool) {
	return try_get_asset(Model, catalog, name);
}
get_model :: inline proc(catalog: ^Asset_Catalog, name: string) -> Model {
	return get_asset(Model, catalog, name);
}

try_get_font :: proc(catalog: ^Asset_Catalog, name: string) -> (Font, bool) {
	return try_get_asset(Font, catalog, name);
}
get_font :: inline proc(catalog: ^Asset_Catalog, name: string) -> Font {
	return get_asset(Font, catalog, name);
}

try_get_shader :: proc(catalog: ^Asset_Catalog, name: string) -> (gpu.Shader_Program, bool) {
	asset, ok := try_get_asset(Shader_Asset, catalog, name);
	if ok do return asset.id, true;
	return {}, false;
}
get_shader :: inline proc(catalog: ^Asset_Catalog, name: string) -> gpu.Shader_Program {
	return get_asset(Shader_Asset, catalog, name).id;
}