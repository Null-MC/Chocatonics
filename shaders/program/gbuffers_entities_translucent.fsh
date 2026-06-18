#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#define TEX_SKY_LUT gaux1
#define TEX_FINAL_PREV gaux2


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;

	#ifdef MC_NORMAL_MAP
		vec4 tangent;
	#endif
} vIn;

uniform sampler2D gtexture;
uniform sampler2D noisetex;
uniform sampler2D texBlueNoise;
uniform sampler2DShadow shadowtex0HW;
uniform sampler2D TEX_SKY_LUT;
uniform sampler2D gaux2;
uniform sampler2D texDepthQ;
uniform sampler2D depthtex1;

#ifdef MC_NORMAL_MAP
	uniform sampler2D normals;
#endif

#ifdef MAT_SPECULAR_ENABLED
	uniform sampler2D specular;
#endif

uniform vec4 lightCol;
uniform vec3 sunVec;
uniform float alphaTestRef;
uniform float frameTimeCounter;
uniform float lightSign;
uniform float near;
uniform float far;
uniform float wetness;
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
uniform vec4 entityColor;
uniform int isEyeInWater;
uniform int frameCounter;
uniform int framemod8;

#include "/lib/r2.glsl"
#include "/lib/ign.glsl"
#include "/lib/ggx.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/material.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/projections.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/shadowSampling.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/clouds.glsl"
#include "/lib/stars.glsl"

#ifdef MC_NORMAL_MAP
	#include "/lib/normal_map.glsl"
#endif

#ifdef MAT_SPECULAR_ENABLED
	const vec2 v_taa_offset = vec2(0.0);
	#include "/lib/specular.glsl"
#endif


/* RENDERTARGETS: 2,7 */
layout(location = 0) out vec4 outColor2;
layout(location = 1) out vec4 outColor7;

void main() {
	if (!all(lessThan(gl_FragCoord.xy * texelSize.xy, RENDER_SCALE_2))) return;

	vec2 taa_offset = taa_offsets[framemod8];

	vec3 fragC = gl_FragCoord.xyz * vec3(texelSize, 1.0);
	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz * vec3(texelSize / RENDER_SCALE, 1.0) - vec3(taa_offset * texelSize * 0.5, 0.0));

	outColor2 = texture(gtexture, vIn.lmtexcoord.xy, Texture_MipMap_Bias) * vIn.color;
	if (outColor2.a < alphaTestRef) discard;

	outColor2.rgb = mix(outColor2.rgb, entityColor.rgb, entityColor.a);

	vec3 albedo = InputTransform(outColor2.rgb);

	#ifdef MAT_SPECULAR_ENABLED
		vec4 specularData = texture(specular, vIn.lmtexcoord.xy);
		float roughness = mat_roughness(specularData.r);
		float emissive = mat_emission(specularData);
		float f0 = specularData.g;

		if (f0 < EPSILON) f0 = 0.04;
	#else
		float roughness = 1.0;
		float emissive = 0.0;
		float f0 = 0.04;
	#endif

	vec3 p3 = mul3(gbufferModelViewInverse, fragpos);

	vec3 np3 = normalize(p3);

	vec3 normal = vIn.normalMat.xyz;

	#ifdef MC_NORMAL_MAP
		vec3 binormal = normalize(cross(vIn.tangent.xyz, normal) * vIn.tangent.w);

		mat3 tbnMatrix = mat3(
			vIn.tangent.x, binormal.x, normal.x,
			vIn.tangent.y, binormal.y, normal.y,
			vIn.tangent.z, binormal.z, normal.z);

		vec3 tex_normal = mat_normal(texture(normals, vIn.lmtexcoord.xy).rgb);
		normal = applyBump(tbnMatrix, tex_normal);
	#endif

	float NdotL = lightSign * dot(normal, sunVec);
	float NdotU = dot(upVec, normal);
	float diffuseSun = saturate(NdotL);

	vec3 direct = texelFetch(TEX_SKY_LUT, ivec2(6, 37), 0).rgb / PI;

	float noise = blueNoise(gl_FragCoord.xy, frameCounter);
	float shading = 1.0;

	// compute shadows only if not backface
	if (diffuseSun > 0.001) {
		vec3 projectedShadowPosition = mul3(shadowModelView, p3);
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		// apply distortion
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;

		// do shadows only if on shadow map
		if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution) {
			const float threshMul = max(2048.0/shadowMapResolution * shadowDistance/128.0, 0.95);
			float distortThresh = (sqrt(1.0 - diffuseSun * diffuseSun) / diffuseSun + 0.7) / distortFactor;
			float diffthresh = distortThresh/6000.0 * threshMul;

			projectedShadowPosition = projectedShadowPosition * vec3(0.5, 0.5, 0.5/6.0) + vec3(0.5, 0.5, 0.5);

			shading = 0.0;
			float rdMul = 4.0 / shadowMapResolution;

			for (int i = 0; i < 9; i++) {
				vec2 offsetS = tapLocation_Shadow(i, 9, 2.0, noise);
				float weight = 1.0 + (i + noise) * rdMul/9.0 * shadowMapResolution;
				shading += texture(shadowtex0HW, vec3(projectedShadowPosition + vec3(rdMul*offsetS, -diffthresh*weight))) / 9.0;
			}

			direct *= shading;
		}
	}

	direct *= diffuseSun * vIn.lmtexcoord.w;

	vec3 diffuseLight = direct + texture(TEX_SKY_LUT, (vIn.lmtexcoord.zw * 15.0 + 0.5) * texelSize).rgb;

	diffuseLight /= 150.0;
	diffuseLight += pow(emissive, Emission_Curve) * 3.0 * MAT_EMISSION_SCALE;

	vec3 color = diffuseLight * albedo * 8.0/3.0;

	float normalDotEye = dot(normal, normalize(fragpos));
	float fresnel = pow(clamp(1.0 + normalDotEye, 0.0, 1.0), 5.0);
	fresnel = mix(f0, 1.0, fresnel);

	// premultiply alpha
	outColor2.rgb = color * outColor2.a;

	#ifdef MAT_SPECULAR_ENABLED
		const bool hand = false;

		vec2 noise2 = blueNoise(texBlueNoise, gl_FragCoord.xy).rg;
		vec3 lightCol2 = texelFetch(TEX_SKY_LUT, ivec2(6, 37), 0).rgb / PI;
		vec3 localNormal = mat3(gbufferModelViewInverse) * normal;

		float lightCol_a = float(sunElevation > 1.e-5) * 2.0 - 1.0;
		vec3 localSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
		vec3 WsunVec = lightCol_a * localSunDir;

		f0 = 0.02;
		roughness = 0.02;
		MaterialReflections(outColor2.rgb, roughness, vec3(f0), albedo, WsunVec, lightCol2, shading * diffuseSun, vIn.lmtexcoord.w, localNormal, np3, fragpos, vec3(noise2, noise), hand);
	#endif

	outColor2.rgb *= 0.1;
	outColor7 = vec4(albedo, 0.0);
}
