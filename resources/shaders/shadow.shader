@vert

@include "default_vert.glsl"



@frag

#version 330 core

void main() {
    gl_FragDepth = gl_FragCoord.z;
}
