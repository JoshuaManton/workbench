package workbench

      import "core:sys/win32"
      import "core:strings"
      import "core:os"
      import "core:mem"
using import "core:fmt"
using import "logging"
      import "gpu"
      import "profiler"
      import "laas"
using import "basic"

Asset_Catalog :: struct {
	textures:   map[string]Texture,
	models:     map[string]Model,
	fonts:      map[string]Font,
	shaders:    map[string]gpu.Shader_Program,
	text_files: map[string]string,

	text_file_types: []string,

	loaded_files: [dynamic]Loaded_File,
}

Loaded_File :: struct {
	path: string,
	last_write_time: os.File_Time,
}

delete_asset_catalog :: proc(catalog: Asset_Catalog) {
	for _, texture in catalog.textures {
		delete_texture(texture);
	}
	for _, model in catalog.models {
		delete_model(model);
	}
	for _, font in catalog.fonts {
		delete_font(font);
	}
	for _, shader in catalog.shaders {
		// todo(josh): figure out why deleting shaders was causing errors
		// gpu.delete_shader(shader);
	}
	for _, text in catalog.text_files {
		delete(text);
	}
	for f in catalog.loaded_files {
		delete(f.path);
	}

	for t in catalog.text_file_types {
		delete(t);
	}

	delete(catalog.textures);
	delete(catalog.models);
	delete(catalog.fonts);
	delete(catalog.shaders);
	delete(catalog.text_files);
	delete(catalog.loaded_files);
	delete(catalog.text_file_types);
}

load_asset_folder :: proc(path: string, catalog: ^Asset_Catalog, text_file_types: ..string, loc := #caller_location) {
	files := get_all_filepaths_recursively(path);
	defer delete(files); // note(josh): dont delete the elements in `files` because they get stored in Asset_Catalog.loaded_files

	assert(catalog.text_file_types == nil);
	catalog.text_file_types = make([]string, len(text_file_types));
	for _, idx in text_file_types do catalog.text_file_types[idx] = aprint(text_file_types[idx]);

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

	switch ext {
		case "png": {
			defer delete(data);
			texture := create_texture_from_png_data(data);
			if name in catalog.textures {
				logln("New texture with name '", name, "'. Deleting old one.");
				delete_texture(catalog.textures[name]);
			}
			catalog.textures[name] = texture;
		}
		case "ttf": {
			defer delete(data);
			font := load_font(data, 32); // todo(josh): multiple sizes for fonts? probably would be good
			if name in catalog.textures {
				logln("New font with name '", name, "'. Deleting old one.");
				delete_texture(catalog.textures[name]);
			}
			catalog.fonts[name] = font;
		}
		case "fbx": {
			defer delete(data);
			model := load_model_from_memory(data, name);
			if name in catalog.models {
				logln("New model with name '", name, "'. Deleting old one.");
				delete_model(catalog.models[name]);
			}
			catalog.models[name] = model;
		}
		case "shader": {
			defer delete(data);

			if name in catalog.shaders {
				logln("New shader with name '", name, "'. Deleting old one.");
				// todo(josh): figure out why deleting shaders was causing errors
				// gpu.delete_shader(catalog.shaders[name]);
			}

			shader, ok := parse_shader(catalog, cast(string)data, root_directory);
			if !ok {
				logln("Error: Parse shader failed: ", filepath);
				delete_key(&catalog.shaders, name);
			}
			else {
				catalog.shaders[name] = shader;
			}
		}
		case "compute": {
			defer delete(data);

			if name in catalog.shaders {
				logln("New compute compute shader with name '", name, "'. Deleting old one.");
				// todo(josh): figure out why deleting shaders was causing errors
				// gpu.delete_shader(catalog.shaders[name]);
			}

			shader, ok := gpu.load_shader_compute(cast(string)data);
			if !ok {
				logln("Error: Parse shader failed: ", filepath);
				delete_key(&catalog.shaders, name);
			}
			else {
				catalog.shaders[name] = shader;
			}
		}
		case: {
			if array_contains(catalog.text_file_types, ext) {
				if name in catalog.text_files {
					logln("New text file with name '", name, "'. Deleting old one.");
					delete(catalog.text_files[name]);
				}
				catalog.text_files[name_and_ext] = cast(string)data;
			}
		}
	}
}

Parse_Shader_Result :: enum {
	Yield,
	Done,
	Error,
}

parse_shader :: proc(catalog: ^Asset_Catalog, text: string, root_folder: string) -> (gpu.Shader_Program, bool) {

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

try_get_texture :: proc(catalog: ^Asset_Catalog, name: string) -> (Texture, bool) {
	asset, ok := catalog.textures[name];
	if ok do return asset, true;
	wb_asset, ok2 := wb_catalog.textures[name];
	if ok2 do return wb_asset, true;
	return {}, false;
}
get_texture :: inline proc(catalog: ^Asset_Catalog, name: string) -> Texture {
	texture, ok := try_get_texture(catalog, name);
	assert(ok, tprint("Couldn't find texture: ", name));
	return texture;
}

try_get_model :: proc(catalog: ^Asset_Catalog, name: string) -> (Model, bool) {
	asset, ok := catalog.models[name];
	if ok do return asset, true;
	wb_asset, ok2 := wb_catalog.models[name];
	if ok2 do return wb_asset, true;
	return {}, false;
}
get_model :: inline proc(catalog: ^Asset_Catalog, name: string) -> Model {
	model, ok := try_get_model(catalog, name);
	assert(ok, tprint("Couldn't find model: ", name));
	return model;
}

try_get_font :: proc(catalog: ^Asset_Catalog, name: string) -> (Font, bool) {
	asset, ok := catalog.fonts[name];
	if ok do return asset, true;
	wb_asset, ok2 := wb_catalog.fonts[name];
	if ok2 do return wb_asset, true;
	return {}, false;
}
get_font :: inline proc(catalog: ^Asset_Catalog, name: string) -> Font {
	font, ok := try_get_font(catalog, name);
	assert(ok, tprint("Couldn't find font: ", name));
	return font;
}

try_get_shader :: proc(catalog: ^Asset_Catalog, name: string) -> (gpu.Shader_Program, bool) {
	asset, ok := catalog.shaders[name];
	if ok do return asset, true;
	wb_asset, ok2 := wb_catalog.shaders[name];
	if ok2 do return wb_asset, true;
	return {}, false;
}
get_shader :: inline proc(catalog: ^Asset_Catalog, name: string) -> gpu.Shader_Program {
	shader, ok := try_get_shader(catalog, name);
	if ok {
		return shader;
	}
	// logln("Error: Couldn't find shader ", name);
	return wb_catalog.shaders["error"];
}

