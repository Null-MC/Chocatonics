#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#define RENDER_VOXY
#define RENDER_GBUFFERS
#define TEX_SKY_LUT gaux1
#define TEX_FINAL_PREV colortex5
#define TEX_DEPTH_REFLECT texVoxyDepthOpaque


// TODO: UNDEFINED!
const float skyIntensity = 0.0;
const float skyIntensityNight = 0.0;
const vec3 nsunColor = vec3(0.0);

uniform mat4 gbufferProjectionInverse;

#include "/lib/blocks.glsl"

#include "/lib/r2.glsl"
#include "/lib/ign.glsl"
#include "/lib/ggx.glsl"
#include "/lib/fresnel.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/shadowSampling.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/clouds.glsl"
#include "/lib/stars.glsl"

#include "/lib/projections.glsl"
#include "/lib/lod_projections.glsl"


vec3 toScreenSpace_vx(const in vec3 screenPos) {
	return screenToViewSpace(vxProjInv, screenPos);
}

//vec3 toClipSpace3_vx(const in vec3 viewSpacePosition) {
//	return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
//}

#ifdef MAT_SPECULAR_ENABLED
	const vec2 v_taa_offset = vec2(0.0);
	#include "/lib/specular.glsl"
#endif


vec3 TangentToWorld(vec3 N, vec3 H) {
//    vec3 UpVector = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(-1.0, 0.0, 0.0);
//    vec3 T = normalize(cross(UpVector, N));
//    vec3 B = cross(N, T);
	vec3 UpVector = abs(N.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, -1.0);
	vec3 T = normalize(cross(UpVector, N));
	vec3 B = cross(T, N);

    return vec3((T * H.x) + (B * H.y) + (N * H.z));
}


/* RENDERTARGETS: 2,7 */
layout(location = 0) out vec4 outColor2;
layout(location = 1) out vec4 outColor7;

void voxy_emitFragment(VoxyFragmentParameters parameters) {
	if (!all(lessThan(gl_FragCoord.xy * texelSize.xy, RENDER_SCALE_2))) return;

	float iswater = 0.0;
	if (parameters.customId == BLOCK_REFLECTIVE) iswater = 0.01;
	if (parameters.customId == BLOCK_ICE) iswater = 0.50;
	if (parameters.customId == BLOCK_WATER) iswater = 1.00;

	vec3 screenPos = gl_FragCoord.xyz;
	screenPos.xy = screenPos.xy * texelSize / RENDER_SCALE - taa_offsets[framemod8] * texelSize * 0.5;
	vec3 viewPos = toScreenSpace_vx(screenPos);

	outColor2 = parameters.sampledColour * parameters.tinting;
	vec3 albedo = InputTransform(outColor2.rgb);

	float roughness = 1.0;
	float emissive = 0.0;
	float f0 = 0.04;

	if (iswater > 0.0) {
//		f0 = 0.02; //iswater > 0.1 ? 0.02 : 0.05 * (1.0 - outColor2.a);
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

	// TODO: normalize?
	vec2 lmcoord = parameters.lightMap;

	vec3 localNormal = vec3(
		uint((parameters.face >> 1) == 2),
		uint((parameters.face >> 1) == 0),
		uint((parameters.face >> 1) == 1)
	) * (float(int(parameters.face) & 1) * 2.0 - 1.0);

	vec3 localPos = mul3(vxModelViewInv, viewPos);

	if (iswater > 0.4) {
		float bumpmult = 1.0;
		if (iswater > 0.9) bumpmult = 1.0;

		float parallaxMult = bumpmult;

		vec3 posxz = localPos + cameraPosition;
		posxz.xz -= posxz.y;// - (2.0/16.0);

		if (iswater < 0.9) posxz.xz *= 3.0;

		vec3 bump = normalize(getWaveHeight(posxz.xz, iswater));

		bump = bump * vec3(bumpmult) + vec3(0.0, 0.0, 1.0 - bumpmult);

		localNormal = TangentToWorld(localNormal, normalize(bump));
	}

	vec3 viewNormal = mat3(vxModelView) * localNormal;

	float NdotL = lightSign * dot(viewNormal, sunVec);
	float NdotU = dot(upVec, viewNormal);
	float diffuseSun = saturate(NdotL);

	float noise = blueNoise(gl_FragCoord.xy, frameCounter);

	vec3 direct = texelFetch(gaux1, ivec2(6, 37), 0).rgb / PI;
	float shading = 1.0;

	// compute shadows only if not backface
	if (diffuseSun > 0.001) {
		vec3 projectedShadowPosition = worldToShadowSpaceProjected(localPos);

		// apply distortion
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;

		// do shadows only if on shadow map
		if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution) {
			const float threshMul = max(2048.0/shadowMapResolution * shadowDistance/128.0, 0.95);
			float distortThresh = (sqrt(1.0 - square(diffuseSun)) / diffuseSun + 0.7) / distortFactor;
			float diffthresh = distortThresh/6000.0 * threshMul;

			projectedShadowPosition = projectedShadowPosition * vec3(0.5, 0.5, 0.5/6.0) + vec3(0.5, 0.5, 0.5);

			shading = 0.0;
//			float noise = blueNoise(gl_FragCoord.xy, frameCounter);
			float rdMul = 4.0 / shadowMapResolution;

			for (int i = 0; i < 9; i++) {
				vec2 offsetS = tapLocation_Shadow(i, 9, 2.0, noise);
				float weight = 1.0 + (i + noise) * rdMul/9.0 * shadowMapResolution;
				shading += texture(shadowtex0HW, vec3(projectedShadowPosition + vec3(rdMul*offsetS, -diffthresh*weight))) / 9.0;
			}

			direct *= shading;
		}
	}

	direct *= (iswater > 0.9 ? 0.2 : 1.0) * diffuseSun * lmcoord.y;

	vec3 diffuseLight = direct + texture(gaux1, (lmcoord * 15.0 + 0.5) * texelSize).rgb;
	vec3 color = diffuseLight * albedo * 8.0/3.0 / 150.0;

	vec3 localViewDir = normalize(localPos);
	float F = schlick(dot(localNormal, -localViewDir), f0, 1.0);

	// premultiply alpha
	outColor2.rgb = color * outColor2.a;
	outColor2.a = max(outColor2.a, F);

	#ifdef MAT_SPECULAR_ENABLED
		const bool hand = false;

		vec2 noise2 = blueNoise(texBlueNoise, gl_FragCoord.xy).rg;
		vec3 lightCol2 = texelFetch(TEX_SKY_LUT, ivec2(6, 37), 0).rgb;// / PI;

		float lightCol_a = float(sunElevation > 1.e-5) * 2.0 - 1.0;
		vec3 localSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
		vec3 WsunVec = lightCol_a * localSunDir;

		MaterialReflections(outColor2.rgb, roughness, f0, albedo, WsunVec, lightCol2, vec3(shading * diffuseSun), lmcoord.y, localNormal, localViewDir, viewPos, vec3(noise2, noise), hand);
	#endif

	outColor2.rgb = clamp(outColor2.rgb * 0.1, 0.0, 65100.0);
	outColor7 = vec4(albedo, iswater);
}
