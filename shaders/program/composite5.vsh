#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	flat vec4 lightCol;
	flat vec3 ambientUp;
	flat vec3 ambientLeft;
	flat vec3 ambientRight;
	flat vec3 ambientDown;
	flat vec3 ambientB;
	flat vec3 ambientF;
//	flat float tempOffsets;
	flat float fogAmount;
	flat float VFAmount;
	flat vec3 refractedSunVec;
	flat vec3 WsunVec;
} vOut;

//uniform sampler2D colortex4;

uniform vec3 sunPosition;
uniform float sunElevation;
uniform float rainStrength;
uniform int isEyeInWater;
uniform int frameCounter;
uniform int worldTime;
uniform mat4 gbufferModelViewInverse;

#include "/lib/sceneBuffer.glsl"

#include "/lib/util.glsl"


void main() {
//	vOut.tempOffsets = HaltonSeq2(frameCounter % 10000);

	gl_Position = ftransform();
	gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * (0.01 + VL_RENDER_RESOLUTION) * 2.0 - 1.0;

	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * RENDER_SCALE * 2.0 - 1.0;
	#endif

	vec3 avgAmbient = scene.avgSky;
	vOut.ambientUp = scene.ambientUp;
	vOut.ambientDown = scene.ambientDown;
	vOut.ambientLeft = scene.ambientLeft;
	vOut.ambientRight = scene.ambientRight;
	vOut.ambientB = scene.ambientB;
	vOut.ambientF = scene.ambientF;

	vOut.lightCol.rgb = scene.lightSourceColor;
	vOut.lightCol.a = float(sunElevation > 1.e-5) * 2.0 - 1.0;

	#ifndef VL_Clouds_Shadows
		vOut.lightCol.rgb *= (1.0 - 0.9*rainStrength);
	#endif

	float modWT = float(worldTime % 24000);

	float fogAmount0 = 1.0/3000.0 + FOG_TOD_MULTIPLIER*(1.0/100.0*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.))*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.)) + 1/120.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.));
	vOut.VFAmount = CLOUDY_FOG_AMOUNT * (fogAmount0*fogAmount0+FOG_RAIN_MULTIPLIER*1.0/20000.0*rainStrength);
	vOut.fogAmount = BASE_FOG_AMOUNT * (fogAmount0 + max(FOG_RAIN_MULTIPLIER * 1.0/10.0 * rainStrength, FOG_TOD_MULTIPLIER * 1.0/50.0 * clamp(modWT - 13000.0, 0.0, 1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.)));

	vOut.WsunVec = vOut.lightCol.a * normalize(mat3(gbufferModelViewInverse) * sunPosition);

	vOut.refractedSunVec = refract(vOut.WsunVec, vec3(0.0, -1.0, 0.0), 1.0/1.33333);
}
