#define VL_SAMPLES2 6 //[4 6 8 10 12 14 16 20 24 30 40 50]


float phaseRayleigh(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) / PI;
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}

//float cloudVol2(in vec3 pos, in float VFAmount, in float fogAmount) {
//	vec3 samplePos = pos * vec3(1.0, 1.0/16.0, 1.0) + frameTimeCounter * vec3(0.5, 0.0, 0.5) * 5.0;
//	float coverage = mix(exp2(-(pos.y - SEA_LEVEL) * (pos.y - SEA_LEVEL) / 10000.0), 1.0, rainStrength * 0.5);
//	float noise = densityAtPos(samplePos * 12.0);
//	float unifCov = exp2(-max(pos.y - SEA_LEVEL, 0.0) / 50.0);
//
//	return pow(saturate(coverage - noise - 0.76), 2.0) * 1200.0/0.23 / (coverage + 0.01) * VFAmount * 600.0 + unifCov * 60.0 * fogAmount;
//}

float cloudVol(in vec3 pos, in float VFAmount, in float fogAmount) {
	vec3 samplePos = pos * vec3(1.0, 1.0/16.0, 1.0) + frameTimeCounter * vec3(0.5, 0.0, 0.5) * 5.0;
	float coverage = mix(exp2(-(pos.y - SEA_LEVEL) * (pos.y - SEA_LEVEL) / 10000.0), 1.0, rainStrength * 0.5);
	float noise = densityAtPos(samplePos * 12.0);
	float unifCov = exp2(-max(pos.y - SEA_LEVEL, 0.0) / 50.0);

	return pow(saturate(coverage - noise - 0.76), 2.0) * 1200.0/0.23 / (coverage + 0.01) * VFAmount * 600.0 + unifCov * 60.0 * fogAmount + rainStrength*2.0;
}

mat2x3 getVolumetricRays(float dither, vec3 fragpos, vec4 lightCol) {
	// project pixel position into projected shadowmap space
	vec3 wpos = mul3(gbufferModelViewInverse, fragpos);
	vec3 fragposition = mul3(shadowModelView, wpos);
	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;

	// project view origin into projected shadowmap space
	vec3 start = toShadowSpaceProjected(vec3(0.0));

	// rayvector into projected shadow map space
	// we can use a projected vector because its orthographic projection
	// however we still have to send it to curved shadow map space every step
	vec3 dV = fragposition - start;
	vec3 dVWorld = wpos - gbufferModelViewInverse[3].xyz;

	float maxLength = min(length(dVWorld), far) / length(dVWorld);
	dV *= maxLength;
	dVWorld *= maxLength;

	// apply dither
	vec3 progress = start.xyz;
	vec3 progressW = gbufferModelViewInverse[3].xyz + cameraPosition;
	vec3 vL = vec3(0.0);

	float SdotV = dot(sunVec, normalize(fragpos)) * lightCol.a;
	float dL = length(dVWorld);
	// Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
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

	vec3 skyCol0 = ambientLight * eyeBrightnessSmooth.y/240.0 * Ambient_Mult*2.0;
	// Makes fog more white idk how to simulate it correctly
	vec3 sunColor = lightCol.rgb;
	skyCol0 = skyCol0.rgb;

	vec3 rC = vec3(fog_coefficientRayleighR*1.e-6, fog_coefficientRayleighG*1.e-5, fog_coefficientRayleighB*1.e-5);
	vec3 mC = vec3(fog_coefficientMieR*1.e-6, fog_coefficientMieG*1.e-6, fog_coefficientMieB*1.e-6);

//	float mu = 1.0;
//	float muS = mu;

	vec3 absorbance = vec3(1.0);
	float expFactor = 11.0;
	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec;

	for (int i = 0; i < VL_SAMPLES2; i++) {
		float d = (pow(expFactor, (i+dither)/float(VL_SAMPLES2))/expFactor - 1.0/expFactor)/(1.0 - 1.0/expFactor);
		float dd = pow(expFactor, (i+dither)/float(VL_SAMPLES2)) * log(expFactor) / float(VL_SAMPLES2)/(expFactor-1.0);

		progress = start.xyz + d*dV;
		progressW = gbufferModelViewInverse[3].xyz + cameraPosition + d*dVWorld;

		//project into biased shadowmap space
		float distortFactor = calcDistort(progress.xy);
		vec3 pos = vec3(progress.xy*distortFactor, progress.z);
		float densityVol = cloudVol(progressW, vIn.VFAmount, vIn.fogAmount);
		float sh = 1.0;

		if (abs(pos.x) < 1.0-0.5/2048.0 && abs(pos.y) < 1.0-0.5/2048) {
			pos = pos * vec3(0.5, 0.5, 0.5/6.0) + 0.5;
			sh = texture(shadowtex0HW, pos);

			#ifdef VL_Clouds_Shadows
				const int rayMarchSteps = 6;

				float cloudShadow = 0.0;
				for (int i = 0; i < rayMarchSteps; i++) {
					vec3 cloudPos = progressW + WsunVec/abs(WsunVec.y)*(1500+(dither+i)/rayMarchSteps*1700-progressW.y);
					cloudShadow += getCloudDensity(cloudPos, 0);
				}

				cloudShadow = mix(1.0, exp(-cloudShadow*cloudDensity*1700/rayMarchSteps), mix(CLOUDS_SHADOWS_STRENGTH, 1.0, rainStrength));
				sh *= cloudShadow;
			#endif
		}

		// Water droplets(fog)
		float density = densityVol * ATMOSPHERIC_DENSITY * 300.0; // * mu

		// Just air
		vec2 airCoef = exp2(-max(progressW.y - SEA_LEVEL, 0.0) / vec2(8.0e3, 1.2e3) * vec2(6.,7.0)) * 6.0;

		// Pbr for air, yolo mix between mie and rayleigh for water droplets
		vec3 rL = rC * airCoef.x;
		vec3 m = (airCoef.y + density) * mC;
		vec3 vL0 = sunColor * sh * (rayL*rL+m*mie) + skyCol0 * (rL + m);
		vL += (vL0 - vL0 * exp(-(rL+m)*dd*dL)) / (rL+m + 0.00000001) * absorbance;
		absorbance *= saturate(exp(-(rL+m) * dd * dL));
	}

	return mat2x3(InputTransformLinear(vL), absorbance);
}
