#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	float viewDist;
} vIn;

uniform float far;

//#ifdef Stochastic_Transparent_Shadows
//	uniform sampler2D noisetex;
//	uniform sampler2D texBlueNoise;
//#endif

//#ifdef Stochastic_Transparent_Shadows
//	#include "/lib/blueNoise.glsl"
//#endif


void main() {
//	outColor = vec4(1.0);

	if (vIn.viewDist < 0.85 * far) discard;

//	#ifdef Stochastic_Transparent_Shadows
//		float noise = blueNoise(gl_FragCoord.xy).a;
//		outColor.a = float(outColor.a >= noise);
//	#endif
}
