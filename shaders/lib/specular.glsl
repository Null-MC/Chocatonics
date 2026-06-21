// #define TEX_SKY_LUT colortex4 | gaux1


vec3 rayTraceSpeculars(vec3 dir, vec3 position, float dither, float quality, bool hand, float fres) {
	vec3 clipPosition = toClipSpace3(position);

	float rayLength = ((position.z + dir.z * farPlane*sqrt(3.0)) > -near) ?
	                   (-near -position.z) / dir.z : farPlane*sqrt(3.0);

	vec3 direction = normalize(toClipSpace3(dir*rayLength + position) - clipPosition);  // convert to clip space
	direction.xy = normalize(direction.xy);

	// get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.0, direction) - clipPosition) / direction;
	float mult = minOf(maxLengths);

	vec3 stepv = direction * mult / quality * vec3(RENDER_SCALE_2, 1.0);

	vec3 spos = clipPosition * vec3(RENDER_SCALE_2, 1.0) + stepv*dither;

	float minZ = spos.z + stepv.z;
	float maxZ = spos.z + stepv.z;

	spos.xy += v_taa_offset * texelSize*0.5 / RENDER_SCALE;

	for (int i = 0; i <= int(quality); i++) {
		// decode depth buffer
		#if defined(REFLECTION_QUARTER_RES_DEPTH) && !defined(RENDER_VOXY)
			vec2 testthing = hand ? spos.xy*texelSize : spos.xy/texelSize/4.0; // fix for ssr on hand

			float sp = sqrt(texelFetch(texDepthQ, ivec2(testthing), 0).r / 65000.0);
			sp = invLinZ(sp, nearPlane, farPlane);
		#else
			float sp = texelFetch(TEX_DEPTH, ivec2(spos.xy / texelSize), 0).r;
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
	float f0,
	vec3 albedo,
	vec3 sunPos,
	vec3 sunCol,
	vec3 skyShading,
	float lightmap,
	vec3 normal,
	vec3 np3,
	vec3 fragpos,
	vec3 noise,
	bool hand)
{
	vec3 Reflections_Final = vec3(0.0);
	float Outdoors = saturate(sqrt(lightmap - sky_occlusion_threshold)	* (sky_occlusion_threshold * 5.0 + 1.0));

	mat3 basis = CoordBase(normal);
	vec3 normSpaceView = -np3 * basis;

//	roughness = square(roughness);

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
	vec3 F = vec3(f0 + (1.0 - f0) * fresnel);
//	vec3 F = vec3(schlick(dot(Ln, H), f0, 1.0));

	float NdotV = saturate(dot(np3, normalize(normal)) * 5000.0);

	bool hasReflections = true;//(f0 * (1.0 - roughness * Roughness_Threshold)) > 0.02;
//	bool hasReflections = true;
	if (!hasReflections || NdotV > 0.00001) Outdoors = 0.0;

	// SSR, Sky, and Sun reflections
	vec4 Reflections = vec4(0.0);
	vec3 SunReflection = skyShading * GGX2(normal, -np3, sunPos, roughness, vec3(f0)) * sunCol * Sun_specular_Strength / 150.0 * 8.0/3.0;

//	#if !defined(PHOTONICS_REFLECT_ENABLED) || (defined(RENDER_GBUFFERS) && !defined(RENDER_VOXY))
	#if !defined(PHOTONICS_REFLECT_ENABLED) || defined(RENDER_VOXY)
		vec3 SkyReflection = skyCloudsFromTex(L, TEX_SKY_LUT).rgb * 0.035;
	#endif

	#if defined(REFLECTION_ENABLED) && (defined(RENDER_GBUFFERS) || defined(RENDER_VOXY) || !defined(PHOTONICS_REFLECT_ENABLED))
		if (hasReflections) { // Skip SSR if ray contribution is low
			#if defined(PHOTONICS_REFLECT_ENABLED) && !defined(RENDER_VOXY)
				vec3 localPos = mul3(gbufferModelViewInverse, fragpos);
				Outdoors = 1.0;

				RayIterator ray;
				ray.iterations = PHOTONICS_REFLECT_STEPS;
				ray_iter_set_position(ray, localPos + rt_camera_position);
				ray_iter_set_direction(ray, L);
				ray_iter_offset_position(ray, 0.02 * normal); // TODO: this needs geo normal not tex

				RayResult hit = ray_iter_next(ray);
				if (ray_result_is_hit(hit) && ray_iter_is_in_bounds(ray)) {
					VoxelData voxel_data = ray_result_voxel_data(hit);
					vec3 hit_albedo = voxel_data_albedo(voxel_data).rgb;

					vec3 hit_position = ray_result_position(hit);
					vec3 hitLocalPos = hit_position - rt_camera_position;
					vec3 hit_localNormal = ray_result_normal(hit);

					float hit_sky = ray_result_skylight(hit) / 15.0;
					vec2 hit_lmcoord = vec2(0.0, hit_sky);

					// shadows
					vec3 projectedShadowPosition = worldToShadowSpaceProjected(hitLocalPos);

					// apply distortion
					float distortFactor = calcDistort(projectedShadowPosition.xy);
					projectedShadowPosition.xy *= distortFactor;

					vec3 shadow = vec3(1.0);
					float hit_sky_NoLm = max(dot(hit_localNormal, sunPos), 0.0);

					// do shadows only if on shadow map
					if (IsInShadowMap(projectedShadowPosition)) {
//						float rdMul = filtered.x * distortFactor * shadow_d0 * shadow_k / shadowMapResolution;
						const float threshMul = max(2048.0 / shadowMapResolution * shadowDistance/128.0, 0.95);
						float distortThresh = (sqrt(1.0 - square(hit_sky_NoLm)) / hit_sky_NoLm + 0.7) / distortFactor;

						projectedShadowPosition = projectedShadowPosition * vec3(0.5, 0.5, 0.5/6.0) + vec3(0.5, 0.5, 0.5);

						float rdMul = 4.0 / shadowMapResolution;
						float diffthresh = distortThresh/6000.0 * threshMul;
						float bias = 1.0 + noise.b * rdMul/SHADOW_FILTER_SAMPLE_COUNT * shadowMapResolution;
						vec3 samplePos = vec3(projectedShadowPosition + vec3(0.0, 0.0, -diffthresh * bias));

						shadow = vec3(texture(shadowtex0HW, samplePos));

						// TODO: shadow color
					}

					// TODO: shadow clouds

					vec3 hit_color = vec3(0.0);

					#ifdef MAT_SPECULAR_ENABLED
						vec4 hit_specularData = voxel_data_specular(voxel_data);

//						float hit_roughness = square(1.0 - hit_specularData.r);
//						float hit_f0 = hit_specularData.g;
//						if (hit_f0 < EPSILON) hit_f0 = 0.04;

						float hit_sss = mat_sss(hit_specularData.b);

						// apply emission
						float hit_emission = mat_emission(hit_specularData);
						hit_color += pow(hit_emission, Emission_Curve) * 3.0 * MAT_EMISSION_SCALE;
					#else
//						float hit_roughness = 1.0;
//						float hit_f0 = 0.04;
						float hit_sss = 0.0;
					#endif

					// block and sky lighting
					#ifdef RENDER_GBUFFERS
						vec3 direct = sunCol * shadow * hit_sky_NoLm;// * hit_sky;

						vec3 diffuseLight = direct/PI + texture(TEX_SKY_LUT, (hit_lmcoord * 15.0 + 0.5) * texelSize).rgb;
						hit_color += diffuseLight * 8.0/3.0 / 150.0;
					#else
						vec3 ambientCoefs = hit_localNormal / dot(abs(hit_localNormal), vec3(1.0));
						vec3 ambientLight = vIn.ambientUp * mix(saturate(ambientCoefs.y), 1.0/6.0, hit_sss);
						ambientLight += vIn.ambientDown * mix(saturate(-ambientCoefs.y), 1.0/6.0, hit_sss);
						ambientLight += vIn.ambientRight * mix(saturate(ambientCoefs.x), 1.0/6.0, hit_sss);
						ambientLight += vIn.ambientLeft * mix(saturate(-ambientCoefs.x), 1.0/6.0, hit_sss);
						ambientLight += vIn.ambientB * mix(saturate(ambientCoefs.z), 1.0/6.0, hit_sss);
						ambientLight += vIn.ambientF * mix(saturate(-ambientCoefs.z), 1.0/6.0, hit_sss);

						vec3 custom_lightmap = texture(TEX_SKY_LUT, (hit_lmcoord * 15.0 + 0.5 + vec2(0.0, 19.0)) * texelSize).rgb / 150.0 * 8.0/3.0;
						ambientLight = ambientLight * custom_lightmap.x + custom_lightmap.z * vec3(0.9, 1.0, 1.5) + custom_lightmap.y * TorchColor;
						hit_color += (hit_sky_NoLm * shadow)/PI * sunCol * 8.0/3.0 / 150.0 + ambientLight;
					#endif

					Reflections.rgb = hit_color * hit_albedo;
				}
				else {
					Reflections.rgb = skyCloudsFromTex(L, TEX_SKY_LUT).rgb * 0.035;
				}
				Reflections.a = 1.0;
			#else
				// Scale quality with ray contribution
				float rayQuality = mix(float(REFLECTION_QUALITY), 0.0, sqrt(roughness));

				vec3 rtPos = rayTraceSpeculars(mat3(gbufferModelView) * L, fragpos, noise.b, rayQuality, hand, fresnel);

				if (rtPos.z < 1.0) { // Reproject on previous frame
					vec3 previousPosition = mul3(gbufferModelViewInverse, toScreenSpace(rtPos)) + (cameraPosition - previousCameraPosition);
					previousPosition = mul3(gbufferPreviousModelView, previousPosition);
					previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;

					if (all(equal(saturate(previousPosition.xy), previousPosition.xy))) {
						Reflections.rgb = texture(TEX_FINAL_PREV, previousPosition.xy).rgb;
						Reflections.a = 1.0;
					}
				}
			#endif
		}
	#endif

	// check if the f0 is within the metal ranges, then tint by albedo if it's true.
//	vec3 metal_tint = f0 > 229.5/255.0 ? albedo : vec3(1.0);
	vec3 metal_tint = mix(vec3(1.0), albedo, f0 > 229.5/255.0);

	Reflections.rgb *= metal_tint;
	SunReflection *= metal_tint;

//	#if !defined(PHOTONICS_REFLECT_ENABLED) || (defined(RENDER_GBUFFERS) && !defined(RENDER_VOXY))
	#if !defined(PHOTONICS_REFLECT_ENABLED) || defined(RENDER_VOXY)
		SkyReflection *= metal_tint;
	#endif

	// darken albedos, and stop darkening where the sky gets occluded indoors
	#if defined(PHOTONICS_REFLECT_ENABLED) && !defined(RENDER_VOXY)
		Output *= 1.0 - F;
	#else
		Output *= mix(1.0 - (Reflections.a * F), 1.0 - F, Outdoors);
	#endif
	
	// apply all reflections to the lighting
	Reflections_Final += Reflections.rgb;

	#if !defined(PHOTONICS_REFLECT_ENABLED) || defined(RENDER_VOXY)
//	#if !defined(PHOTONICS_REFLECT_ENABLED) || (defined(RENDER_GBUFFERS) && !defined(RENDER_VOXY))
		Reflections_Final += SkyReflection * (1.0-Reflections.a) * Outdoors;
	#endif

	Reflections_Final *= F;

	#ifdef REFLECTION_ROUGH
		Output += Reflections_Final * (1.0 - sqrt(roughness));
	#else
		// interpolate between the albedos and reflections using the roughness value instead of the sampling.
		Output = mix(Output + Reflections_Final, Output, vec3(sqrt(roughness)));
	#endif

	Output += SunReflection;
}
