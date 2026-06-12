#version 120

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec4 color;
varying vec2 texcoord;

uniform vec2 texelSize;
uniform int framemod8;


void main() {
	gl_Position = ftransform();
	texcoord = (gl_MultiTexCoord0).xy;
	color = gl_Color;

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
