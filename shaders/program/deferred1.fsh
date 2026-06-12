#version 120
#extension GL_EXT_gpu_shader4 : enable

//Computes volumetric clouds at variable resolution (default 1/4 res)

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


flat varying vec3 sunColor;
flat varying vec3 moonColor;
flat varying vec3 avgAmbient;
flat varying float tempOffsets;

uniform sampler2D depthtex0;
uniform sampler2D noisetex;
uniform sampler2D texBlueNoise;
uniform sampler2D colortex4;

uniform vec3 sunVec;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int frameCounter;
uniform int framemod8;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;


vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

#include "/lib/util.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/volumetricClouds.glsl"


float R2_dither() {
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter);
}


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
	#ifdef VOLUMETRIC_CLOUDS
		vec2 halfResTC = vec2(floor(gl_FragCoord.xy) / CLOUDS_QUALITY / RENDER_SCALE + 0.5 + taa_offsets[framemod8] * CLOUDS_QUALITY * RENDER_SCALE * 0.5);

		float noise = blueNoise(gl_FragCoord.xy, frameCounter);
		vec3 fragpos = toScreenSpace(vec3(halfResTC * texelSize, 1.0));
		outColor0 = renderClouds(fragpos, vec3(0.0), noise, sunColor/150.0, moonColor/150.0, avgAmbient/150.0);
	#else
		outColor0 = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
}
