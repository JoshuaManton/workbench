package workbench

      import "core:sys/win32"
      import "core:strings"
      import "core:os"
      import "core:mem"
using import "core:fmt"
using import "logging"
      import "gpu"
      import "profiler"
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
	assert(nameok);
	ext, ok := get_file_extension(filepath);
	assert(ok, filepath);
	data, fileok := os.read_entire_file(filepath);
	assert(fileok);

	switch ext {
		case "png": {
			defer delete(data);
			texture := create_texture_from_png_data(data);
			if name in catalog.textures do delete_texture(catalog.textures[name]);
			catalog.textures[name] = texture;
		}
		case "ttf": {
			defer delete(data);
			font := load_font(data, 32); // todo(josh): multiple sizes for fonts? probably would be good
			if name in catalog.textures do delete_texture(catalog.textures[name]);
			catalog.fonts[name] = font;
		}
		case "fbx": {
			defer delete(data);
			model := load_model_from_memory(data, name);
			if name in catalog.models do delete_model(catalog.models[name]);
			catalog.models[name] = model;
		}
		case "shader": {
			defer delete(data);
			lines := strings.split(cast(string)data, "\n");

			vertex_builder: strings.Builder;
			fragment_builder: strings.Builder;
			defer strings.destroy_builder(&vertex_builder);
			defer strings.destroy_builder(&fragment_builder);

			current_builder: ^strings.Builder;
			for l in lines {
				if string_starts_with(l, "@vert") {
					current_builder = &vertex_builder;
				}
				else if string_starts_with(l, "@frag") {
					current_builder = &fragment_builder;
				}
				else {
					assert(current_builder != nil);
					sbprint(current_builder, l, "\n");
				}
			}

			assert(strings.to_string(vertex_builder) != "");
			assert(strings.to_string(fragment_builder) != "");

			// todo(josh): figure out why deleting shaders was causing errors
			// if name in catalog.shaders do gpu.delete_shader(catalog.shaders[name]);
			shader, ok := gpu.load_shader_text(strings.to_string(vertex_builder), strings.to_string(fragment_builder));
			assert(ok);
			catalog.shaders[name] = shader;
		}
		case: {
			if array_contains(catalog.text_file_types, ext) {
				name_and_ext, ok := get_file_name_and_extension(filepath);
				assert(ok);
				if name in catalog.text_files do delete(catalog.text_files[name]);
				catalog.text_files[name_and_ext] = cast(string)data;
			}
			else {
				logln("Unknown file extension: .", ext, " at ", filepath);
			}
		}
	}
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
	assert(ok, tprint("Couldn't find shader: ", name));
	return shader;
}

