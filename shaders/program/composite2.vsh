#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


flat varying vec3 WsunVec;
flat varying vec3 ambientUp;
flat varying vec3 ambientLeft;
flat varying vec3 ambientRight;
flat varying vec3 ambientB;
flat varying vec3 ambientF;
flat varying vec3 ambientDown;
flat varying vec4 lightCol;
flat varying float tempOffsets;
flat varying vec2 TAA_Offset;
flat varying vec3 zMults;
flat varying vec3 refractedSunVec;

uniform sampler2D colortex4;

uniform float far;
uniform float near;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float sunElevation;
uniform int frameCounter;

#include "/lib/util.glsl"


void main() {
	gl_Position = ftransform();

	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * RENDER_SCALE * 2.0 - 1.0;
	#endif

	tempOffsets = HaltonSeq2(frameCounter % 10000);
	TAA_Offset = taa_offsets[frameCounter % 8];

	#ifndef TAA
		TAA_Offset = vec2(0.0);
	#endif

	lightCol.a = float(sunElevation > 1.e-5) * 2.0 - 1.0;
	lightCol.rgb = texelFetch2D(colortex4, ivec2(6, 37), 0).rgb;

	ambientUp = texelFetch2D(colortex4, ivec2(0, 37), 0).rgb;
	ambientDown = texelFetch2D(colortex4, ivec2(1, 37), 0).rgb;
	ambientLeft = texelFetch2D(colortex4, ivec2(2, 37), 0).rgb;
	ambientRight = texelFetch2D(colortex4, ivec2(3, 37), 0).rgb;
	ambientB = texelFetch2D(colortex4, ivec2(4, 37), 0).rgb;
	ambientF = texelFetch2D(colortex4, ivec2(5, 37), 0).rgb;

	vec3 localSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);

	WsunVec = lightCol.a * localSunDir;
	zMults = vec3((far * near) * 2.0, far+near, far-near);
	refractedSunVec = refract(WsunVec, -vec3(0.0, 1.0, 0.0), 1.0/1.33333);
}
