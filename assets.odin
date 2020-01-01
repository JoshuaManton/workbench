package workbench

      import "core:sys/win32"
      import "core:strings"
      import "core:os"
      import rt "core:runtime"
      import "core:mem"
using import "core:fmt"
using import "logging"
      import "gpu"
      import "profiler"
      import "laas"
using import "basic"

Asset_Catalog :: struct {
	handlers: map[^rt.Type_Info]Asset_Handler,
	loaded_files: [dynamic]Loaded_File,
}
Loaded_File :: struct {
	path: string,
	last_write_time: os.File_Time,
}

Asset_Load_Proc   :: #type proc([]byte, Asset_Load_Context) -> rawptr;
Asset_Delete_Proc :: #type proc(asset: rawptr);
Asset_Handler :: struct {
	assets: map[string]rawptr,

	extensions: []string,
	load_proc: Asset_Load_Proc,
	delete_proc: Asset_Delete_Proc,
}

Asset_Load_Context :: struct {
	file_name: string,
	root_directory: string,
	extension: string,
}

add_asset_handler :: proc(catalog: ^Asset_Catalog, $Type: typeid, extensions: []string, load_proc: proc([]byte, Asset_Load_Context) -> ^Type, delete_proc: proc(^Type)) {
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
		delete(f.path);
	}
	delete(catalog.loaded_files);
}

load_asset_folder :: proc(path: string, catalog: ^Asset_Catalog, loc := #caller_location) {
	if catalog.handlers == nil {
		add_asset_handler(catalog, Texture,            {"png"},               catalog_load_texture, catalog_delete_texture);
		add_asset_handler(catalog, Font,               {"ttf"},               catalog_load_font,    catalog_delete_font);
		add_asset_handler(catalog, Model,              {"fbx"},               catalog_load_model,   catalog_delete_model);
		add_asset_handler(catalog, gpu.Shader_Program, {"shader", "compute"}, catalog_load_shader,  catalog_delete_shader);
	}

	files := get_all_filepaths_recursively(path);
	defer delete(files); // note(josh): dont delete the elements in `files` because they get stored in Asset_Catalog.loaded_files

	for filepath in files {
		last_write_time, err := os.last_write_time_by_name(filepath);
		assert(err == 0);
		append(&catalog.loaded_files, Loaded_File{filepath, last_write_time});

		load_asset(catalog, filepath);
	}
}

load_asset :: proc(catalog: ^Asset_Catalog, filepath: string) {
	name, nameok := get_file_name(filepath);
	assert(nameok, filepath);
	ext, extok := get_file_extension(filepath);
	assert(extok, filepath);
	root_directory, dirok := get_file_directory(filepath);
	assert(dirok, filepath);
	name_and_ext, neok := get_file_name_and_extension(filepath);
	assert(neok, filepath);

	data, fileok := os.read_entire_file(filepath);
	assert(fileok);
	defer delete(data);

	handler_loop: for ti in catalog.handlers {
		handler := catalog.handlers[ti];
		defer catalog.handlers[ti] = handler; // ugh, PLEASE GIVE MAP POINTERS BILL

		for handler_extension in handler.extensions {
			if handler_extension == ext {
				if name in handler.assets {
					logln("New asset with name '", name, "'. Deleting old one.");
					handler.delete_proc(handler.assets[name]);
				}

				asset := handler.load_proc(data, Asset_Load_Context{name, root_directory, ext});
				if asset != nil {
					handler.assets[name] = asset;
				}
				else {
					logln("Loading asset '", name, "' failed.");
				}

				break handler_loop;
			}
		}
	}
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
	assert(ok);

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

get_asset :: proc($Type: typeid, catalog: ^Asset_Catalog, name: string) -> Type {
	asset, ok := try_get_asset(Type, catalog, name);
	assert(ok, tprint("Couldn't find asset: ", name));
	return asset;
}



check_for_file_updates :: proc(catalog: ^Asset_Catalog) {
	profiler.TIMED_SECTION(&wb_profiler);
	for _, idx in catalog.loaded_files {
		file := &catalog.loaded_files[idx];
		new_last_write_time, err := os.last_write_time_by_name(file.path);
		assert(err == 0); // todo(josh): check for deleted files?
		if new_last_write_time > file.last_write_time {
			logln("file update: ", file.path);
			file.last_write_time = new_last_write_time;
			load_asset(catalog, file.path);
		}
	}
}



// todo(josh): we currently individually allocate each asset which is a little wasteful, could back these by an arena or something

catalog_load_texture :: proc(data: []byte, ctx: Asset_Load_Context) -> ^Texture {
	texture := create_texture_from_png_data(data);
	return new_clone(texture);
}
catalog_delete_texture :: proc(texture: ^Texture) {
	delete_texture(texture^);
	free(texture);
}

catalog_load_font :: proc(data: []byte, ctx: Asset_Load_Context) -> ^Font {
	font := load_font(data, 54); // todo(josh): multiple sizes for fonts? probably would be good
	return new_clone(font);
}
catalog_delete_font :: proc(font: ^Font) {
	delete_font(font^);
	free(font);
}

catalog_load_model :: proc(data: []byte, ctx: Asset_Load_Context) -> ^Model {
	model := load_model_from_memory(data, ctx.file_name);
	return new_clone(model);
}
catalog_delete_model :: proc(model: ^Model) {
	delete_model(model^);
	free(model);
}

catalog_load_shader :: proc(data: []byte, ctx: Asset_Load_Context) -> ^gpu.Shader_Program {
	switch ctx.extension {
		case "shader": {
			shader, ok := parse_shader(cast(string)data, ctx.root_directory);
			if !ok {
				return nil;
			}
			return new_clone(shader);
		}
		case "compute": {
			shader, ok := gpu.load_shader_compute(cast(string)data);
			if !ok {
				return nil;
			}
			return new_clone(shader);
		}
		case: {
			panic(ctx.extension);
		}
	}
	unreachable();
	return {};
}
catalog_delete_shader :: proc(shader: ^gpu.Shader_Program) {
	// todo(josh): figure out why deleting shaders was causing errors
	// gpu.delete_shader(catalog.shaders[name]);
	free(shader);
}

Parse_Shader_Result :: enum {
	Yield,
	Done,
	Error,
}

parse_shader :: proc(text: string, root_folder: string) -> (gpu.Shader_Program, bool) {

	// todo(josh): would be great to be able to @include wb shaders from user code. hmmmmmm.


	process_includes :: proc(builder: ^strings.Builder, text: string, root_folder: string) -> bool {
		assert(builder != nil);

		lines := strings.split(text, "\n");
		defer delete(lines);
		for line in lines {
			if string_starts_with(line, "@include") {
				rest_of_line := line[len("@include "):];
				assert(len(rest_of_line) > 0);
				lexer := laas.make_lexer(rest_of_line);
				file_to_include := laas.expect_string(&lexer);
				file_path := tprint(root_folder, "/", file_to_include);
				file_data, ok := os.read_entire_file(file_path);
				defer delete(file_data);

				if !ok {
					logln("Error: Couldn't find file for include: ", file_to_include);
					return false;
				}

				process_includes(builder, cast(string)file_data, root_folder);
			}
			else {
				sbprint(builder, line, "\n");
			}
		}

		return true;
	}

	all_text_builder: strings.Builder;
	defer strings.destroy_builder(&all_text_builder);

	ok := process_includes(&all_text_builder, text, root_folder);
	if !ok do return {}, false;

	all_text := strings.to_string(all_text_builder);

	vertex_builder: strings.Builder;   defer strings.destroy_builder(&vertex_builder);
	fragment_builder: strings.Builder; defer strings.destroy_builder(&fragment_builder);
	current_builder: ^strings.Builder;

	lines := strings.split(all_text, "\n");
	defer delete(lines);
	for line in lines {
		if string_starts_with(line, "@vert") {
			current_builder = &vertex_builder;
		}
		else if string_starts_with(line, "@frag") {
			current_builder = &fragment_builder;
		}
		else {
			if current_builder != nil {
				sbprint(current_builder, line, "\n");
			}
		}
	}

	assert(strings.to_string(vertex_builder) != "");
	assert(strings.to_string(fragment_builder) != "");

	shader, compileok := gpu.load_shader_vert_frag(strings.to_string(vertex_builder), strings.to_string(fragment_builder));
	return shader, compileok;
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
	return try_get_asset(gpu.Shader_Program, catalog, name);
}
get_shader :: inline proc(catalog: ^Asset_Catalog, name: string) -> gpu.Shader_Program {
	return get_asset(gpu.Shader_Program, catalog, name);
}