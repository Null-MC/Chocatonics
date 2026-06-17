vec3 rayTraceSpeculars(vec3 dir, vec3 position, float dither, float quality, bool hand, float fres) {
	vec3 clipPosition = toClipSpace3(position);

	float rayLength = ((position.z + dir.z * far*sqrt(3.0)) > -near) ?
	                   (-near -position.z) / dir.z : far*sqrt(3.0);

	vec3 direction = normalize(toClipSpace3(dir*rayLength + position) - clipPosition);  // convert to clip space
	direction.xy = normalize(direction.xy);

	// get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.0, direction) - clipPosition) / direction;
	float mult = minOf(maxLengths);

	vec3 stepv = direction * mult / quality * vec3(RENDER_SCALE_2, 1.0);

	vec3 spos = clipPosition * vec3(RENDER_SCALE_2, 1.0) + stepv*dither;

	float minZ = spos.z + stepv.z;
	float maxZ = spos.z + stepv.z;

	spos.xy += vIn.TAA_Offset * texelSize*0.5 / RENDER_SCALE;

	for (int i = 0; i <= int(quality); i++) {
		// decode depth buffer
		#ifdef REFLECTION_QUARTER_RES_DEPTH
			vec2 testthing = hand ? spos.xy*texelSize : spos.xy/texelSize/4.0; // fix for ssr on hand

			float sp = sqrt(texelFetch(texDepthQ, ivec2(testthing), 0).r / 65000.0);
			sp = invLinZ(sp, nearPlane, farPlane);
		#else
			float sp = texelFetch(depthtex1, ivec2(spos.xy / texelSize), 0).r;
		#endif

		if (sp <= max(maxZ, minZ) && sp >= min(maxZ, minZ)) {
			return vec3(spos.xy / RENDER_SCALE, sp);
		}

		spos += stepv;

		// small bias
		float biasamount = 0.0002;
		if (hand) biasamount = 0.01;
		minZ = maxZ-biasamount / linZ(spos.z, nearPlane, farPlane);

		maxZ += stepv.z;
	}

	return vec3(1.1);
}

// pain
void MaterialReflections(
	inout vec3 Output,
	float roughness,
	vec3 f0,
	vec3 albedo,
	vec3 sunPos,
	vec3 sunCol,
	float diffuse,
	float lightmap,
	vec3 normal,
	vec3 np3,
	vec3 fragpos,
	vec3 noise,
	bool hand)
{
	vec3 Reflections_Final = Output;
	float Outdoors = saturate(sqrt(lightmap - sky_occlusion_threshold)	* (sky_occlusion_threshold * 5.0 + 1.0));

	mat3 basis = CoordBase(normal);
	vec3 normSpaceView = -np3 * basis;

	// roughness stuff
	#ifdef REFLECTION_ROUGH
		int seed = (frameCounter % 40000) * 2 + frameCounter + 1;
		vec2  ij = fract(R2_samples(seed) + noise.rg);

		vec3 H = sampleGGXVNDF(normSpaceView, vec2(roughness), ij.x, ij.y, hand);

		if (hand) H = normalize(vec3(0.0, 0.0, 1.0));
	#else
		vec3 H = normalize(vec3(0.0, 0.0, 1.0));
	#endif

	vec3 Ln = reflect(-normSpaceView, clamp(H, -1.0, 1.0));
	vec3 L = basis * Ln;

	// fresnel stuff
	float fresnel = pow5(saturate(1.0 + dot(-Ln, H)));
	vec3 F = f0 + (1.0 - f0) * fresnel;

	float NdotV = saturate(dot(np3, normalize(normal)) * 5000.0);

	bool hasReflections = (f0.y * (1.0 - roughness * Roughness_Threshold)) > 0.02;
	if (!hasReflections || NdotV > 0.00001) Outdoors = 0.0;

	// SSR, Sky, and Sun reflections
	vec4 Reflections = vec4(0.0);
	vec3 SunReflection = diffuse * GGX2(normal, -np3,  sunPos, roughness, f0)/150.0 * 8.0/3.0 * sunCol * Sun_specular_Strength;

	#ifndef PHOTONICS_REFLECT_ENABLED
		vec3 SkyReflection = skyCloudsFromTex(L, colortex4).rgb * 0.035;
	#endif

//	#ifndef Sky_reflection
//		SkyReflection = Reflections_Final;
//	#endif

	#if defined(REFLECTION_ENABLED) && !defined(PHOTONICS_REFLECT_ENABLED)
		if (hasReflections && NdotV < 0.00001) { // Skip SSR if ray contribution is low
			// float rayQuality = REFLECTION_QUALITY;
			float rayQuality = mix(REFLECTION_QUALITY, 0.0, sqrt(roughness)); // Scale quality with ray contribution

			vec3 rtPos = rayTraceSpeculars(mat3(gbufferModelView) * L, fragpos.xyz, noise.b, rayQuality, hand, fresnel);

			if (rtPos.z < 1.0) { // Reproject on previous frame
				vec3 previousPosition = mul3(gbufferModelViewInverse, toScreenSpace(rtPos)) + (cameraPosition - previousCameraPosition);
				previousPosition = mul3(gbufferPreviousModelView, previousPosition);
				previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;

				if (all(equal(saturate(previousPosition.xy), previousPosition.xy))) {
					Reflections.rgb = texture(colortex5, previousPosition.xy).rgb;
					Reflections.a = 1.0;
				}
			}
		}
	#endif

	// check if the f0 is within the metal ranges, then tint by albedo if it's true.
	vec3 Metals = f0.y  >= 230.0/255.0 ? saturate(albedo + fresnel) : vec3(1.0);

	Reflections.rgb *= Metals;
	SunReflection *= Metals;

	#ifndef PHOTONICS_REFLECT_ENABLED
		SkyReflection *= Metals;
	#endif

	// darken albedos, and stop darkening where the sky gets occluded indoors
	#ifdef PHOTONICS_REFLECT_ENABLED
		Reflections_Final *= 1.0 - luma(F);
	#else
		Reflections_Final *= mix(1.0 - (Reflections.a * luma(F)), 1.0 - luma(F), Outdoors);
	#endif
	
	// apply all reflections to the lighting
	Reflections_Final += Reflections.rgb * luma(F);

	#ifndef PHOTONICS_REFLECT_ENABLED
		Reflections_Final += SkyReflection * luma(F) * (1.0-Reflections.a) * Outdoors;
	#endif

	#ifdef REFLECTION_ROUGH
		Output = Reflections_Final;
	#else
		// interpolate between the albedos and reflections using the roughness value instead of the sampling.
		Output = mix(Reflections_Final, Output, vec3(sqrt(roughness)));
	#endif

	Output += SunReflection;
}
