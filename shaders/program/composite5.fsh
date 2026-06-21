#version 430 compatibility

// Volumetric fog rendering

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
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
} vIn;

uniform sampler2D noisetex;
uniform sampler2D texBlueNoise;
uniform sampler2D depthtex0;
uniform sampler2DShadow shadowtex0HW;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;

uniform vec3 sunVec;
uniform float far;
uniform int frameCounter;
uniform float rainStrength;
uniform float sunElevation;
uniform ivec2 eyeBrightnessSmooth;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform vec2 texelSize;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
//uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
//uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;

//#include "/lib/ign.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/waterOptions.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/projections.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/volumetricClouds.glsl"


float phaseRayleigh(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) / PI;
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}

float densityAtPosFog(in vec3 pos) {
	pos /= 18.0;
	pos.xz *= 0.5;

	vec3 p = floor(pos);
	vec3 f = fract(pos);

	f = (f*f) * (3.0-2.0*f);

	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0, 193.0);

	vec2 coord =  uv / 512.0;

	vec2 xy = texture(noisetex, coord).yx;

	return mix(xy.r, xy.g, f.y);
}

float cloudVol(in vec3 pos) {
	vec3 samplePos = pos * vec3(1.0, 1.0/16.0, 1.0) + frameTimeCounter * vec3(0.5, 0.0, 0.5) * 5.0;
	float coverage = mix(exp2(-(pos.y - SEA_LEVEL) * (pos.y - SEA_LEVEL) / 10000.0), 1.0, rainStrength * 0.5);
	float noise = densityAtPosFog(samplePos * 12.0);
	float unifCov = exp2(-max(pos.y-SEA_LEVEL, 0.0) / 50.0);

	float cloud = pow(clamp(coverage - noise - 0.76, 0.0, 1.0), 2.0) * 1200.0/0.23 / (coverage+0.01)*vIn.VFAmount*600 + unifCov*60.0*vIn.fogAmount + rainStrength*2.0;

	return cloud;
}

mat2x3 getVolumetricRays(float dither, vec3 fragpos, vec4 lightCol) {
	// project pixel position into projected shadowmap space
	vec3 wpos = toWorldSpace(fragpos);
	vec3 fragposition = mul3(shadowModelView, wpos);
	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;

	// project view origin into projected shadowmap space
	vec3 start = toShadowSpaceProjected(vec3(0.0));

	// rayvector into projected shadow map space
	// we can use a projected vector because its orthographic projection
	// however we still have to send it to curved shadow map space every step
	vec3 dV = fragposition - start;
	vec3 dVWorld = wpos - gbufferModelViewInverse[3].xyz;

	float maxLength = min(length(dVWorld), farPlane) / length(dVWorld);
	dV *= maxLength;
	dVWorld *= maxLength;

	// apply dither
	vec3 progress = start.xyz;
	vec3 progressW = gbufferModelViewInverse[3].xyz + cameraPosition;
	vec3 vL = vec3(0.0);

	float SdotV = dot(sunVec, normalize(fragpos)) * lightCol.a;
	float dL = length(dVWorld);
	//Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
	float mie = mix(phaseg(SdotV, fog_mieg1), phaseg(SdotV, fog_mieg2), 0.5);
	float rayL = phaseRayleigh(SdotV);
//	wpos.y = clamp(wpos.y,0.0,1.0);

	vec3 ambientCoefs = dVWorld / dot(abs(dVWorld), vec3(1.0));

	vec3 ambientLight = vIn.ambientUp * saturate(ambientCoefs.y);
	ambientLight += vIn.ambientDown * saturate(-ambientCoefs.y);
	ambientLight += vIn.ambientRight * saturate(ambientCoefs.x);
	ambientLight += vIn.ambientLeft * saturate(-ambientCoefs.x);
	ambientLight += vIn.ambientB * saturate(ambientCoefs.z);
	ambientLight += vIn.ambientF * saturate(-ambientCoefs.z);

	vec3 skyCol0 = ambientLight * eyeBrightnessSmooth.y/vec3(240.0) * Ambient_Mult*2.0 * 8.0/150.0/3.0;
	// Makes fog more white idk how to simulate it correctly
	vec3 sunColor = lightCol.rgb * 8.0/150.0/3.0;
	skyCol0 = skyCol0.rgb;

	vec3 rC = vec3(fog_coefficientRayleighR*1e-6, fog_coefficientRayleighG*1e-5, fog_coefficientRayleighB*1e-5);
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);

	float mu = 1.0;
	float muS = 1.0*mu;

	vec3 absorbance = vec3(1.0);
	float expFactor = 11.0;

//	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * lightCol.a;

	for (int i = 0; i < VL_SAMPLES; i++) {
		float d = (pow(expFactor, float(i+dither)/float(VL_SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(VL_SAMPLES)) * log(expFactor) / float(VL_SAMPLES)/(expFactor-1.0);
		progress = start.xyz + d*dV;
		progressW = gbufferModelViewInverse[3].xyz + cameraPosition + d*dVWorld;

		// project into biased shadowmap space
		float distortFactor = calcDistort(progress.xy);
		vec3 pos = vec3(progress.xy * distortFactor, progress.z);
		float densityVol = cloudVol(progressW);
		float sh = 1.0;

		if (IsInShadowMap(pos.xy)) {
			pos = pos * vec3(0.5, 0.5, 0.5/6.0) + 0.5;
			sh = texture(shadowtex0HW, pos);

			#ifdef VL_Clouds_Shadows
				const int rayMarchSteps = 6;

				float cloudShadow = 0.0;
				for (int i = 0; i < rayMarchSteps; i++) {
					vec3 cloudPos = progressW + vIn.WsunVec / abs(vIn.WsunVec.y) * (1500 + (dither+i) / rayMarchSteps*1700 - progressW.y);
					cloudShadow += getCloudDensity(cloudPos, 0);
				}

				cloudShadow = mix(1.0, exp(cloudShadow * cloudDensity * -1700/rayMarchSteps), mix(CLOUDS_SHADOWS_STRENGTH, 1.0, rainStrength));
				sh *= cloudShadow;
			#endif
		}

		// Water droplets(fog)
		float density = densityVol * ATMOSPHERIC_DENSITY * mu * 300.0;

		// Just air
		vec2 airCoef = exp2(-max(progressW.y - SEA_LEVEL, 0.0) / vec2(8.0e3, 1.2e3) * vec2(6.0, 7.0)) * 6.0;

		// Pbr for air, yolo mix between mie and rayleigh for water droplets
		vec3 rL = rC * airCoef.x;
		vec3 m = (airCoef.y + density) * mC;
		vec3 vL0 = sunColor * sh * (rayL*rL+m*mie) + skyCol0 * (rL + m);
		vL += (vL0 - vL0 * exp(-(rL+m)*dd*dL)) / ((rL+m)+0.00000001) * absorbance;
		absorbance *= saturate(exp(-(rL+m)*dd*dL));
	}

	return mat2x3(vL, absorbance);
}

float waterCaustics(vec3 wPos, vec3 lightSource) {
	vec2 pos = (wPos.xz - lightSource.xz / lightSource.y * wPos.y) * 4.0;
	vec2 movement = vec2(-0.02 * frameTimeCounter);
	float caustic = 0.0;
	float weightSum = 0.0;
	float radiance =  2.39996;

	float cos_rad = cos(radiance);
	float sin_rad = sin(radiance);
	mat2 rotationMatrix = mat2(
		vec2(cos_rad, -sin_rad),
		vec2(sin_rad,  cos_rad));

	vec2 displ = texture(noisetex, pos * vec2(3.0, 1.0)/96.0 + movement).bb * 2.0 - 1.0;
	pos = pos/2.0 + 1.74 * frameTimeCounter;

	for (int i = 0; i < 3; i++) {
		pos = rotationMatrix * pos;
		float w = exp2(-0.8 * i);
		caustic += pow(0.5 + sin(dot(pos * exp2(0.8*i) + displ*PI, vec2(0.5))) * 0.5, 6.0) * w/1.41;
		weightSum += w;
	}

	return caustic * weightSum;
}

void waterVolumetrics(inout vec3 inColor, vec3 rayStart, vec3 rayEnd, float estEyeDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL){
	int spCount = 16;

	vec3 start = toShadowSpaceProjected(rayStart);
	vec3 end = toShadowSpaceProjected(rayEnd);
	vec3 dV = (end-start);

	// limit ray length at 32 blocks for performance and reducing integration error
	// you can't see above this anyway
	float maxZ = min(rayLength, 32.0) / (1e-8 + rayLength);
	dV *= maxZ;
	vec3 dVWorld = mat3(gbufferModelViewInverse) * (rayEnd - rayStart) * maxZ;
	rayLength *= maxZ;
	float dY = normalize(mat3(gbufferModelViewInverse) * rayEnd).y * rayLength;
	vec3 absorbance = vec3(1.0);
	vec3 vL = vec3(0.0);
	float phase = phaseg(VdotL, Dirt_Mie_Phase);
	float expFactor = 11.0;
	vec3 progressW = gbufferModelViewInverse[3].xyz + cameraPosition;
//	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * vIn.lightCol.a;

	for (int i = 0; i < spCount; i++) {
		float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor) / (1.0 - 1.0/expFactor);		// exponential step position (0-1)
		float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount) / (expFactor-1.0);	//step length (derivative)
		vec3 spPos = start.xyz + dV*d;
		progressW = gbufferModelViewInverse[3].xyz + cameraPosition + d*dVWorld;

		// project into biased shadowmap space
		float distortFactor = calcDistort(spPos.xy);
		vec3 pos = vec3(spPos.xy * distortFactor, spPos.z);
		float sh = 1.0;

		if (IsInShadowMap(pos.xy)) {
			pos = pos * vec3(0.5, 0.5, 0.5/6.0) + 0.5;
			sh = texture(shadowtex0HW, pos);
		}

		vec3 ambientMul = exp(-max(estEyeDepth - dY * d, 0.0) * waterCoefs);
		vec3 sunMul = exp(-max((estEyeDepth - dY * d), 0.0) / abs(vIn.refractedSunVec.y) * waterCoefs);
		float sunCaustics = mix(waterCaustics(progressW, vIn.WsunVec)*0.5+0.5, 1.0, exp(-max((estEyeDepth - dY * d), 0.0) / 3.0));
		vec3 light = (sh * sunCaustics * lightSource * phase * sunMul + ambientMul*ambient) * scatterCoef;
		vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs * absorbance;
		absorbance *= exp(-dd * rayLength * waterCoefs);
	}

	inColor += vL;
}


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
	vec2 tc = floor(gl_FragCoord.xy) / VL_RENDER_RESOLUTION * texelSize + 0.5 * texelSize;
	float z = texture(depthtex0, tc).x;

	vec3 fragpos = toScreenSpace(vec3(tc/RENDER_SCALE, z));

	float noise = blueNoise(gl_FragCoord.xy, frameCounter);
	vec4 color;

	if (isEyeInWater == 0) {
		mat2x3 vl = getVolumetricRays(noise, fragpos, vIn.lightCol);
		float absorbance = dot(vl[1], vec3(0.22, 0.71, 0.07));

		color = vec4(vl[0], absorbance);
	}
	else {
//		float dirtAmount = Dirt_Amount;
		vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
		vec3 totEpsilon = dirtEpsilon * Dirt_Amount + waterEpsilon;
		vec3 scatterCoef = Dirt_Amount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B);

		float estEyeDepth = saturate((14.0 - eyeBrightnessSmooth.y/255.0 * 16.0) / 14.0);
		estEyeDepth *= square(estEyeDepth) * 34.0;
		#ifndef lightMapDepthEstimation
			estEyeDepth = max(Water_Top_Layer - cameraPosition.y, 0.0);
		#endif

		vec3 vl = vec3(0.0);
		waterVolumetrics(vl, vec3(0.0), fragpos, estEyeDepth, estEyeDepth, length(fragpos), noise, totEpsilon, scatterCoef, vIn.ambientUp * 8.0/150.0/3.0*0.5, vIn.lightCol.rgb * 8.0/150.0/3.0 * (1.0 - pow(1.0 - sunElevation * vIn.lightCol.a, 5.0)), dot(normalize(fragpos), normalize(sunVec)));

		color = vec4(vl, 1.0);
	}

	outColor0 = clamp(color, 0.000001, 65000.0);
}
