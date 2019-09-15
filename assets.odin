package workbench

      import "core:sys/win32"
      import "core:strings"
      import "core:os"
      import "core:mem"
using import "core:fmt"
using import "logging"
      import "gpu"
using import "basic"

Asset_Catalog :: struct {
	textures:   map[string]gpu.Texture,
	models:     map[string]gpu.Model,
	fonts:      map[string]Font,
	text_files: map[string]string,
}

delete_asset_catalog :: proc(catalog: Asset_Catalog) {
	for key, texture in catalog.textures {
		delete(key);
		gpu.delete_texture(texture.gpu_id);
	}
	for key, model in catalog.models {
		delete(key);
		gpu.delete_model(model);
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
	files := get_all_filepaths_recursively(path);
	defer {
		for f in files do delete(f);
		delete(files);
	}

	for filepath in files {
		name, nameok := get_file_name(filepath);
		assert(nameok);
		ext, ok := get_file_extension(filepath);
		assert(ok, filepath);
		data, fileok := os.read_entire_file(filepath);
		assert(fileok);

		switch ext {
			case "png": {
				texture := create_texture_from_png_data(data);
				assert(name notin catalog.textures);
				catalog.textures[aprint(name)] = texture;
				delete(data);
			}
			case "ttf": {
				font := load_font(data, 32); // todo(josh): multiple sizes for fonts? probably would be good
				assert(name notin catalog.textures);
				catalog.fonts[aprint(name)] = font;
				delete(data);
			}
			case "fbx": {
				model := load_model_from_memory(data);
				assert(name notin catalog.models);
				catalog.models[aprint(name)] = model;
				delete(data);
			}
			case: {
				if array_contains(text_file_types, ext) {
					name_and_ext, ok := get_file_name_and_extension(filepath);
					assert(name_and_ext notin catalog.text_files);
					catalog.text_files[aprint(name_and_ext)] = cast(string)data;
				}
				else {
					logln("Unknown file extension: .", ext, " at ", filepath);
				}
			}
		}
	}
}