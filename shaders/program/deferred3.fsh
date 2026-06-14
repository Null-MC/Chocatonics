#version 430 compatibility

// Computes volumetric clouds at variable resolution (default 1/4 res)

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	flat vec3 sunColor;
	flat vec3 moonColor;
	flat vec3 avgAmbient;
//	flat float tempOffsets;
} vIn;

uniform sampler2D depthtex0;
uniform sampler2D noisetex;
uniform sampler2D texBlueNoise;
uniform sampler2D colortex4;
uniform sampler2D texSkyGradient;

uniform vec3 sunVec;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int frameCounter;
uniform int framemod8;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform mat4 gbufferProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;


#include "/lib/util.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/projections.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/volumetricClouds.glsl"


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
	#ifdef VOLUMETRIC_CLOUDS
		vec2 halfResTC = vec2(floor(gl_FragCoord.xy) / CLOUDS_QUALITY / RENDER_SCALE + 0.5 + taa_offsets[framemod8] * CLOUDS_QUALITY * RENDER_SCALE * 0.5);

		float noise = blueNoise(gl_FragCoord.xy, frameCounter);
		vec3 fragpos = toScreenSpace(vec3(halfResTC * texelSize, 1.0));
		outColor0 = renderClouds(fragpos, vec3(0.0), noise, vIn.sunColor, vIn.moonColor, vIn.avgAmbient);
	#else
		outColor0 = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
}
