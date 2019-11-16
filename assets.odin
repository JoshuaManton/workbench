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
	for key, texture in catalog.textures {
		delete(key);
		delete_texture(texture);
	}
	for key, model in catalog.models {
		delete(key);
		delete_model(model);
	}
	for key, font in catalog.fonts {
		delete(key);
		delete_font(font);
	}
	for key, text in catalog.text_files {
		delete(key);
		delete(text);
	}

	delete(catalog.textures);
	delete(catalog.models);
	delete(catalog.fonts);
	delete(catalog.text_files);
}

load_asset_folder :: proc(path: string, catalog: ^Asset_Catalog, text_file_types: ..string, loc := #caller_location) {
	// todo(josh): determine lifetimes of text_file_types and its contents

	files := get_all_filepaths_recursively(path);
	defer delete(files); // note(josh): dont delete the elements in `files` because they get stored in Asset_Catalog.loaded_files

	assert(catalog.text_file_types == nil);
	catalog.text_file_types = text_file_types;

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
			texture := create_texture_from_png_data(data);
			if name in catalog.textures do delete_texture(catalog.textures[name]);
			catalog.textures[name] = texture;
			delete(data);
		}
		case "ttf": {
			font := load_font(data, 32); // todo(josh): multiple sizes for fonts? probably would be good
			if name in catalog.textures do delete_texture(catalog.textures[name]);
			catalog.fonts[name] = font;
			delete(data);
		}
		case "fbx": {
			model := load_model_from_memory(data);
			if name in catalog.models do delete_model(catalog.models[name]);
			catalog.models[name] = model;
			delete(data);
		}
		case "shader": {
			logln("loading shader: ", name);
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

			if name in catalog.shaders do gpu.delete_shader(catalog.shaders[name]);
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

load_wb_shaders :: proc(catalog: ^Asset_Catalog) {
	assert(WORKBENCH_PATH != "");
	load_asset_folder(tprint(WORKBENCH_PATH, "/shaders"), catalog);
}