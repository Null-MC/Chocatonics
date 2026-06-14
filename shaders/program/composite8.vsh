#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out vec2 texcoord;
flat out float exposureA;
flat out float tempOffsets;

uniform int frameCounter;

#include "/lib/sceneBuffer.glsl"

#include "/lib/util.glsl"


void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;

	tempOffsets = HaltonSeq2(frameCounter % 10000);
	exposureA = scene.exposure;
}
