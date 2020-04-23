@vert
#version 330 core
layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec4 vbo_color;

uniform mat4 model_matrix;

out vec4 v_color;

void main() {
    gl_Position = vec4(vbo_vertex_position, 1);
    v_color = vbo_color;
}

@geom
#version 330 core
layout (triangles) in;
layout (triangle_strip, max_vertices = 3) out;

in vec4 v_color[];

out vec3 vert_normal;
out vec4 vert_color;
out vec3 frag_position;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

// vec3 calculateLighting(vec3 normal){
// 	float brightness = max(dot(-sun_direction, normal), 0.0);
// 	return (vec3(sun_color.xyz) + (brightness * vec3(sun_color.xyz))) * sun_intensity;
// }

vec3 calcTriangleNormal(){
	vec3 tangent1 = gl_in[1].gl_Position.xyz - gl_in[0].gl_Position.xyz;
	vec3 tangent2 = gl_in[2].gl_Position.xyz - gl_in[0].gl_Position.xyz;
	vec3 normal = cross(tangent1, tangent2);
	return normalize(normal);
}

void main() {
    vec3 normal = calcTriangleNormal();
	// vec3 lighting = calculateLighting(normal);

    for (int i=0; i<3; i++) {
        gl_Position = projection_matrix * view_matrix * model_matrix * gl_in[i].gl_Position;
        vert_color = v_color[0];// * vec4(lighting.xyz, 1);
        vert_normal = normal;
        frag_position = vec3(model_matrix * gl_in[i].gl_Position);
        EmitVertex();
    }
    EndPrimitive();
}


@frag
@include "lit_frag.glsl"