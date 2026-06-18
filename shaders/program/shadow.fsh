#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec2 texcoord;
} vIn;

uniform sampler2D gtexture;

#ifdef Stochastic_Transparent_Shadows
	uniform sampler2D noisetex;
	uniform sampler2D texBlueNoise;
#endif

uniform float alphaTestRef;

#ifdef Stochastic_Transparent_Shadows
	#include "/lib/blueNoise.glsl"
#endif


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
	outColor = texture(gtexture, vIn.texcoord, Texture_MipMap_Bias);

	#ifdef SHADOW_DISABLE_ALPHA_MIPMAPS
		outColor.a = textureLod(gtexture, vIn.texcoord, 0).a;
	#endif

	#ifdef Stochastic_Transparent_Shadows
		float noise = blueNoise(gl_FragCoord.xy).a;
		outColor.a = float(outColor.a >= noise);
	#endif

	if (outColor.a < alphaTestRef) discard;
}
