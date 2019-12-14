package particles

using import "../math"
using import "../types"
using import "../logging"
using import "../basic"
using import "../gpu"
import odingl "../external/gl"

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
    
    active_particles: int,
    particles: [dynamic]Particle,
    
    offsets: [dynamic]Mat4,
    rstate: rand.Rand,
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
    position: Vec3,
    colour: Colorf,
}

particles_vao : gpu.VAO;
offsets_vbo : gpu.VBO;

init :: proc() {
    
    ident := identity(Mat4);
    quad_verts := []Particle_Vertex {
    	{{-0.5,  0.5, 0.0}, Colorf{1, 1, 1, 1}},
    	{{ 0.5, -0.5, 0.0}, Colorf{1, 1, 1, 1}},
    	{{-0.5, -0.5, 0.0}, Colorf{1, 1, 1, 1}},
        
    	{{-0.5,  0.5, 0.0}, Colorf{1, 1, 1, 1}},
    	{{ 0.5,  0.5, 0.0}, Colorf{1, 1, 1, 1}},
    	{{ 0.5,  0.5, 0.0}, Colorf{1, 1, 1, 1}},
    };
    
    particles_vao = gpu.gen_vao();
    offsets_vbo = gpu.gen_vbo();
    
    gpu.bind_vao(particles_vao);
    gpu.bind_vbo(offsets_vbo);
    
    gpu.buffer_vertices(quad_verts);
    
    gpu.bind_vbo(0);
    gpu.bind_vao(0);
}

init_particle_emitter :: proc(using emitter: ^Particle_Emitter, seed: u64) {
    rand.init(&rstate, seed);
    
    max_particles = 100;
    
    particles = make([dynamic]Particle, 0, max_particles);
    offsets = make([dynamic]Mat4, max_particles, max_particles);
    rotation = Quat{0,0,0,1};
}

update_particle_emitter :: proc(using emitter: ^Particle_Emitter, delta_time: f32) {
    if !emit do return;
    
    amount_to_spawn := minv(max_particles - active_particles, emission_rate);
    for i := 0; i < amount_to_spawn; i += 1 {
        
        ttl := lerp(min_ttl, max_ttl, rand.float32(&rstate));
        
        p := Particle{
            position,
            rotation,
            Vec3{1,1,1},
            
            quaternion_forward(rotation),
            
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
    
    for i := len(particles)-1; i > 0; i -= 1 {
        p := particles[i];
        
        p.current_ttl -= delta_time;
        p.position += p.velocity;
        offsets[i] = translate(identity(Mat4), p.position);
        
        if p.current_ttl <= 0 && !p.dead {
            p.dead = true;
            active_particles -= 1;
        }
        
        particles[i] = p;
    }
}

render_particle_emitter :: proc(using emitter: ^Particle_Emitter) {
    
    gpu.bind_vbo(offsets_vbo);
    gpu.buffer_vertices(offsets[:]); // not actually vertices
    
    gpu.bind_vao(particles_vao);

    set_vertex_format_ti(type_info_of(Particle_Vertex));
    
    odingl.EnableVertexAttribArray(2);
    odingl.VertexAttribPointer(2, 4, odingl.FLOAT, odingl.FALSE, size_of(Mat4), rawptr(uintptr(0)));
    odingl.EnableVertexAttribArray(3);
    odingl.VertexAttribPointer(3, 4, odingl.FLOAT, odingl.FALSE, size_of(Mat4), rawptr(uintptr(size_of(Vec4))));
    odingl.EnableVertexAttribArray(4);
    odingl.VertexAttribPointer(4, 4, odingl.FLOAT, odingl.FALSE, size_of(Mat4), rawptr(uintptr(size_of(Vec4) * 2)));
    odingl.EnableVertexAttribArray(5);
    odingl.VertexAttribPointer(5, 4, odingl.FLOAT, odingl.FALSE, size_of(Mat4), rawptr(uintptr(size_of(Vec4) * 3)));
    
    odingl.VertexAttribDivisor(2, 1);
    odingl.VertexAttribDivisor(3, 1);
    odingl.VertexAttribDivisor(4, 1);
    odingl.VertexAttribDivisor(5, 1);
    
    draw_arrays_instanced(.Triangles, 0, 6, active_particles);
}