package workbench

import "core:fmt"

import "gpu"
import log "logging"
import "math"
import "types"

Terrain :: struct {
    model: gpu.Model,

    color0: Colorf,
    color1: Colorf,

    height_map: [][]f32
}

Terrain_Vertex :: struct {
    position: Vec3,
    colour: Colorf,
}

create_terrain :: proc(size: int, height_map: [][]f32) -> Terrain {

    assert(size <= len(height_map), "Height map too smalle for terrain");

    terrain := Terrain {
        gpu.Model {
            "terrain",
            make([dynamic]Mesh, 0, 1),
        },
        {36.0/255.0, 191.0/255.0, 70.0/255.0, 1},
        {150.0/255.0, 130.0/255.0, 65.0/255.0, 1},
        height_map,
    };

    verts := make([dynamic]Terrain_Vertex, 0, size);
    for x in 0..size {
        for z in 0..size {

            height := height_map[x][z];
            colour := Colorf{1,1,1,1};
            if ((size * x) + z) % 2 == 0 {
                colour = terrain.color0;
            } else {
                colour = terrain.color1;
            }

            append(&verts, Terrain_Vertex {
                Vec3 {
                    f32(z) / f32(size - 1) * f32(size),
                    height,
                    f32(x) / f32(size - 1) * f32(size),
                },
                colour,
            });
        }
    }

    inds := make([dynamic]u32, 0, size);
    for x in 0..size-1 {
        for z in 0..size-1 {
            bottom_left := (size * x) + z;
            bottom_right := bottom_left + size;
            top_left := bottom_left + 1;
            top_right := bottom_right + 1;

            append(&inds, u32(bottom_left));
            append(&inds, u32(bottom_right));
            append(&inds, u32(top_right));
            append(&inds, u32(bottom_left));
            append(&inds, u32(top_right));
            append(&inds, u32(top_left));
        }
    }

    add_mesh_to_model(&terrain.model, verts[:], inds[:], {});

    return terrain;
}