#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	flat vec4 lightCol;
	flat vec3 WsunVec;
	flat vec3 ambientUp;
	flat vec3 ambientLeft;
	flat vec3 ambientRight;
	flat vec3 ambientB;
	flat vec3 ambientF;
	flat vec3 ambientDown;
//	flat float tempOffsets;
	flat vec2 TAA_Offset;
//	flat vec3 zMults;
	flat vec3 refractedSunVec;
} vOut;

//uniform sampler2D colortex4;

uniform float far;
uniform float near;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float sunElevation;
uniform int frameCounter;

#include "/lib/sceneBuffer.glsl"

#include "/lib/util.glsl"


void main() {
	gl_Position = ftransform();

	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * RENDER_SCALE * 2.0 - 1.0;
	#endif

//	vOut.tempOffsets = HaltonSeq2(frameCounter % 10000);
	vOut.TAA_Offset = taa_offsets[frameCounter % 8];

	#ifndef TAA_ENABLED
		vOut.TAA_Offset = vec2(0.0);
	#endif

	vOut.lightCol.a = float(sunElevation > 1.e-5) * 2.0 - 1.0;
	vOut.lightCol.rgb = scene.lightSourceColor; //texelFetch(colortex4, ivec2(6, 37), 0).rgb;

	vOut.ambientUp = scene.ambientUp; //texelFetch(colortex4, ivec2(0, 37), 0).rgb;
	vOut.ambientDown = scene.ambientDown; //texelFetch(colortex4, ivec2(1, 37), 0).rgb;
	vOut.ambientLeft = scene.ambientLeft; //texelFetch(colortex4, ivec2(2, 37), 0).rgb;
	vOut.ambientRight = scene.ambientRight; //texelFetch(colortex4, ivec2(3, 37), 0).rgb;
	vOut.ambientB = scene.ambientB; //texelFetch(colortex4, ivec2(4, 37), 0).rgb;
	vOut.ambientF = scene.ambientF; //texelFetch(colortex4, ivec2(5, 37), 0).rgb;

	vec3 localSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);

	vOut.WsunVec = vOut.lightCol.a * localSunDir;
//	vOut.zMults = vec3((far * near) * 2.0, far+near, far-near);
	vOut.refractedSunVec = refract(vOut.WsunVec, vec3(0.0, -1.0, 0.0), 1.0/1.33333);
}
