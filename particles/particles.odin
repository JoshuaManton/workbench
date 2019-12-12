package particles

using import "../math"
using import "../types"
using import "../logging"
using import "../basic"
using import "../gpu"

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
    
    offset: Mat4 "per_instance",
}

particles_vao : gpu.VAO;
offsets_vbo : gpu.VBO;

init :: proc() {
    
    ident := identity(Mat4);
    quad_verts := []Particle_Vertex {
    	{{-0.5,  0.5, 0.0}, Colorf{1, 1, 1, 1}, ident},
    	{{ 0.5, -0.5, 0.0}, Colorf{1, 1, 1, 1}, ident},
    	{{-0.5, -0.5, 0.0}, Colorf{1, 1, 1, 1}, ident},
        
    	{{-0.5,  0.5, 0.0}, Colorf{1, 1, 1, 1}, ident},
    	{{ 0.5,  0.5, 0.0}, Colorf{1, 1, 1, 1}, ident},
    	{{ 0.5,  0.5, 0.0}, Colorf{1, 1, 1, 1}, ident},
    };
    
    particles_vao = gpu.gen_vao();
    gpu.bind_vao(particles_vao);
    gpu.buffer_vertices(quad_verts);
    gpu.bind_vao(0);
    
    offsets_vbo = gpu.gen_vbo();
}

init_particle_emitter :: proc(using emitter: ^Particle_Emitter, seed: u64) {
    rand.init(&rstate, seed);
    
    max_particles = 100;
    
    particles = make([dynamic]Particle, 0, max_particles);
    offsets = make([dynamic]Mat4, max_particles, max_particles);
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
        
        if p.current_ttl <= 0 {
            p.dead = true;
            active_particles -= 1;
        }
        
        particles[i] = p;
    }
}

render_particle_emitter :: proc(using emitter: ^Particle_Emitter) {
    gpu.bind_vbo(offsets_vbo);
    gpu.buffer_vertices(offsets[:]); // not actually vertices
    gpu.bind_vbo(0);
    
    gpu.bind_vao(particles_vao);
    draw_arrays_instanced(.Triangles, 0, 6, active_particles);
}