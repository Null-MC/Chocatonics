#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	vec2 texcoord;
	flat vec4 exposure;
	flat vec2 rodExposureDepth;
} vOut;

#include "/lib/sceneBuffer.glsl"


void main() {
	gl_Position = ftransform();
	vOut.texcoord = gl_MultiTexCoord0.xy;

	vOut.exposure = vec4(scene.exposure * vec3(FinalR, FinalG, FinalB), scene.exposure);
	vOut.rodExposureDepth = vec2(scene.rodExposure, scene.centerDepth);
}
