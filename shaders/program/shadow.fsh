#version 120
#extension GL_ARB_shader_texture_lod : enable
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec2 texcoord;

uniform sampler2D tex;
uniform sampler2D noisetex;
uniform sampler2D texBlueNoise;

#include "/lib/blueNoise.glsl"


void main() {
	gl_FragData[0] = texture2D(tex, texcoord.xy);

	#ifdef SHADOW_DISABLE_ALPHA_MIPMAPS
		gl_FragData[0].a = texture2DLod(tex, texcoord.xy, 0).a;
	#endif

	#ifdef Stochastic_Transparent_Shadows
		float noise = blueNoise(gl_FragCoord.xy).a;
		gl_FragData[0].a = float(gl_FragData[0].a >= noise);
	#endif
}
