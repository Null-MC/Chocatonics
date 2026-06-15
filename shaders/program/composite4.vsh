#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	flat vec4 lightCol;
//	flat vec3 ambientUp;
//	flat vec3 ambientLeft;
//	flat vec3 ambientRight;
//	flat vec3 ambientDown;
//	flat vec3 ambientB;
//	flat vec3 ambientF;
////	flat float tempOffsets;
	flat vec2 TAA_Offset;
//	flat float fogAmount;
//	flat float VFAmount;
//	flat vec3 refractedSunVec;
	flat vec3 WsunVec;
} vOut;

uniform sampler2D colortex4;

uniform vec3 sunPosition;
uniform float sunElevation;
uniform float rainStrength;
//uniform int isEyeInWater;
uniform int frameCounter;
//uniform int worldTime;
uniform mat4 gbufferModelViewInverse;

//#include "/lib/util.glsl"


void main() {
	#ifdef TAA_ENABLED
		vOut.TAA_Offset = taa_offsets[frameCounter % 8];
	#else
		vOut.TAA_Offset = vec2(0.0);
	#endif

	gl_Position = ftransform();

	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * RENDER_SCALE * 2.0 - 1.0;
	#endif

	//	vOut.tempOffsets = HaltonSeq2(frameCounter % 10000);

	vec3 sc = texelFetch(colortex4, ivec2(6, 37), 0).rgb;
//	vec3 avgAmbient = texelFetch(colortex4, ivec2(11, 37), 0).rgb;
//	vOut.ambientUp = texelFetch(colortex4, ivec2(0, 37), 0).rgb;
//	vOut.ambientDown = texelFetch(colortex4, ivec2(1, 37), 0).rgb;
//	vOut.ambientLeft = texelFetch(colortex4, ivec2(2, 37), 0).rgb;
//	vOut.ambientRight = texelFetch(colortex4, ivec2(3, 37), 0).rgb;
//	vOut.ambientB = texelFetch(colortex4, ivec2(4, 37), 0).rgb;
//	vOut.ambientF = texelFetch(colortex4, ivec2(5, 37), 0).rgb;

	vOut.lightCol.a = float(sunElevation > 1.e-5) * 2.0 - 1.0;
	vOut.lightCol.rgb = sc;

	#ifndef VL_Clouds_Shadows
		vOut.lightCol.rgb *= (1.0 - 0.9*rainStrength);
	#endif

//	float modWT = (worldTime%24000)*1.0;

//	float fogAmount0 = 1.0/3000.0 + FOG_TOD_MULTIPLIER*(1.0/100.0*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.))*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.)) + 1/120.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.));
//	vOut.VFAmount = CLOUDY_FOG_AMOUNT * (fogAmount0*fogAmount0+FOG_RAIN_MULTIPLIER*1.0/20000.0*rainStrength);
//	vOut.fogAmount = BASE_FOG_AMOUNT * (fogAmount0+max(FOG_RAIN_MULTIPLIER*1/10.*rainStrength , FOG_TOD_MULTIPLIER*1/50.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.)));

	vOut.WsunVec = vOut.lightCol.a * normalize(mat3(gbufferModelViewInverse) * sunPosition);

//	vOut.refractedSunVec = refract(vOut.WsunVec, -vec3(0.0, 1.0, 0.0), 1.0/1.33333);
}
