@vert
#version 330 core

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec3 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec3 vbo_normal;

uniform vec4 mesh_color;
uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

out vec3 frag_position;
out vec3 tex_coord;
out vec4 vert_color;
out vec3 vert_normal;
out vec3 vertex_pos;

void main() {
    gl_Position = vec4(vbo_vertex_position, 1);
    tex_coord = vbo_tex_coord;
    vert_normal = mat3(transpose(inverse(model_matrix))) * vbo_normal;
    frag_position = vec3(model_matrix * vec4(vbo_vertex_position, 1.0));
    vert_color = vbo_color * mesh_color;
    vertex_pos = vbo_vertex_position;
}

@geom
#version 330 core

layout (points) in;
layout (triangle_strip, max_vertices = 30) out;

in vec3 vertex_pos[];

out vec3 vert_normal;
out vec4 vert_color;
out vec3 frag_position;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

uniform sampler3D dataFieldTex; 
uniform isampler2D edgeTableTex; 
uniform isampler2D triTableTex; 

uniform int has_dataFieldTex;
uniform int has_edgeTableTex;
uniform int has_triTableTex;

uniform float isolevel; 
uniform vec3 vertDecals[8];

// vec4 cubePos(int i){ 
//     return gl_in[0].gl_Position + vec4(vertDecals[i], 1); 
// } 

// float cubeVal(int i){ 
//     vec3 tpos = vertex_pos[0]+vertDecals[i];
//     return texelFetch(dataFieldTex, ivec3(int(tpos.x), int(tpos.y), int(tpos.z)), 0).r; 
// } 

// int triTableValue(int i, int j){ 
//     return texelFetch(triTableTex, ivec2(j, i), 0).r; 
// } 

// int edgeTableValue(int i){
//     return texelFetch(edgeTableTex, ivec2(i, 0), 0).a;
// }

// vec4 vertexInterp(float isolevel, vec4 v0, float l0, vec4 v1, float l1){

//     if (abs(isolevel-l0) < 0.00001)
//         return(v0);
//     if (abs(isolevel-l1) < 0.00001)
//         return(v1);
//     if (abs(l0-l1) < 0.00001)
//         return(v0);

//     return mix(v0, v1, (isolevel-l0)/(l1-l0));
// }

float cubeVal(int i) {
    vec4 corner = gl_in[0].gl_Position + vec4(vertDecals[i], 0);
    return texelFetch(dataFieldTex, ivec3(int(corner.x), int(corner.y), int(corner.z)), 0).r;
}

vec4 cubePos(int i){ 
    return gl_in[0].gl_Position + vec4(vertDecals[i], 1); 
} 

int edgeVal(int i) {
    return texelFetch(edgeTableTex, ivec2(i, 0), 0).r;
}

int triTableValue(int i, int j){ 
    return texelFetch(triTableTex, ivec2(j, i), 0).r; 
}

vec4 vertexInterp(float iso, vec4 p1, float v1, vec4 p2, float v2) {
    if ((p2.x != p1.x && p2.x < p1.x) || 
        (p2.y != p1.y && p2.y < p1.y) || 
        (p2.z != p1.z && p2.z < p1.z))
    {
        vec4 temp = p1;
        p2 = p1;
        p1 = temp;
    }

    if (abs(v1 - v2) > 0.00001) 
        return p1 + (p2 - p1)/(v2 - v1)*(iso - v1);
    else return p1;
}

void main() {

    int cube_index = 0;
    if (cubeVal(0) < isolevel) cube_index |= 1;
    if (cubeVal(1) < isolevel) cube_index |= 2;
    if (cubeVal(2) < isolevel) cube_index |= 4;
    if (cubeVal(3) < isolevel) cube_index |= 8;
    if (cubeVal(4) < isolevel) cube_index |= 16;
    if (cubeVal(5) < isolevel) cube_index |= 32;
    if (cubeVal(6) < isolevel) cube_index |= 64;
    if (cubeVal(7) < isolevel) cube_index |= 128;

    if (cube_index == 0 || cube_index == 255)
        return;

    int edge_val = edgeVal(cube_index);
    if (edge_val == 0) return;

    vec4 vert_list[12];
    if ((edge_val & 1) != 0) 
        vert_list[0] = vertexInterp(isolevel, cubePos(0), cubeVal(0), cubePos(1), cubeVal(1));
    if ((edge_val & 2) != 0) 
        vert_list[1] = vertexInterp(isolevel, cubePos(1), cubeVal(1), cubePos(2), cubeVal(2));
    if ((edge_val & 4) != 0) 
        vert_list[2] = vertexInterp(isolevel, cubePos(2), cubeVal(2), cubePos(3), cubeVal(3));
    if ((edge_val & 8) != 0) 
        vert_list[3] = vertexInterp(isolevel, cubePos(3), cubeVal(3), cubePos(0), cubeVal(0));
    if ((edge_val & 16) != 0) 
        vert_list[4] = vertexInterp(isolevel, cubePos(4), cubeVal(4), cubePos(5), cubeVal(5));
    if ((edge_val & 32) != 0) 
        vert_list[5] = vertexInterp(isolevel, cubePos(5), cubeVal(5), cubePos(6), cubeVal(6));
    if ((edge_val & 64) != 0) 
        vert_list[6] = vertexInterp(isolevel, cubePos(6), cubeVal(6), cubePos(7), cubeVal(7));
    if ((edge_val & 128) != 0) 
        vert_list[7] = vertexInterp(isolevel, cubePos(7), cubeVal(7), cubePos(4), cubeVal(4));
    if ((edge_val & 256) != 0) 
        vert_list[8] = vertexInterp(isolevel, cubePos(0), cubeVal(0), cubePos(4), cubeVal(4));
    if ((edge_val & 512) != 0) 
        vert_list[9] = vertexInterp(isolevel, cubePos(1), cubeVal(1), cubePos(5), cubeVal(5));
    if ((edge_val & 1024) != 0) 
        vert_list[10] = vertexInterp(isolevel, cubePos(2), cubeVal(2), cubePos(6), cubeVal(6));
    if ((edge_val & 2048) != 0) 
        vert_list[11] = vertexInterp(isolevel, cubePos(3), cubeVal(3), cubePos(7), cubeVal(7));

    for (int i=0;triTableValue(cube_index, i) != -1; i += 3){
        gl_Position = projection_matrix * view_matrix * model_matrix * vert_list[triTableValue(cube_index, i+0)];
        // frag_position = vec3(triTableValue(cube_index, i+0), cube_index, i);//(model_matrix * vert_list[triTableValue(cube_index, i+0)]).xyz;
        EmitVertex();
        gl_Position = projection_matrix * view_matrix * model_matrix * vert_list[triTableValue(cube_index, i+1)];
        // frag_position = vec3(triTableValue(cube_index, i+1), cube_index, i);//(model_matrix * vert_list[triTableValue(cube_index, i+1)]).xyz;
        EmitVertex();
        gl_Position = projection_matrix * view_matrix * model_matrix * vert_list[triTableValue(cube_index, i+2)];
        // frag_position = vec3(triTableValue(cube_index, i+2), cube_index, i);//(model_matrix * vert_list[triTableValue(cube_index, i+2)]).xyz;
        EmitVertex();
        EndPrimitive();

        gl_Position = projection_matrix * view_matrix * model_matrix * vert_list[triTableValue(cube_index, i+0)];
        // frag_position = (model_matrix * vert_list[triTableValue(cube_index, i+0)]).xyz;
        EmitVertex();
        gl_Position = projection_matrix * view_matrix * model_matrix * vert_list[triTableValue(cube_index, i+2)];
        // frag_position = (model_matrix * vert_list[triTableValue(cube_index, i+2)]).xyz;
        EmitVertex();
        gl_Position = projection_matrix * view_matrix * model_matrix * vert_list[triTableValue(cube_index, i+1)];
        // frag_position = (model_matrix * vert_list[triTableValue(cube_index, i+1)]).xyz;
        EmitVertex();
        EndPrimitive();
    }

    // vert_normal = vec3(0,-1,0);
    // vert_color = vec4(1,0,0,1);

    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(0);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(4);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(1);
    // EmitVertex();
    // EndPrimitive();

    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(5);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(1);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(4);
    // EmitVertex();
    // EndPrimitive();

    // vert_color = vec4(0,1,0,1);
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(3);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(7);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(2);
    // EmitVertex();
    // EndPrimitive();

    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(6);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(2);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(7);
    // EmitVertex();
    // EndPrimitive();

    // vert_color = vec4(0,0,1,1);
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(0);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(4);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(3);
    // EmitVertex();
    // EndPrimitive();

    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(7);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(3);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(4);
    // EmitVertex();
    // EndPrimitive();

    // vert_color = vec4(0,1,1,1);
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(4);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(5);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(7);
    // EmitVertex();
    // EndPrimitive();

    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(5);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(6);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(7);
    // EmitVertex();
    // EndPrimitive();

    // vert_color = vec4(1,0,1,1);
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(2);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(0);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(3);
    // EmitVertex();
    // EndPrimitive();

    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(1);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(0);
    // EmitVertex();
    // gl_Position = projection_matrix * view_matrix * model_matrix * cubePos(2);
    // EmitVertex();
    // EndPrimitive();
}


@frag
@include "lit_frag.glsl"