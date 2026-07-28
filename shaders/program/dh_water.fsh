#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#define RENDER_GBUFFERS
#define TEX_SKY_LUT gaux1
#define TEX_FINAL_PREV gaux2

#ifdef LOD_ENABLED
	#define TEX_DEPTH_REFLECT texVoxyDepthOpaque
#else
	#define TEX_DEPTH_REFLECT depthtex1
#endif


in VertexData {
	vec4 color;
	vec4 normalMat;
	vec2 lmcoord;
	float viewDist;
} vIn;

uniform sampler2D noisetex;
uniform sampler2D texBlueNoise;
uniform sampler2DShadow shadowtex0HW;
uniform sampler2D TEX_SKY_LUT;
uniform sampler2D gaux2;
uniform sampler2D texWave;
uniform sampler2D TEX_DEPTH_REFLECT;

#ifdef REFLECTION_QUARTER_RES_DEPTH
	uniform sampler2D texDepthQ;
#endif

#ifdef LIGHTING_COLORED
	uniform usampler3D texVoxels;
	uniform sampler3D texFloodFill;
	uniform sampler2D texBlockLight;
	uniform usampler2D texBlockLightMask;
#endif

uniform vec4 lightCol;
uniform vec3 sunVec;
uniform int heldItemId;
uniform int heldItemId2;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform float frameTimeCounter;
uniform float waveScale;
uniform float lightSign;
uniform float near;
uniform float far;
//uniform float wetness;
uniform float moonIntensity;
uniform float sunIntensity;
uniform vec3 sunColor;
uniform vec3 nsunColor;
uniform vec3 upVec;
uniform float sunElevation;
uniform float fogAmount;
uniform vec2 texelSize;
uniform float rainStrength;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;
uniform vec3 relativeEyePosition;
uniform int isEyeInWater;
uniform int frameCounter;
uniform int framemod8;

uniform mat4 dhProjectionInverse;
uniform float dhFarPlane;

#include "/lib/r2.glsl"
#include "/lib/ign.glsl"
#include "/lib/ggx.glsl"
#include "/lib/fresnel.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/projections.glsl"
#include "/lib/lod_projections.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/shadowSampling.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/clouds.glsl"
#include "/lib/stars.glsl"

#ifdef LIGHTING_COLORED
	#include "/lib/voxel.glsl"
	#include "/lib/blockLights.glsl"
	#include "/lib/blockLightMask.glsl"
	#include "/lib/floodfill.glsl"
	#include "/lib/floodfillMasked.glsl"
#endif

#include "/lib/handLight.glsl"

#ifdef PHOTONICS_REFLECT_ENABLED
	#include "/photonics/uniforms.glsl"
	#include "/photonics/tracing.glsl"
	#include "/photonics/trace_ray.glsl"
#endif

#ifdef CLOUDS_SHADOWS
	#include "/lib/volumetricClouds.glsl"
#endif

//#ifdef MAT_SPECULAR_ENABLED
	const vec2 v_taa_offset = vec2(0.0);
	#include "/lib/specular.glsl"
//#endif


vec3 toScreenSpace_dh(const in vec3 screenPos) {
	return screenToViewSpace(dhProjectionInverse, screenPos);
}

float cdist(vec2 coord) {
	return max(abs(coord.s - 0.5), abs(coord.t - 0.5)) * 2.0;
}

vec3 TangentToWorld(vec3 N, vec3 H) {
    vec3 UpVector = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(UpVector, N));
    vec3 B = cross(N, T);

    return vec3((T * H.x) + (B * H.y) + (N * H.z));
}


/* RENDERTARGETS: 2,7 */
layout(location = 0) out vec4 outColor2;
layout(location = 1) out vec4 outColor7;

void main() {
	if (!all(lessThan(gl_FragCoord.xy * texelSize.xy, RENDER_SCALE_2))) return;

	if (vIn.viewDist < 0.85 * far) discard;

	vec2 taa_offset = taa_offsets[framemod8];
	float iswater = vIn.normalMat.w;

	vec3 viewPos = toScreenSpace_dh(gl_FragCoord.xyz * vec3(texelSize / RENDER_SCALE, 1.0) - vec3(taa_offset * texelSize * 0.5, 0.0));

	outColor2 = vIn.color;

	vec3 albedo = InputTransform(outColor2.rgb);

	float roughness = 1.0;
	float emissive = 0.0;
	float f0 = 0.04;

	if (iswater > 0.0) {
//		f0 = 0.02;//iswater > 0.1 ? 0.02 : 0.05 * (1.0 - outColor2.a);
//		roughness = 0.02;
	}

	if (iswater > 0.4) {
		f0 = 0.018;
		albedo = vec3(0.42, 0.6, 0.7);
		outColor2 = vec4(albedo, 0.7);
		roughness = 0.1;
	}

	if (iswater > 0.9) {
		f0 = 0.020;
		outColor2 = vec4(0.0);
		roughness = 0.0;
	}

	vec3 geoViewNormal = vIn.normalMat.xyz;
	vec3 texViewNormal = geoViewNormal;

	vec3 localPos = toWorldSpace(viewPos);

	if (iswater > 0.4) {
		float bumpmult = 1.0;
		if (iswater > 0.9) bumpmult = 1.0;

		vec3 posxz = localPos + cameraPosition;
		posxz.xz -= posxz.y;

		if (iswater < 0.9) posxz.xz *= 3.0;

		vec3 bump = normalize(getWaveHeight(posxz.xz, iswater));

		bump = bump * vec3(bumpmult) + vec3(0.0, 0.0, 1.0 - bumpmult);

		vec3 geoLocalNormal = mat3(gbufferModelViewInverse) * geoViewNormal;
		texViewNormal = TangentToWorld(geoLocalNormal, bump);
		texViewNormal = mat3(gbufferModelView) * texViewNormal;
	}

	vec3 texLocalNormal = mat3(gbufferModelViewInverse) * texViewNormal;

	float NdotL = lightSign * dot(texViewNormal, sunVec);
	float NdotU = dot(upVec, texViewNormal);
	float diffuseSun = saturate(NdotL);

	vec3 direct = texelFetch(TEX_SKY_LUT, ivec2(6, 37), 0).rgb / PI;

	float noise = blueNoise(gl_FragCoord.xy, frameCounter);
	float shading = 1.0;

	// compute shadows only if not backface
	if (diffuseSun > 0.001) {
		vec3 projectedShadowPosition = worldToShadowSpaceProjected(localPos);

		// apply distortion
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;

		// do shadows only if on shadow map
		if (IsInShadowMap(projectedShadowPosition)) {
			const float threshMul = max(2048.0/shadowMapResolution * shadowDistance/128.0, 0.95);
			float distortThresh = (sqrt(1.0 - square(diffuseSun)) / diffuseSun + 0.7) / distortFactor;
			float diffthresh = distortThresh/6000.0 * threshMul;

			projectedShadowPosition = projectedShadowPosition * vec3(0.5, 0.5, 0.5/6.0) + vec3(0.5, 0.5, 0.5);

			shading = 0.0;
//			float noise = blueNoise(gl_FragCoord.xy, frameCounter);
			float rdMul = 4.0 / shadowMapResolution;

			for (int i = 0; i < SHADOW_FILTER_SAMPLE_COUNT; i++) {
				vec2 offsetS = tapLocation_Shadow(i, SHADOW_FILTER_SAMPLE_COUNT, 2.0, noise);
				float bias = 1.0 + (i + noise) * rdMul/SHADOW_FILTER_SAMPLE_COUNT * shadowMapResolution;
				shading += texture(shadowtex0HW, vec3(projectedShadowPosition + vec3(rdMul*offsetS, -diffthresh*bias)));
			}

			direct *= shading / SHADOW_FILTER_SAMPLE_COUNT;
		}

		#ifdef CLOUDS_SHADOWS
			vec3 world_pos = localPos + cameraPosition;
			vec3 localSkyLightDir = mat3(gbufferModelViewInverse) * sunVec;

			const int rayMarchSteps = 6;
			float cloudShadow = 0.0;

			for (int i = 0; i < rayMarchSteps; i++) {
				vec3 cloudPos = world_pos + localSkyLightDir / abs(localSkyLightDir.y) * (1500 + (noise+i) / rayMarchSteps*1700 - world_pos.y);
				cloudShadow += getCloudDensity(cloudPos, 0);
			}

			shading *= mix(1.0, exp(-cloudShadow * cloudDensity * 1700/rayMarchSteps), mix(CLOUDS_SHADOWS_STRENGTH, 1.0, rainStrength));
		#endif
	}

	vec2 lmcoord = vIn.lmcoord;

	#ifdef LIGHTING_COLORED
		vec3 geoLocalNormal = mat3(gbufferModelViewInverse) * geoViewNormal;

		vec3 voxelPos = GetVoxelPosition(localPos);
		vec3 samplePos = GetFloodFillSamplePos(voxelPos, geoLocalNormal, texLocalNormal);

		vec3 floodfill_light = vec3(0.0);
		if (IsInVoxelBounds(samplePos)) {
			lmcoord.x = 0.0;
			floodfill_light = SampleFloodFillMasked(samplePos, frameCounter);
		}
	#else
		float maxLit = SampleHandLight(localPos, texLocalNormal);
		lmcoord.x = max(lmcoord.x, maxLit);
	#endif

	direct *= (iswater > 0.9 ? 0.2 : 1.0) * diffuseSun * lmcoord.y;

	vec3 color = direct + texture(TEX_SKY_LUT, (lmcoord * 15.0 + 0.5) * texelSize).rgb;
	color *= 8.0/3.0 / 150.0;

	#ifdef LIGHTING_COLORED
		color += floodfill_light;

		#if !defined(PHOTONICS_HAND_LIGHT_ENABLED)
			color += SampleHandLight(localPos, texLocalNormal, heldItemId, heldBlockLightValue);
			color += SampleHandLight(localPos, texLocalNormal, heldItemId2, heldBlockLightValue2);
		#endif
	#endif

	color *= albedo;

	vec3 viewDir = normalize(viewPos);
	float F = schlick(dot(texViewNormal, -viewDir), f0, 1.0);

	// premultiply alpha
	outColor2.rgb = color * outColor2.a;
	outColor2.a = max(outColor2.a, F);

	const bool hand = false;

	vec2 noise2 = blueNoise(texBlueNoise, gl_FragCoord.xy).rg;
	vec3 lightCol2 = texelFetch(TEX_SKY_LUT, ivec2(6, 37), 0).rgb;// / PI;

	vec3 localViewDir = mat3(gbufferModelViewInverse) * viewDir;

	float lightCol_a = float(sunElevation > 1.e-5) * 2.0 - 1.0;
	vec3 localSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	vec3 WsunVec = lightCol_a * localSunDir;

	MaterialReflections(outColor2.rgb, roughness, f0, albedo, WsunVec, lightCol2, vec3(shading * diffuseSun), lmcoord.y, texLocalNormal, localViewDir, viewPos, vec3(noise2, noise), hand);

	outColor2.rgb = clamp(outColor2.rgb * 0.1, 0.0, 65100.0);
	outColor7 = vec4(albedo, iswater);
}
