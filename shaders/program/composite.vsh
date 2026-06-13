#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	flat vec3 sunVecW;
	flat vec2 taa_offset;
} vOut;

uniform int frameCounter;
uniform float sunElevation;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;


void main() {
	vec3 localSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	vOut.sunVecW = (float(sunElevation > 1.e-5) * 2.0 - 1.0) * localSunDir;

	#ifdef TAA_ENABLED
		vOut.taa_offset = taa_offsets[frameCounter % 8];
	#else
		vOut.taa_offset = vec2(0.0);
	#endif

	gl_Position = ftransform();

	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * RENDER_SCALE * 2.0 - 1.0;
	#endif
}
