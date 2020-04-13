# workbench

workbench is a collection of libraries for games handling things like rendering, serialization, collision, and more.

### Renderer

* Forward PBR renderer
* Cascaded shadow maps
* Skeletal animation
* HDR
* Bloom
* Gamma correction

![Renderer](https://i.imgur.com/BAEvzkQ.png)

// todo: more pictures and gifs

### Entity System and Editor

![Editor](https://i.imgur.com/tSwY37S.png)

```odin
My_Entity :: struct {
  using base: Entity, // Entity has common fields like position, scale, rotation, render info, etc
  health: int,
  speed: f32,
  target_position: Vec3,
}

add_entity_type(My_Entity);
add_init_proc(init_my_entity);
add_update_proc(update_my_entity);

init_my_entity :: proc(entity: ^My_Entity) {
    entity.health = 10;
    entity.speed = 15;
    entity.render_info.model_id = "my_cool_model";
    entity.render_info.shader_id = "lit";
    entity.render_info.texture_id = "some_texture";
    entity.render_info.color = Colorf{1, 0.2, 0.1, 1};
}

update_my_entity :: proc(entity: ^My_Entity, dt: f32) {
    entity.position = lerp(entity.position, entity.target_position, entity.speed * dt);
    if entity.health <= 0 {
        destroy_entity(&scene, entity);
    }
}
```

### Serialization

// todo

### Collision

// todo

### Asset Loading

// todo

### UI Layouting

// todo

### Custom Allocators

// todo
