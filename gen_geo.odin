package workbench

import "math"

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

create_sphere_model :: proc(stacks: int = 24, sectors: int = 48) -> Model {
    verts := make([]Vertex3D, (stacks+1) * (sectors+1));
    inds := make([]u32, (stacks+1) * (sectors+1) * 6);
    defer delete(verts);
    defer delete(inds);

    // for i in 0..stacks {
    //     for j in 0..sectors {
    //         y := math.sin(math.PI/2 + math.PI * i);
    //         x := math.cos(math.TAU * j) * math.sin(math.PI * i);
    //         z := math.sin(math.TAU * j) * math.sin(math.PI * i);
    //     }
    // }

    sector_step := math.TAU / f32(sectors);
    stack_step := math.PI / f32(stacks);

    vert_i := 0;
    for i in 0..stacks {
        stack_angle := math.PI/2 - f32(i) * f32(stack_step);
        xy := math.cos(stack_angle);
        z := math.sin(stack_angle);

        for j in 0..sectors {
            sector_angle := f32(j) * sector_step;
            x := xy * cos(sector_angle);
            y := xy * sin(sector_angle);

            s := f32(i) / f32(sectors);
            t := f32(i) / f32(stacks);

            verts[vert_i] = { {x,y,z}, {s,t,0}, {1,1,1,1}, {x,y,z}, {}, {} }; 

            vert_i+=1;
        }
    }

    inds_i := 0;
    for i in 0..<stacks {
        k1 := i * (sectors+1);
        k2 := k1 + (sectors+1);
        for j in 0..<sectors {
            if (i != 0) {
                inds[inds_i] = u32(k1); inds_i += 1;
                inds[inds_i] = u32(k2); inds_i += 1;
                inds[inds_i] = u32(k1+1); inds_i += 1;
            }
            if (i != stacks-1) {
                inds[inds_i] = u32(k1+1); inds_i += 1;
                inds[inds_i] = u32(k2); inds_i += 1;
                inds[inds_i] = u32(k2+1); inds_i += 1;
            }

            k1+=1;
            k2+=1;
        }
    }

    model: Model;
    add_mesh_to_model(&model, verts[:], inds[:], {});
    return model;
}