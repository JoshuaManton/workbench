package workbench

      import "core:sys/win32"
      import "core:strings"
      import "core:os"
using import "core:fmt"
using import "logging"
      import "gpu"
using import "basic"

Asset_Catalog :: struct {
	textures:   map[string]gpu.Texture,
	models:     map[string]gpu.Model,
	fonts:      map[string]Font,
	text_files: map[string]string,

	filepaths: [dynamic]string,
}

delete_asset_catalog :: proc(catalog: Asset_Catalog) {
	for _, texture in catalog.textures {
		gpu.delete_texture(texture);
	}
	for _, model in catalog.models {
		gpu.delete_model(model);
	}
	for _, font in catalog.fonts {
		delete_font(font);
	}
	for _, text in catalog.text_files {
		delete(text);
	}
	for filepath in catalog.filepaths {
		delete(filepath);
	}

	delete(catalog.textures);
	delete(catalog.models);
	delete(catalog.fonts);
	delete(catalog.text_files);
	delete(catalog.filepaths);
}

load_asset_folder :: proc(path: string, catalog: ^Asset_Catalog, text_file_types: ..string) {
	files := get_all_filepaths_recursively(path);
	defer delete(files);

	for filepath in files {
		append(&catalog.filepaths, filepath);

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
				catalog.textures[name] = texture;
				delete(data);
			}
			case "ttf": {
				font := load_font(data, 32); // todo(josh): multiple sizes for fonts? probably would be good
				assert(name notin catalog.textures);
				catalog.fonts[name] = font;
				delete(data);
			}
			case "fbx": {
				model := load_model_from_memory(data);
				assert(name notin catalog.models);
				catalog.models[name] = model;
				delete(data);
			}
			case: {
				if array_contains(text_file_types, ext) {
					name_and_ext, ok := get_file_name_and_extension(filepath);
					println(filepath);
					println(name_and_ext);
					assert(name_and_ext notin catalog.text_files);
					catalog.text_files[name_and_ext] = cast(string)data;
				}
				else {
					logln("Unknown file extension: .", ext, " at ", filepath);
				}
			}
		}
	}
}