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

uniform float step;
uniform float isolevel; 
uniform vec3 vertDecals[8];

float cubeVal(int i) {
    vec4 corner = gl_in[0].gl_Position + vec4(vertDecals[i], 0);
    // The data texture is streamed in y > z > x
    return texelFetch(dataFieldTex, ivec3(int(corner.y), int(corner.z), int(corner.x)), 0).r;
}

float lerp(float iso, float p1, float p2, float v1, float v2) {
    if (abs(v1 - v2) > 0.00001) 
        return p1 + (p2 - p1)/(v2 - v1)*(iso - v1);
    else return p1;
}

vec3 cubeNormal(int i) {
    vec4 corner = gl_in[0].gl_Position + vec4(vertDecals[i], 0);

    float y = texelFetch(dataFieldTex, ivec3(int(corner.y+1), int(corner.z), int(corner.x)), 0).r - texelFetch(dataFieldTex, ivec3(int(corner.y-1), int(corner.z), int(corner.x)), 0).r;
    float z = texelFetch(dataFieldTex, ivec3(int(corner.y), int(corner.z+1), int(corner.x)), 0).r - texelFetch(dataFieldTex, ivec3(int(corner.y), int(corner.z-1), int(corner.x)), 0).r;
    float x = texelFetch(dataFieldTex, ivec3(int(corner.y), int(corner.z), int(corner.x+1)), 0).r - texelFetch(dataFieldTex, ivec3(int(corner.y), int(corner.z), int(corner.x-1)), 0).r;

    return -normalize(vec3(x,y,z));
}

vec4 cubePos(int i){ 
    vec4 pos = gl_in[0].gl_Position;
    return vec4(step*pos.x,step*pos.y,step*pos.z,pos.w) + vec4(vertDecals[i]*step, 0); 
} 

int edgeVal(int i) {
    return texelFetch(edgeTableTex, ivec2(i, 0), 0).r;
}

int triTableValue(int i, int j){ 
    return texelFetch(triTableTex, ivec2(j, i), 0).r; 
}

vec3 calcTriangleNormal(vec4 p1, vec4 p2, vec4 p3){
    vec3 tangent1 = p2.xyz - p1.xyz;
    vec3 tangent2 = p3.xyz - p1.xyz;
    vec3 normal = cross(tangent1, tangent2);
    return -normalize(normal);
}

vec4 vertexInterp(float iso, vec4 p1, float v1, vec4 p2, float v2) {
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
    vec3 vert_norms[12];

    vert_list[0] = vertexInterp(isolevel, cubePos(0), cubeVal(0), cubePos(1), cubeVal(1));
    vert_norms[0] = cubeNormal(0);

    vert_list[1] = vertexInterp(isolevel, cubePos(1), cubeVal(1), cubePos(2), cubeVal(2));
    vert_norms[1] = cubeNormal(1);

    vert_list[2] = vertexInterp(isolevel, cubePos(2), cubeVal(2), cubePos(3), cubeVal(3));
    vert_norms[2] = cubeNormal(2);

    vert_list[3] = vertexInterp(isolevel, cubePos(3), cubeVal(3), cubePos(0), cubeVal(0));
    vert_norms[3] = cubeNormal(3);

    vert_list[4] = vertexInterp(isolevel, cubePos(4), cubeVal(4), cubePos(5), cubeVal(5));
    vert_norms[4] = cubeNormal(4);

    vert_list[5] = vertexInterp(isolevel, cubePos(5), cubeVal(5), cubePos(6), cubeVal(6));
    vert_norms[5] = cubeNormal(5);

    vert_list[6] = vertexInterp(isolevel, cubePos(6), cubeVal(6), cubePos(7), cubeVal(7));
    vert_norms[6] = cubeNormal(6);

    vert_list[7] = vertexInterp(isolevel, cubePos(7), cubeVal(7), cubePos(4), cubeVal(4));
    vert_norms[7] = cubeNormal(7);

    vert_list[8] = vertexInterp(isolevel, cubePos(0), cubeVal(0), cubePos(4), cubeVal(4));
    vert_norms[8] = cubeNormal(0);

    vert_list[9] = vertexInterp(isolevel, cubePos(1), cubeVal(1), cubePos(5), cubeVal(5));
    vert_norms[9] = cubeNormal(1);

    vert_list[10] = vertexInterp(isolevel, cubePos(2), cubeVal(2), cubePos(6), cubeVal(6));
    vert_norms[10] = cubeNormal(2);

    vert_list[11] = vertexInterp(isolevel, cubePos(3), cubeVal(3), cubePos(7), cubeVal(7));
    vert_norms[11] = cubeNormal(3);


    vert_color = vec4(0.3,0.8,0.2,1);

    for (int i=0;triTableValue(cube_index, i) != -1; i += 3){
        vec4 pos1 = projection_matrix * view_matrix * model_matrix * vert_list[triTableValue(cube_index, i+0)];
        vec4 pos2 = projection_matrix * view_matrix * model_matrix * vert_list[triTableValue(cube_index, i+1)];
        vec4 pos3 = projection_matrix * view_matrix * model_matrix * vert_list[triTableValue(cube_index, i+2)];

        // poly shading
        vert_normal = calcTriangleNormal(pos1, pos2, pos3);

        vert_normal = vert_norms[triTableValue(cube_index, i+0)];
        gl_Position = pos1;
        frag_position = (model_matrix * vert_list[triTableValue(cube_index, i+0)]).xyz;
        EmitVertex();

        vert_normal = vert_norms[triTableValue(cube_index, i+1)];
        gl_Position = pos2;
        frag_position = (model_matrix * vert_list[triTableValue(cube_index, i+1)]).xyz;
        EmitVertex();

        vert_normal = vert_norms[triTableValue(cube_index, i+2)];
        gl_Position = pos3;
        frag_position = (model_matrix * vert_list[triTableValue(cube_index, i+2)]).xyz;
        EmitVertex();
        
        EndPrimitive();

        gl_Position = pos1;
        frag_position = (model_matrix * vert_list[triTableValue(cube_index, i+0)]).xyz;
        EmitVertex();

        gl_Position = pos3;
        frag_position = (model_matrix * vert_list[triTableValue(cube_index, i+2)]).xyz;
        EmitVertex();

        gl_Position = pos2;
        frag_position = (model_matrix * vert_list[triTableValue(cube_index, i+1)]).xyz;
        EmitVertex();
        EndPrimitive();
    }
}


@frag
@include "lit_frag.glsl"