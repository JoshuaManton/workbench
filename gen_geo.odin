package workbench

create_cube_model :: proc(scale : f32 = 1) -> Model {
	indices := []u32 {
		 0,  2,  1,  0,  3,  2,
		 4,  5,  6,  4,  6,  7,
		 8, 10,  9,  8, 11, 10,
		12, 13, 14, 12, 14, 15,
		16, 17, 18, 16, 18, 19,
		20, 22, 21, 20, 23, 22,
	};

    verts := []Vertex3D {
    	{{-(scale * 0.5), -(scale * 0.5), -(scale * 0.5)}, {1, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  0, -1}, {}, {}},
    	{{ (scale * 0.5), -(scale * 0.5), -(scale * 0.5)}, {0, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  0, -1}, {}, {}},
    	{{ (scale * 0.5),  (scale * 0.5), -(scale * 0.5)}, {0, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  0, -1}, {}, {}},
    	{{-(scale * 0.5),  (scale * 0.5), -(scale * 0.5)}, {1, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  0, -1}, {}, {}},

    	{{-(scale * 0.5), -(scale * 0.5),  (scale * 0.5)}, {0, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  0,  1}, {}, {}},
    	{{ (scale * 0.5), -(scale * 0.5),  (scale * 0.5)}, {1, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  0,  1}, {}, {}},
    	{{ (scale * 0.5),  (scale * 0.5),  (scale * 0.5)}, {1, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  0,  1}, {}, {}},
    	{{-(scale * 0.5),  (scale * 0.5),  (scale * 0.5)}, {0, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  0,  1}, {}, {}},

    	{{-(scale * 0.5), -(scale * 0.5), -(scale * 0.5)}, {0, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{-1,  0,  0}, {}, {}},
    	{{-(scale * 0.5),  (scale * 0.5), -(scale * 0.5)}, {0, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{-1,  0,  0}, {}, {}},
    	{{-(scale * 0.5),  (scale * 0.5),  (scale * 0.5)}, {1, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{-1,  0,  0}, {}, {}},
    	{{-(scale * 0.5), -(scale * 0.5),  (scale * 0.5)}, {1, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{-1,  0,  0}, {}, {}},

    	{{ (scale * 0.5), -(scale * 0.5), -(scale * 0.5)}, {1, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{ 1,  0,  0}, {}, {}},
    	{{ (scale * 0.5),  (scale * 0.5), -(scale * 0.5)}, {1, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{ 1,  0,  0}, {}, {}},
    	{{ (scale * 0.5),  (scale * 0.5),  (scale * 0.5)}, {0, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{ 1,  0,  0}, {}, {}},
    	{{ (scale * 0.5), -(scale * 0.5),  (scale * 0.5)}, {0, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{ 1,  0,  0}, {}, {}},

    	{{-(scale * 0.5), -(scale * 0.5), -(scale * 0.5)}, {0, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0, -1,  0}, {}, {}},
    	{{ (scale * 0.5), -(scale * 0.5), -(scale * 0.5)}, {1, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0, -1,  0}, {}, {}},
    	{{ (scale * 0.5), -(scale * 0.5),  (scale * 0.5)}, {1, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0, -1,  0}, {}, {}},
    	{{-(scale * 0.5), -(scale * 0.5),  (scale * 0.5)}, {0, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0, -1,  0}, {}, {}},

    	{{-(scale * 0.5),  (scale * 0.5), -(scale * 0.5)}, {0, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  1,  0}, {}, {}},
    	{{ (scale * 0.5),  (scale * 0.5), -(scale * 0.5)}, {1, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  1,  0}, {}, {}},
    	{{ (scale * 0.5),  (scale * 0.5),  (scale * 0.5)}, {1, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  1,  0}, {}, {}},
    	{{-(scale * 0.5),  (scale * 0.5),  (scale * 0.5)}, {0, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{ 0,  1,  0}, {}, {}},
    };

    model: Model;
    add_mesh_to_model(&model, verts, indices, {});
    return model;
}

create_quad_model :: proc() -> Model {
    verts := []Vertex3D {
        {{-0.5, -0.5, 0}, {0, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{0, 0, 1}, {}, {}},
        {{-0.5,  0.5, 0}, {0, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{0, 0, 1}, {}, {}},
        {{ 0.5,  0.5, 0}, {1, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{0, 0, 1}, {}, {}},
        {{ 0.5, -0.5, 0}, {1, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{0, 0, 1}, {}, {}},
    };

    indices := []u32 {
    	0, 2, 1, 0, 3, 2
    };

    model: Model;
    add_mesh_to_model(&model, verts, indices, {});
    return model;
}