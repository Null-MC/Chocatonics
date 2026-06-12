#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out vec2 texcoord;
flat out float exposureA;
flat out float tempOffsets;

uniform sampler2D colortex4;
uniform int frameCounter;

#include "/lib/util.glsl"


void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;

	tempOffsets = HaltonSeq2(frameCounter % 10000);
	exposureA = texelFetch2D(colortex4, ivec2(10, 37), 0).r;
}
