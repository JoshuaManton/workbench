package workbench

using import "math"
using import "types"
using import "logging"
using import "basic"
using import "gpu"
import odingl "external/gl"
import sort "core:sort"

import "core:math/rand"

Particle_Emitter :: struct {
    position: Vec3,
    rotation: Quat,
    
    emit: bool,
    emission_rate: int,
    max_particles: int,
    
    min_ttl: f32,
    max_ttl: f32,
    
    initial_colour: Colorf,
    final_colour: Colorf,
    
    initial_scale: Vec3,
    final_scale: Vec3,
    
    texture_id : string,
    emission: Emission_Data,
    
    // runtime
    texture : Texture "wbml_noserialize",
    shader: gpu.Shader_Program "wbml_noserialize",
    active_particles: int "wbml_noserialize",
    
    particles: [dynamic]Particle "wbml_noserialize",
    offsets: [dynamic]Mat4 "wbml_noserialize",
    colours: [dynamic]Colorf "wbml_noserialize",
    
    rstate: rand.Rand "wbml_noserialize",
    last_emission: f32 "wbml_noserialize",
}

Spheric_Emission :: struct {
    direction: Vec3,
    angle_min, angle_max: f32,
}

Linear_Emission :: struct {}

Emission_Data :: union {
    Spheric_Emission,
    Linear_Emission,
}

Particle :: struct {
    position: Vec3,
    rotation: Quat,
    scale: Vec3,
    
    velocity: Vec3,
    
    initial_ttl: f32,
    current_ttl: f32,
    
    colour: Colorf,
    
    dead: bool,
}

Particle_Vertex :: struct {
    position: Vec4,
    uv: Vec2,
}

particles_vbo : gpu.VBO;
particles_vao : gpu.VAO;
offsets_vbo : gpu.VBO;
colours_vbo : gpu.VBO;

init_particles :: proc() {
    
    ident := identity(Mat4);
    quad_verts := []Particle_Vertex {
    	{{-0.5, -0.5, 0.0, 0.0}, {0, 0}}, // bottom left
        {{ 0.5, -0.5, 0.0, 0.0}, {1, 0}}, // bottom right
    	{{-0.5,  0.5, 0.0, 0.0}, {0, 1}}, // top left
    	
    	{{ 0.5, -0.5, 0.0, 0.0}, {1, 0}}, // bottom right
        {{ 0.5,  0.5, 0.0, 0.0}, {1, 1}}, // top right
    	{{-0.5,  0.5, 0.0, 0.0}, {0, 1}}, // top left
    };
    
    // generate vao and 2 vbos, 1 for vertices, othe other for instanced particle offsets
    particles_vbo = gpu.gen_vbo();
    particles_vao = gpu.gen_vao();
    offsets_vbo = gpu.gen_vbo();
    colours_vbo = gpu.gen_vbo();
    
    // buffer the quad
    gpu.bind_vbo(particles_vbo);
    gpu.bind_vao(particles_vao);
    set_vertex_format_ti(type_info_of(Particle_Vertex));
    gpu.buffer_vertices(quad_verts);
    
    // vbo for instance colours
    gpu.bind_vbo(colours_vbo);
    odingl.EnableVertexAttribArray(2);
    odingl.VertexAttribPointer(2, 4, odingl.FLOAT, odingl.FALSE, size_of(Vec4), rawptr(uintptr(0)));
    odingl.VertexAttribDivisor(2, 1);
    
    // enable a mat4, and set it to step every instance
    gpu.bind_vbo(offsets_vbo);
    odingl.EnableVertexAttribArray(3);
    odingl.VertexAttribPointer(    3, 4, odingl.FLOAT, odingl.FALSE, size_of(Vec4) * 4, rawptr(uintptr(0)));
    odingl.VertexAttribDivisor(    3, 1);
    odingl.EnableVertexAttribArray(4);
    odingl.VertexAttribPointer(    4, 4, odingl.FLOAT, odingl.FALSE, size_of(Vec4) * 4, rawptr(uintptr(16)));
    odingl.VertexAttribDivisor(    4, 1);
    odingl.EnableVertexAttribArray(5);
    odingl.VertexAttribPointer(    5, 4, odingl.FLOAT, odingl.FALSE, size_of(Vec4) * 4, rawptr(uintptr(32)));
    odingl.VertexAttribDivisor(    5, 1);
    odingl.EnableVertexAttribArray(6);
    odingl.VertexAttribPointer(    6, 4, odingl.FLOAT, odingl.FALSE, size_of(Vec4) * 4, rawptr(uintptr(48)));
    odingl.VertexAttribDivisor(    6, 1);
    
    gpu.bind_vao(0);
}

init_particle_emitter :: proc(using emitter: ^Particle_Emitter, seed: u64) {
    rand.init(&rstate, seed);
    
    max_particles = 100;
    
    particles = make([dynamic]Particle, 0, max_particles);
    offsets = make([dynamic]Mat4, max_particles, max_particles);
    colours = make([dynamic]Colorf, max_particles, max_particles);
    rotation = Quat{0,0,0,1};
    initial_scale = Vec3{1,1,1};
    final_scale = Vec3{1,1,1};
}

update_particle_emitter :: proc(using emitter: ^Particle_Emitter, delta_time: f32) {
    if !emit do return;
    
    last_emission += delta_time;
    emissions_per_second := f32(1) / f32(emission_rate);
    if last_emission >= emissions_per_second {
        last_emission = 0;
        ttl := lerp(min_ttl, max_ttl, rand.float32(&rstate));
        
        velocity := Vec3{0,0,0};
        switch d in emission {
            case Spheric_Emission: {
                a := lerp(d.angle_min, d.angle_max, rand.float32(&rstate));
                theta := acos(a);
                phi := lerp(f32(0), f32(TAU), rand.float32(&rstate));
                
                sin_theta := sin(theta);
                x := sin_theta * f32(cos(phi));
                y := sin_theta * f32(sin(phi));
                z := f32(cos(theta));
                
                velocity = Vec3{x,y,z} * 0.01;
            }
            case Linear_Emission: {
                velocity = quaternion_forward(rotation) * 0.01;
            }
        }
        
        p := Particle{
            Vec3{},
            rotation,
            Vec3{1,1,1},
            velocity,
            ttl,
            ttl,
            initial_colour,
            false,
        };
        
        if active_particles < len(particles) {
            for j := 0; j < len(particles); j += 1 {
                op := particles[j];
                if op.dead {
                    particles[j] = p;
                    break;
                }
            }
        } else {
            append(&particles, p);
        }
        active_particles += 1;
    }
    
    j := 0;
    for _, i in particles {
        p := particles[i];
        
        if p.dead do continue;
        
        p.current_ttl -= delta_time;
        complete_percent :=  1 - p.current_ttl / p.initial_ttl;
        
        if p.current_ttl <= 0 && !p.dead {
            p.dead = true;
            active_particles -= 1;
        }
        if !p.dead {
            
            p.position += p.velocity;
            p.scale = lerp(initial_scale, final_scale, complete_percent);
            
            t := translate(identity(Mat4), position + p.position);
            s := mat4_scale(identity(Mat4), p.scale);
            o := mul(t, s);
            
            if j >= len(offsets) do append(&offsets, o);
            else do offsets[j] = o;
            
            p.colour = color_lerp(initial_colour, final_colour, complete_percent);
            
            if j >= len(colours) do append(&colours, p.colour);
            else do colours[j] = p.colour;
            
            j += 1;
        }
        
        particles[i] = p;
    }
}

render_particle_emitter :: proc(using emitter: ^Particle_Emitter, projection, view: Mat4) {
    if !emit do return;
    
    _view := view;
    _proj := projection;
    
    gpu.use_program(shader);
    gpu.uniform_mat4(shader, "view_matrix",       &_view);
	gpu.uniform_mat4(shader, "projection_matrix", &_proj);
    
    gpu.enable(.Blend);
    odingl.BlendFunc(odingl.SRC_ALPHA, odingl.ONE_MINUS_SRC_ALPHA);
    
    gpu.active_texture0();
    gpu.bind_texture_2d(texture.gpu_id);
    
    gpu.enable(.Depth_Test);
    gpu.bind_vao(particles_vao);
    
    gpu.bind_vbo(offsets_vbo);
    gpu.buffer_vertices(offsets[:]); // not actually vertices
    
    gpu.bind_vbo(colours_vbo);
    gpu.buffer_vertices(colours[:]);
    
    draw_arrays_instanced(.Triangles, 0, 6, active_particles);
    gpu.disable(.Blend);
    
    gpu.bind_vao(0);
}