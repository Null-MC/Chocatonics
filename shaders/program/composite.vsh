#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


flat varying vec2 TAA_Offset;
flat varying vec3 WsunVec;

uniform sampler2D colortex4;

uniform int frameCounter;
uniform float sunElevation;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;

#include "/lib/util.glsl"


void main() {
	TAA_Offset = taa_offsets[frameCounter % 8];

	#ifndef TAA
		TAA_Offset = vec2(0.0);
	#endif

	gl_Position = ftransform();

	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * RENDER_SCALE * 2.0 - 1.0;
	#endif

	vec3 localSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	WsunVec = (float(sunElevation > 1.e-5) * 2.0 - 1.0) * localSunDir;
}
