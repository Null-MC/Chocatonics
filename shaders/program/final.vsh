#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out vec2 texcoord;


void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
}
