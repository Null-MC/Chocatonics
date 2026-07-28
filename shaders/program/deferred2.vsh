#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	flat vec3 sunColor;
	flat vec3 moonColor;
	flat vec3 avgAmbient;
//	flat float tempOffsets;
} vOut;

uniform sampler2D colortex4;
uniform int frameCounter;

#include "/lib/util.glsl"


void main() {
//	vOut.tempOffsets = HaltonSeq2(frameCounter % 10000);

	vOut.sunColor = texelFetch(colortex4, ivec2(12, 37), 0).rgb;
	vOut.moonColor = texelFetch(colortex4, ivec2(13, 37), 0).rgb;
	vOut.avgAmbient = texelFetch(colortex4, ivec2(11, 37), 0).rgb;

	gl_Position = ftransform();
	gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * saturate(CLOUDS_QUALITY + 0.01) * 2.0 - 1.0;

	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * RENDER_SCALE * 2.0 - 1.0;
	#endif
}
