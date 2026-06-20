#version 430 compatibility

// Photonics world-space reflection trace

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
////	flat float tempOffsets;
	flat vec2 TAA_Offset;
//	flat float fogAmount;
//	flat float VFAmount;
//	flat vec3 refractedSunVec;
	flat vec3 WsunVec;
} vIn;

uniform sampler2D TEX_GB_COLOR;
uniform sampler2D TEX_GB_NORMAL;
uniform sampler2D TEX_GB_SPECULAR;
uniform sampler2D TEX_GB_WORLD;
uniform sampler2D noisetex;
uniform sampler2D texBlueNoise;
uniform sampler2D depthtex0;
uniform sampler2DShadow shadowtex0HW;
//uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;

#ifdef REFLECTION_ACCUMULATE
	uniform sampler2D TEX_REFLECT_HISTORY;
#endif

uniform float far;
uniform float near;
//uniform vec3 sunVec;
uniform int frameCounter;
//uniform float rainStrength;
//uniform float sunElevation;
//uniform ivec2 eyeBrightnessSmooth;
//uniform float frameTimeCounter;
//uniform int isEyeInWater;
uniform vec2 texelSize;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 shadowLightPosition;

#include "/lib/r2.glsl"
#include "/lib/ggx.glsl"
//#include "/lib/ign.glsl"
#include "/lib/fresnel.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/material.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/octohedral.glsl"
//#include "/lib/waterOptions.glsl"
#include "/lib/Shadow_Params.glsl"
//#include "/lib/color_transforms.glsl"
//#include "/lib/color_dither.glsl"
#include "/lib/projections.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/sky_gradient.glsl"
//#include "/lib/volumetricClouds.glsl"

#include "/photonics/tracing.glsl"
#include "/photonics/trace_ray.glsl"


vec3 toClipSpacePrev3(const in vec3 viewSpacePosition) {
	return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec2 reproject(const in vec3 screenPos, const in float reflectDist) {
	vec3 viewPos = toScreenSpace(screenPos);

	// parallax offset
	viewPos += reflectDist * normalize(viewPos);

    vec3 localPos = mul3(gbufferModelViewInverse, viewPos);

	// camera movement
	vec3 prev_localPos = localPos + cameraPosition - previousCameraPosition;

	vec3 prev_viewPos = mul3(gbufferPreviousModelView, prev_localPos);

	// parallax offset
//	prev_viewPos -= reflectDist * normalize(prev_viewPos);

	return toClipSpacePrev3(prev_viewPos).xy;
}

float pack_8bit_float_and_uint(float floatVal, uint uintVal) {
	// 1. Clamp values to guarantee they fit in 8 bits
	float clampedFloat = clamp(floatVal, 0.0, 1.0);
	float clampedUint  = float(clamp(uintVal, 0u, 255u));

	// 2. Quantize the float to exactly 8 bits of precision (values like 0/255, 1/255... 255/255)
	float quantizedFloat = floor(clampedFloat * 255.0) / 255.0;

	// 3. Compress the fractional float so it strictly stays below 1.0
	// This scales the range [0.0, 1.0] down to [0.0, 255.0/256.0]
	float fractionalPart = quantizedFloat * (255.0 / 256.0);

	// 4. Combine them into a single float value (Max total value: ~255.996)
	return clampedUint + fractionalPart;
}

void unpack_8bit_float_and_uint(float packedVal, out float floatVal, out uint uintVal) {
	// 1. Extract the integer portion to get the original 8-bit uint
	float intPart = floor(packedVal);
	uintVal = uint(intPart);

	// 2. Extract the fractional remainder
	float fractionalPart = fract(packedVal);

	// 3. Reverse the scaling factor to reconstruct the [0.0, 1.0] range
	floatVal = fractionalPart * (256.0 / 255.0);

	// 4. Clean up minor floating-point precision variances
	floatVal = clamp(floatVal, 0.0, 1.0);
}


#if defined(REFLECTION_ROUGH) && (defined(REFLECTION_ACCUMULATE) || defined(REFLECTION_NEIGHBOR_CLAMP))
	/* RENDERTARGETS: 13 */
	layout(location = 0) out vec4 outColor13;
#else
	/* RENDERTARGETS: 3 */
	layout(location = 0) out vec4 outColor3;
#endif

void main() {
	vec2 texcoord = gl_FragCoord.xy * texelSize;
	float z = texture(depthtex0, texcoord).x;

	vec3 screenPos = vec3(texcoord / RENDER_SCALE - vIn.TAA_Offset * texelSize, z);

	vec3 reflect_color = vec3(0.0);
	float reflectDist = 0.0;
	float roughness = 1.0;

	if (z < 1.0) {
		vec3 viewPos = toScreenSpace(screenPos);
		vec3 localPos = mat3(gbufferModelViewInverse) * viewPos;
		vec3 localViewDir = normVec(localPos);

		localPos += gbufferModelViewInverse[3].xyz;

		vec4 color = texture(TEX_GB_COLOR, texcoord);
		vec3 albedo = InputTransform(color.rgb);

		vec4 normalData = texture(TEX_GB_NORMAL, texcoord);
		vec3 geoViewNormal = OctDecode(normalData.xy);
		vec3 tex_normal = OctDecode(normalData.zw);

		vec3 geoLocalNormal = mat3(gbufferModelViewInverse) * geoViewNormal;
		vec3 normal = mat3(gbufferModelViewInverse) * tex_normal;

		vec4 specularData = texture(TEX_GB_SPECULAR, texcoord);

		vec4 worldData = texture(TEX_GB_WORLD, texcoord);
		vec2 lightmap = worldData.xy;
		float mat = worldData.w;

		bool hand = abs(mat-0.75) < 0.01;

		roughness = square(1.0 - specularData.r);
		float f0 = specularData.g;

		mat3 basis = CoordBase(normal);
		vec3 normSpaceView = -localViewDir * basis;

		// roughness stuff
		#ifdef REFLECTION_ROUGH
			vec2 noise2 = blueNoise(texBlueNoise, gl_FragCoord.xy).rg;

			int seed = (frameCounter % 40000) * 2 + frameCounter + 1;
			vec2  ij = fract(R2_samples(seed) + noise2);

			vec3 H = sampleGGXVNDF(normSpaceView, vec2(roughness), ij.x, ij.y, hand);

			if (hand) H = normalize(vec3(0.0, 0.0, 1.0));
		#else
			const vec3 H = vec3(0.0, 0.0, 1.0);
		#endif

		vec3 Ln = reflect(-normSpaceView, clamp(H, -1.0, 1.0));
		vec3 reflectLocalDir = basis * Ln;

		// fresnel stuff
		float F = schlick(dot(Ln, H), f0, 1.0);

		float NdotV = saturate(dot(localViewDir, normalize(normal)) * 5000.0);

		bool hasReflections = (f0 * (1.0 - roughness * Roughness_Threshold)) > 0.02;

//		bool is_hit = false;
		if (hasReflections && NdotV < 0.00001) { // Skip SSR if ray contribution is low
			vec3 localSkyLightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
			float noise = blueNoise(gl_FragCoord.xy, frameCounter);

			RayIterator ray;
			ray.iterations = PHOTONICS_REFLECT_STEPS;
			ray_iter_set_position(ray, localPos + rt_camera_position);
			ray_iter_set_direction(ray, reflectLocalDir);
			ray_iter_offset_position(ray, 0.02 * geoLocalNormal);

			vec3 radiance = vec3(0.0);
			vec3 transmittance = vec3(1.0);
			vec3 localPosLast = localPos;

			int bounce;
			bool bounce_hit = true;
			for (bounce = 0; bounce < PHOTONICS_REFLECT_BOUNCES; bounce++) {
				RayResult hit = ray_iter_next(ray);
				bounce_hit = ray_result_is_hit(hit);
				if (!bounce_hit || !ray_iter_is_in_bounds(ray)) break;

				vec3 hit_position = ray_result_position(hit);

				VoxelData voxel_data = ray_result_voxel_data(hit);
				vec3 hit_albedo = voxel_data_albedo(voxel_data).rgb;
//				hit_albedo = toLinear(hit_albedo);

				vec3 hitLocalPos = hit_position - rt_camera_position;
				vec3 hit_localNormal = ray_result_normal(hit);
//				float hitViewDist = length(hitLocalPos);

				reflectDist += distance(localPosLast, hitLocalPos);

				float hit_sky = ray_result_skylight(hit) / 15.0;
				vec2 hit_lmcoord = vec2(0.0, hit_sky);

				// shadows
				vec3 projectedShadowPosition = mul3(shadowModelView, hitLocalPos);
				projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

				// apply distortion
				float distortFactor = calcDistort(projectedShadowPosition.xy);
				projectedShadowPosition.xy *= distortFactor;

				vec3 shadow = vec3(1.0);
				float hit_sky_NoLm = max(dot(hit_localNormal, localSkyLightDir), 0.0);

				// do shadows only if on shadow map
				if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0) {
					vec3 filtered = vec3(1.412, 1.0, 0.0);

					float rdMul = filtered.x * distortFactor * shadow_d0 * shadow_k / shadowMapResolution;
					const float threshMul = max(2048.0 / shadowMapResolution * shadowDistance/128.0, 0.95);
					float distortThresh = (sqrt(1.0-hit_sky_NoLm*hit_sky_NoLm)/hit_sky_NoLm+0.7)/distortFactor;

					projectedShadowPosition = projectedShadowPosition * vec3(0.5, 0.5, 0.5/6.0) + vec3(0.5, 0.5, 0.5);

					float diffthresh = distortThresh/6000.0 * threshMul;

					const vec2 offsetS = vec2(0.0); // TODO: remove
					float bias = 1.0 + noise * rdMul/SHADOW_FILTER_SAMPLE_COUNT * shadowMapResolution;
					vec3 samplePos = vec3(projectedShadowPosition + vec3(rdMul * offsetS, -diffthresh * bias));

					shadow = vec3(texture(shadowtex0HW, samplePos));

					// TODO: shadow color
				}

				#ifdef SHADOW_CLOUDS
					shadow *= SampleCloudShadow(hitLocalPos, localSkyLightDir);
				#endif

				vec3 hit_color = vec3(0.0);

				#if MAT_FORMAT != 0 || defined(MC_TEXTURE_FORMAT_LAB_PBR)
					vec4 hit_specularData = voxel_data_specular(voxel_data);

					float hit_roughness = square(1.0 - hit_specularData.r);
					float hit_f0 = hit_specularData.g;
					if (hit_f0 < EPSILON) hit_f0 = 0.04;

					float hit_sss = mat_sss(hit_specularData.b);

					// apply emission
					float hit_emission = mat_emission(hit_specularData);
					hit_color += pow(hit_emission, Emission_Curve) * 3.0 * MAT_EMISSION_SCALE;
				#else
					float hit_roughness = 1.0;
					float hit_f0 = 0.04;
					float hit_sss = 0.0;
				#endif

				// block and sky lighting
				vec3 ambientCoefs = hit_localNormal / dot(abs(hit_localNormal), vec3(1.0));
				vec3 ambientLight = vIn.ambientUp * mix(saturate(ambientCoefs.y), 1.0/6.0, hit_sss);
				ambientLight += vIn.ambientDown * mix(saturate(-ambientCoefs.y), 1.0/6.0, hit_sss);
				ambientLight += vIn.ambientRight * mix(saturate(ambientCoefs.x), 1.0/6.0, hit_sss);
				ambientLight += vIn.ambientLeft * mix(saturate(-ambientCoefs.x), 1.0/6.0, hit_sss);
				ambientLight += vIn.ambientB * mix(saturate(ambientCoefs.z), 1.0/6.0, hit_sss);
				ambientLight += vIn.ambientF * mix(saturate(-ambientCoefs.z), 1.0/6.0, hit_sss);

				vec3 custom_lightmap = texture(colortex4, (hit_lmcoord * 15.0 + 0.5 + vec2(0.0, 19.0)) * texelSize).rgb / 150.0 * 8.0/3.0;
				ambientLight = ambientLight * custom_lightmap.x + custom_lightmap.z * vec3(0.9, 1.0, 1.5) + custom_lightmap.y * TorchColor;
				hit_color += (hit_sky_NoLm * shadow)/PI * vIn.lightCol.rgb * 8.0/3.0 / 150.0 + ambientLight;

				// TODO: fresnel, probably wrong
				float hit_NoVm = max(dot(hit_localNormal, -reflectLocalDir), 0.0);
				float hit_F = schlick(hit_NoVm, hit_f0, 1.0);


				hit_color *= hit_albedo;

				radiance += hit_color * transmittance;

//				transmittance *= hit_NoLm * hit_F;
				transmittance *= hit_F;

				// check if the f0 is within the metal ranges, then tint by albedo if it's true.
				transmittance *= mix(vec3(1.0), hit_albedo, hit_f0 > 229.5/255.0);

				#ifndef REFLECTION_ROUGH
					transmittance *= 1.0 - sqrt(hit_roughness);
				#endif

				vec3 hit_reflectLocalDir = normalize(reflect(reflectLocalDir, hit_localNormal));
				localPosLast = hitLocalPos;

				reflectLocalDir = hit_reflectLocalDir;
				ray_iter_set_direction(ray, reflectLocalDir);
			}

			if (!bounce_hit) {
				// sample sky
				vec3 sky_color = skyCloudsFromTex(reflectLocalDir, colortex4).rgb / 150.0;
				sky_color = clamp(sky_color * 8.0/3.0, 0.0, 65000.0);
				radiance += sky_color * transmittance;

				reflectDist = farPlane;
			}

			reflect_color = radiance;
		}

		#ifndef REFLECTION_ACCUMULATE
			// check if the f0 is within the metal ranges, then tint by albedo if it's true.
			reflect_color *= mix(vec3(1.0), albedo, f0 > 229.5/255.0);
		#endif

		// apply all reflections to the lighting
		reflect_color *= F; //luma(F);

		#ifndef REFLECTION_ROUGH
			reflect_color *= 1.0 - sqrt(roughness);
		#endif
	}

	vec4 final_color;

	#ifdef REFLECTION_ACCUMULATE
//		float alpha = 0.998;// mix(0.0, 0.998, pow(roughness, 0.1));

		vec3 screenPos2 = vec3(texcoord / RENDER_SCALE, z);
		vec2 tex_last = reproject(screenPos2, reflectDist);
		vec4 src = textureLod(TEX_REFLECT_HISTORY, tex_last * RENDER_SCALE, 0);

		uint counter;
		float src_roughness;
		unpack_8bit_float_and_uint(src.a, src_roughness, counter);

		if (!all(equal(saturate(tex_last), tex_last))) counter = 0;

//		float diff = abs(src_roughness - roughness);
//		if (diff > 0.5) counter = 0;

		float alpha = 1.0 - 1.0 / (1 + counter);

//		alpha *= max(1.0 - 8.0*diff, 0.0);

		reflect_color = mix(reflect_color, src.rgb, alpha);

		int counter_max = int(ceil(sqrt(roughness) * 120.0));
		counter = min(counter+1, counter_max);

		final_color.rgb = reflect_color;
		final_color.a = pack_8bit_float_and_uint(roughness, counter);
	#else
		final_color.rgb = reflect_color;
		final_color.a = 1.0;
	#endif

	#if defined(REFLECTION_ROUGH) && (defined(REFLECTION_ACCUMULATE) || defined(REFLECTION_NEIGHBOR_CLAMP))
		final_color.rgb = clamp(final_color.rgb, 0.000001, 65000.0);

		outColor13 = final_color;
	#else
		ivec2 uv = ivec2(gl_FragCoord.xy);
		vec3 dest_color = texelFetch(colortex3, uv, 0).rgb;

		outColor3.rgb = clamp(dest_color + final_color.rgb, 0.000001, 65000.0);
		outColor3.a = 1.0;
	#endif
}
