#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	flat vec3 ambientUp;
	flat vec3 ambientLeft;
	flat vec3 ambientRight;
	flat vec3 ambientB;
	flat vec3 ambientF;
	flat vec3 ambientDown;
	flat vec3 sunColor;
	flat vec3 sunColorCloud;
	flat vec3 moonColor;
	flat vec3 moonColorCloud;
	flat vec3 lightSourceColor;
	flat vec3 avgSky;
	flat vec2 tempOffsets;
	flat float exposure;
	flat float avgBrightness;
	flat float rodExposure;
	flat float fogAmount;
	flat float VFAmount;
	flat float avgL2;
} vOut;

uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec2 texelSize;
uniform float rainStrength;
uniform float sunElevation;
uniform float nightVision;
uniform float near;
uniform float far;
uniform float frameTime;
uniform float eyeAltitude;
uniform int frameCounter;
uniform int worldTime;

#include "/lib/r2.glsl"
#include "/lib/util.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/ROBOBO_sky.glsl"


vec3 sunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);

vec3 rodSample(vec2 Xi) {
	float r = sqrt(1.0f - Xi.x*Xi.y);
    float phi = 2.0 * PI * Xi.y;

    return normalize(vec3(cos(phi) * r, sin(phi) * r, Xi.x)).xzy;
}


void main() {
	gl_Position = ftransform() * 0.5 + 0.5;
	gl_Position.xy = gl_Position.xy * vec2(18.0 + 258.0*2.0, 258.0) * texelSize;
	gl_Position.xy = gl_Position.xy * 2.0 - 1.0;

	vOut.tempOffsets = R2_samples(frameCounter % 10000);

	vOut.ambientUp = vec3(0.0);
	vOut.ambientDown = vec3(0.0);
	vOut.ambientLeft = vec3(0.0);
	vOut.ambientRight = vec3(0.0);
	vOut.ambientB = vec3(0.0);
	vOut.ambientF = vec3(0.0);
	vOut.avgSky = vec3(0.0);

	#ifndef WORLD_NETHER
		// Integrate sky light for each block side
		int maxIT = 20;
		for (int i = 0; i < maxIT; i++) {
			vec2 ij = R2_samples((frameCounter % 1000) * maxIT + i);
			vec3 pos = normalize(rodSample(ij));

			vec3 samplee = 1.72 * skyFromTex(pos, colortex4).rgb / maxIT / 150.0;
			vOut.avgSky += samplee / 1.72;

			vOut.ambientUp += samplee * (pos.y + abs(pos.x)/7.0 + abs(pos.z)/7.0);
			vOut.ambientLeft += samplee * (saturate(-pos.x) + saturate(pos.y/7.0) + abs(pos.z)/7.0);
			vOut.ambientRight += samplee * (saturate(pos.x) + saturate(pos.y/7.0) + abs(pos.z)/7.0);
			vOut.ambientB += samplee * (saturate(pos.z) + abs(pos.x)/7.0 + saturate(pos.y/7.0));
			vOut.ambientF += samplee * (saturate(-pos.z) + abs(pos.x)/7.0 + saturate(pos.y/7.0));
			vOut.ambientDown += samplee * (saturate(pos.y / 6.0) + abs(pos.x)/7.0 + abs(pos.z)/7.0);
		}

		vec2 planetSphere = vec2(0.0);
		vec3 sky = vec3(0.0);
		vec3 skyAbsorb = vec3(0.0);

		float sunVis = clamp(sunElevation, 0.0, 0.05) / 0.05 * clamp(sunElevation, 0.0, 0.05) / 0.05;
		float moonVis = clamp(-sunElevation, 0.0, 0.05) / 0.05 * clamp(-sunElevation, 0.0, 0.05) / 0.05;

		// TODO: unused?
		vec3 zenithColor = calculateAtmosphere(vec3(0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 1.0, 0.0), sunVec, -sunVec, planetSphere, skyAbsorb, 25, vOut.tempOffsets.x);

		skyAbsorb = vec3(0.0);
		vec3 absorb = vec3(0.0);
		vOut.sunColor = calculateAtmosphere(vec3(0.0), sunVec, vec3(0.0, 1.0, 0.0), sunVec, -sunVec, planetSphere, skyAbsorb, 25, 0.0);
		vOut.sunColor = sunColorBase / 4000.0 * skyAbsorb;

		skyAbsorb = vec3(1.0);
		float dSun = 0.03;
		vec3 modSunVec = sunVec * (1.0 - dSun) + vec3(0.0, dSun, 0.0);
		vec3 modSunVec2 = sunVec * (1.0 - dSun) + vec3(0.0, dSun, 0.0);
		if (modSunVec2.y > modSunVec.y) modSunVec = modSunVec2;

		vOut.sunColorCloud = calculateAtmosphere(vec3(0.0), modSunVec, vec3(0.0, 1.0, 0.0), sunVec, -sunVec, planetSphere, skyAbsorb, 25, 0.0);
		vOut.sunColorCloud = sunColorBase / 4000.0 * skyAbsorb;

		skyAbsorb = vec3(1.0);
		vOut.moonColor = calculateAtmosphere(vec3(0.0), -sunVec, vec3(0.0, 1.0, 0.0), sunVec, -sunVec, planetSphere, skyAbsorb, 25, 0.5);
		vOut.moonColor = moonColorBase / 4000.0 * skyAbsorb;

		skyAbsorb = vec3(1.0);
		modSunVec = -sunVec * (1.0 - dSun) + vec3(0.0, dSun, 0.0);
		modSunVec2 = -sunVec * (1.0 - dSun) + vec3(0.0, dSun, 0.0);
		if (modSunVec2.y > modSunVec.y) modSunVec = modSunVec2;

		vOut.moonColorCloud = calculateAtmosphere(vec3(0.0), modSunVec, vec3(0.0, 1.0, 0.0), sunVec, -sunVec, planetSphere, skyAbsorb, 25, 0.5);
		vOut.moonColorCloud = moonColorBase / 4000.0 * 0.55;

		#ifndef CLOUDS_SHADOWS
			vOut.sunColor *= (1.0 - rainStrength * vec3(0.96));
			vOut.moonColor *= (1.0 - rainStrength * vec3(0.96));
		#endif

		vOut.lightSourceColor = sunVis >= 1e-5 ? vOut.sunColor * sunVis : vOut.moonColor * moonVis;

		float lightDir = float(sunVis >= 1e-5) * 2.0 - 1.0;
	#endif

	// Fake bounced sunlight
	#ifdef WORLD_NETHER
		vec3 bouncedSun = saturate(gl_Fog.color.rgb * pow(luma(gl_Fog.color.rgb), -0.75) * 0.65) / 4000.0 * 0.08;

		vOut.ambientUp += bouncedSun * clamp(-sunVec.y + 5.0, 0.0, 6.0);
		vOut.ambientLeft += bouncedSun * clamp(sunVec.x + 5.0, 0.0, 6.0);
		vOut.ambientRight += bouncedSun * clamp(-sunVec.x + 5.0, 0.0, 6.0);
		vOut.ambientB += bouncedSun * clamp(-sunVec.z+5.0, 0.0, 6.0);
		vOut.ambientF += bouncedSun * clamp(sunVec.z+5.0, 0.0, 6.0);
		vOut.ambientDown += bouncedSun * clamp(sunVec.y+5.0, 0.0, 6.0);
	#else
		vec3 bouncedSun = vOut.lightSourceColor * 0.1/5.0 * 0.5 * saturate(lightDir * sunVec.y) * saturate(lightDir * sunVec.y);
		vec3 cloudAmbientSun = vOut.sunColorCloud * 0.007 * (1.0-rainStrength*0.5);
		vec3 cloudAmbientMoon = vOut.moonColorCloud * 0.007 * (1.0-rainStrength*0.5);

		vOut.ambientUp += bouncedSun * clamp(-lightDir*sunVec.y+4.0,0.0,4.0) + cloudAmbientSun*clamp(sunVec.y+2.,0.,4.0) + cloudAmbientMoon*clamp(-sunVec.y+2.,0.,4.0);
		vOut.ambientLeft += bouncedSun * clamp(lightDir*sunVec.x+4.0,0.0,4.0) + cloudAmbientSun*clamp(-sunVec.x+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(sunVec.x+2.,0.0,4.)*0.7;
		vOut.ambientRight += bouncedSun * clamp(-lightDir*sunVec.x+4.0,0.0,4.0) + cloudAmbientSun*clamp(sunVec.x+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(-sunVec.x+2.,0.0,4.)*0.7;
		vOut.ambientB += bouncedSun * clamp(-lightDir*sunVec.z+4.0,0.0,4.0) + cloudAmbientSun*clamp(sunVec.z+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(-sunVec.z+2.,0.0,4.)*0.7;
		vOut.ambientF += bouncedSun * clamp(lightDir*sunVec.z+4.0,0.0,4.0) + cloudAmbientSun*clamp(-sunVec.z+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(sunVec.z+2.,0.0,4.)*0.7;
		vOut.ambientDown += bouncedSun * clamp(lightDir*sunVec.y+4.0,0.0,4.0)*0.7 + cloudAmbientSun*clamp(-sunVec.y+2.,0.0,4.)*0.5 + cloudAmbientMoon*clamp(sunVec.y+2.,0.0,4.)*0.5;

		vOut.avgSky += bouncedSun * 2.5;

		vec3 rainNightBoost = vOut.moonColorCloud * rainStrength * 0.05;

		vOut.ambientUp += rainNightBoost;
		vOut.ambientLeft += rainNightBoost;
		vOut.ambientRight += rainNightBoost;
		vOut.ambientB += rainNightBoost;
		vOut.ambientF += rainNightBoost;
		vOut.ambientDown += rainNightBoost;
		vOut.avgSky += rainNightBoost;
	#endif

	float avgLuma = 0.0;
	float m2 = 0.0;
	int n = 100;
	vec2 clampedRes = max(1.0/texelSize, vec2(1920.0, 1080.0));
	float avgExp = 0.0;
	float avgB = 0.0;
	vec2 resScale = vec2(1920.0, 1080.0) / clampedRes * BLOOM_QUALITY;

	const int maxITexp = 50;
	float w = 0.0;
	for (int i = 0; i < maxITexp; i++) {
		vec2 ij = R2_samples((frameCounter % 2000) * maxITexp + i);
		vec2 tc = 0.5 + (ij-0.5) * 0.7;
		vec3 sp = texture(colortex6, tc/16.0 * resScale + vec2(0.375*resScale.x+4.5*texelSize.x, 0.0)).rgb;
		avgExp += log(luma(sp));
		avgB += log(min(dot(sp, vec3(0.07, 0.22, 0.71)), 8.e-2));
	}

	avgExp = exp(avgExp / maxITexp);
	avgB = exp(avgB / maxITexp);

	vOut.avgBrightness = texelFetch(colortex4, ivec2(10, 37), 0).g;
	vOut.avgBrightness = clamp(mix(avgExp, vOut.avgBrightness, 0.95), 0.00003051757, 65000.0);

	float L = max(vOut.avgBrightness, 1.e-8);
	float keyVal = 1.03 - 2.0 / (log(L*4000 / 150.0*8.0/3.0 + 1.0) / log(10.0) + 2.0);
	float targetExposure = 0.18 / log2(L*2.5 + 1.040 - nightVision*0.038) * 0.7;

	vOut.avgL2 = clamp(mix(avgB, texelFetch(colortex4, ivec2(10, 37), 0).b, 0.985), 0.00003051757, 65000.0);
	float targetrodExposure = max(0.012 / log2(vOut.avgL2 + 1.002) - 0.1, 0.0) * 1.2;

	vOut.exposure = targetExposure * EXPOSURE_MULTIPLIER;
	vOut.rodExposure = targetrodExposure;

	#ifndef AUTO_EXPOSURE
		vOut.exposure = Manual_exposure_value;
		vOut.rodExposure = clamp(log(Manual_exposure_value * 2.0 + 1.0) - 0.1, 0.0, 2.0);
	#endif

	float modWT = float(worldTime % 24000);

	float fogAmount0 = 1.0/3000.0+FOG_TOD_MULTIPLIER*(1.0/100.0*(clamp(modWT-11000.0,0.0,2000.0)/2000.0+(1.0-clamp(modWT,0.0,3000.0)/3000.0))*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.)) + 1/120.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.));
	vOut.VFAmount = CLOUDY_FOG_AMOUNT * (fogAmount0*fogAmount0 + FOG_RAIN_MULTIPLIER*1.0/20000.0*rainStrength);
	vOut.fogAmount = BASE_FOG_AMOUNT*(fogAmount0+max(FOG_RAIN_MULTIPLIER*1.0/10.0*rainStrength , FOG_TOD_MULTIPLIER*1.0/50.0*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.)));
}
