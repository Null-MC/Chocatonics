#version 430 compatibility

// Photonics world-space reflections

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
////uniform mat4 gbufferPreviousProjection;
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
#include "/lib/sky_gradient.glsl"
//#include "/lib/volumetricClouds.glsl"

#include "/photonics/tracing.glsl"
#include "/photonics/trace_ray.glsl"


#ifdef REFLECTION_ROUGH
	/* RENDERTARGETS: 13 */
	layout(location = 0) out vec4 outColor13;
#else
	/* RENDERTARGETS: 3 */
	layout(location = 0) out vec4 outColor3;
#endif

void main() {
	vec2 texcoord = gl_FragCoord.xy * texelSize;
	float z = texture(depthtex0, texcoord).x;

	vec4 reflect_color = vec4(0.0);

	if (z < 1.0) {
		vec3 fragpos = toScreenSpace(vec3(texcoord / RENDER_SCALE - vIn.TAA_Offset * texelSize * 0.5, z));
		vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
		vec3 np3 = normVec(p3);

		p3 += gbufferModelViewInverse[3].xyz;

		vec4 color = texture(TEX_GB_COLOR, texcoord);
		vec3 albedo = toLinear(color.rgb);

		vec4 normalData = texture(TEX_GB_NORMAL, texcoord);
		vec3 geoViewNormal = mat3(gbufferModelViewInverse) * OctDecode(normalData.xy);
		vec3 tex_normal = OctDecode(normalData.zw);

		vec3 geoLocalNormal = mat3(gbufferModelViewInverse) * geoViewNormal;
		vec3 normal = mat3(gbufferModelViewInverse) * tex_normal;

		vec4 specularData = texture(TEX_GB_SPECULAR, texcoord);

		vec4 worldData = texture(TEX_GB_WORLD, texcoord);
		vec2 lightmap = worldData.xy;
		float mat = worldData.w;

		bool hand = abs(mat-0.75) < 0.01;

		#ifdef MC_TEXTURE_FORMAT_LAB_PBR
			float roughness = square(1.0 - specularData.r);
			float f0 = specularData.g;
			if (f0 < EPSILON) f0 = 0.04;
		#else
			float roughness = 1.0;
			float f0 = 0.04;
		#endif

		mat3 basis = CoordBase(normal);
		vec3 normSpaceView = -np3 * basis;

		// roughness stuff
		#ifdef REFLECTION_ROUGH
			vec2 noise2 = blueNoise(texBlueNoise, gl_FragCoord.xy).rg;

			int seed = (frameCounter % 40000) * 2 + frameCounter + 1;
			vec2  ij = fract(R2_samples(seed) + noise2);

			vec3 H = sampleGGXVNDF(normSpaceView, vec2(roughness), ij.x, ij.y, hand);

			if (hand) H = normalize(vec3(0.0, 0.0, 1.0));
		#else
//			vec3 H = normalize(vec3(0.0, 0.0, 1.0));
			const vec3 H = vec3(0.0, 0.0, 1.0);
		#endif

		vec3 Ln = reflect(-normSpaceView, clamp(H, -1.0, 1.0));
		vec3 reflectLocalDir = basis * Ln;

		// fresnel stuff
		float fresnel = pow5(saturate(1.0 + dot(-Ln, H)));
		float F = f0 + (1.0 - f0) * fresnel;
//		float F = schlick(dot(-Ln, H), f0, 1.0);
//		vec3 rayContrib = F;

		float NdotV = saturate(dot(np3, normalize(normal)) * 5000.0);

		bool hasReflections = (f0 * (1.0 - roughness * Roughness_Threshold)) > 0.02;

//		bool is_hit = false;
		if (hasReflections && NdotV < 0.00001) { // Skip SSR if ray contribution is low
			vec3 localSkyLightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
			float noise = blueNoise(gl_FragCoord.xy, frameCounter);

			RayIterator ray;
			ray.iterations = PHOTONICS_REFLECT_STEPS;
			ray_iter_set_position(ray, p3 + rt_camera_position);
			ray_iter_set_direction(ray, reflectLocalDir);
			ray_iter_offset_position(ray, 0.004 * geoLocalNormal);

			vec3 radiance = vec3(0.0);
			vec3 transmittance = vec3(1.0);

			bool bounce_hit = true;
			for (int bounce = 0; bounce < PHOTONICS_REFLECT_BOUNCES; bounce++) {
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

//				reflectDist += distance(localPos, hitLocalPos);

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
//				float hit_fresnel = pow5(saturate(1.0 + dot(-Ln, H)));
//				float hit_F = hit_f0 + (1.0 - hit_f0) * hit_fresnel;
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

				reflectLocalDir = hit_reflectLocalDir;
				ray_iter_set_direction(ray, reflectLocalDir);
			}

			if (!bounce_hit) {
				// sample sky
				vec3 sky_color = skyCloudsFromTex(reflectLocalDir, colortex4).rgb / 150.0;
				sky_color = clamp(sky_color * 8.0/3.0, 0.0, 65000.0);
				radiance += sky_color * transmittance;
			}

			reflect_color.rgb = radiance;
		}

		// check if the f0 is within the metal ranges, then tint by albedo if it's true.
		reflect_color.rgb *= mix(vec3(1.0), albedo, f0 > 229.5/255.0);

		// apply all reflections to the lighting
		reflect_color.rgb *= F; //luma(F);

		#ifndef REFLECTION_ROUGH
			reflect_color.rgb *= 1.0 - sqrt(roughness);
		#endif

		reflect_color.a = 1.0;
	}

	#ifdef REFLECTION_ROUGH
		outColor13 = clamp(reflect_color, 0.000001, 65000.0);
	#else
		ivec2 uv = ivec2(gl_FragCoord.xy);
		vec3 dest_color = texelFetch(colortex3, uv, 0).rgb;

		dest_color += reflect_color.rgb;

		outColor3 = vec4(clamp(dest_color, 0.000001, 65000.0), 1.0);
	#endif
}
