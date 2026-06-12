#version 120

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec4 color;
varying vec2 texcoord;

uniform vec2 texelSize;
uniform int framemod8;


void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	gl_Position = ftransform();
	color = gl_Color;

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
