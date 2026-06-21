#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#define RENDER_GBUFFERS
#define TEX_SKY_LUT gaux1
#define TEX_FINAL_PREV gaux2


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;
	vec3 binormal;
	vec3 tangent;
	vec3 viewVector;
} vIn;

uniform sampler2D gtexture;
uniform sampler2D noisetex;
uniform sampler2D texBlueNoise;
uniform sampler2DShadow shadowtex0HW;
uniform sampler2D TEX_SKY_LUT;
uniform sampler2D gaux2;
uniform sampler2D texWave;
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
#include "/lib/waterBump.glsl"
#include "/lib/clouds.glsl"
#include "/lib/stars.glsl"

#ifdef PHOTONICS_REFLECT_ENABLED
	#include "/photonics/uniforms.glsl"
	#include "/photonics/tracing.glsl"
	#include "/photonics/trace_ray.glsl"
#endif

#ifdef MC_NORMAL_MAP
	#include "/lib/normal_map.glsl"
#endif

#ifdef MAT_SPECULAR_ENABLED
	const vec2 v_taa_offset = vec2(0.0);
	#include "/lib/specular.glsl"
#endif


vec3 rayTrace(vec3 dir, vec3 position, float dither, float fresnel) {
    float quality = mix(15, REFLECTION_QUALITY, fresnel);
    vec3 clipPosition = toClipSpace3(position);

	float rayLength = ((position.z + dir.z * farPlane*sqrt(3.0)) > -nearPlane) ?
       (-nearPlane -position.z) / dir.z : farPlane*sqrt(3.0);

	// convert to clip space
    vec3 direction = normalize(toClipSpace3(dir * rayLength + position) - clipPosition);
    direction.xy = normalize(direction.xy);

    // get at which length the ray intersects with the edge of the screen
    vec3 maxLengths = (step(0.0, direction) - clipPosition) / direction;
    float mult = minOf(maxLengths);

    vec3 stepv = direction * mult / quality * vec3(RENDER_SCALE_2, 1.0);

	vec3 spos = clipPosition * vec3(RENDER_SCALE_2, 1.0) + stepv*dither;
	float minZ = clipPosition.z;
	float maxZ = spos.z + stepv.z * 0.5;
	spos.xy += taa_offsets[framemod8] * texelSize * 0.5 / RENDER_SCALE;

    for (int i = 0; i <= int(quality); i++) {
		#ifdef REFLECTION_QUARTER_RES_DEPTH
			// decode depth buffer
			float sp = texelFetch(texDepthQ, ivec2(spos.xy/texelSize/4), 0).r;
			sp = invLinZ(sqrt(sp / 65000.0), nearPlane, farPlane);

			if (sp <= max(maxZ, minZ) && sp >= min(maxZ, minZ)) {
				return vec3(spos.xy / RENDER_SCALE, sp);
	        }

        	spos += stepv;
		#else
			float sp = texelFetch(depthtex1, ivec2(spos.xy / texelSize), 0).r;
          	if (sp <= max(maxZ, minZ) && sp >= min(maxZ, minZ)) {
				return vec3(spos.xy / RENDER_SCALE, sp);
	        }

        	spos += stepv;
		#endif

		// small bias
		minZ = maxZ - 0.00004 / linZ(spos.z, nearPlane, farPlane);
		maxZ += stepv.z;
    }

    return vec3(1.1);
}

float cdist(vec2 coord) {
	return max(abs(coord.s - 0.5), abs(coord.t - 0.5)) * 2.0;
}

#define PW_DEPTH 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0]
#define PW_POINTS 1 //[2 4 6 8 16 32]

vec3 getParallaxDisplacement(vec3 posxz, float iswater, float bumpmult, vec3 viewVec) {
	float waveZ = mix(20.0,0.25,iswater);
	float waveM = mix(0.0,4.0,iswater);

	vec3 parallaxPos = posxz;
	vec2 vec = vIn.viewVector.xy * (1.0 / float(PW_POINTS)) * PW_DEPTH;
	float waterHeight = getWaterHeightmap(posxz.xz, iswater) * 2.0;
	parallaxPos.xz += waterHeight * vec;

	return parallaxPos;
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

	vec2 taa_offset = taa_offsets[framemod8];
	float iswater = vIn.normalMat.w;

//	vec3 fragC = gl_FragCoord.xyz * vec3(texelSize, 1.0);
	vec3 viewPos = toScreenSpace(gl_FragCoord.xyz * vec3(texelSize / RENDER_SCALE, 1.0) - vec3(taa_offset * texelSize * 0.5, 0.0));

	outColor2 = texture(gtexture, vIn.lmtexcoord.xy, Texture_MipMap_Bias) * vIn.color;

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

	if (iswater > 0.0) {
		f0 = iswater > 0.1 ? 0.02 : 0.05 * (1.0 - outColor2.a);
		roughness = 0.02;
	}

	if (iswater > 0.4) {
		albedo = vec3(0.42, 0.6, 0.7);
		outColor2 = vec4(0.42, 0.6, 0.7, 0.7);
		roughness = 0.1;
	}

	if (iswater > 0.9) {
		outColor2 = vec4(0.0);
		roughness = 0.0;
	}

	vec3 normal = vIn.normalMat.xyz;

	vec3 localPos = mul3(gbufferModelViewInverse, viewPos);

	mat3 tbnMatrix = mat3(
		vIn.tangent.x, vIn.binormal.x, normal.x,
		vIn.tangent.y, vIn.binormal.y, normal.y,
		vIn.tangent.z, vIn.binormal.z, normal.z);

	if (iswater > 0.4) {
		float bumpmult = 1.0;
		if (iswater > 0.9) bumpmult = 1.0;

		float parallaxMult = bumpmult;

		vec3 posxz = localPos + cameraPosition;
		posxz.xz -= posxz.y;

		if (iswater < 0.9) posxz.xz *= 3.0;

		posxz.xyz = getParallaxDisplacement(posxz, iswater, bumpmult, normalize(tbnMatrix * viewPos));

		vec3 bump = normalize(getWaveHeight(posxz.xz, iswater));

		bump = bump * vec3(bumpmult) + vec3(0.0, 0.0, 1.0 - bumpmult);

		normal = normalize(bump * tbnMatrix);
	}
	else {
		#ifdef MC_NORMAL_MAP
			const float wetness = 0.0; // TODO
			vec3 tex_normal = mat_normal(texture(normals, vIn.lmtexcoord.xy).rgb);
			normal = applyBump(tbnMatrix, tex_normal, wetness);
		#endif
	}

	float NdotL = lightSign * dot(normal, sunVec);
	float NdotU = dot(upVec, normal);
	float diffuseSun = saturate(NdotL);

	vec3 direct = texelFetch(TEX_SKY_LUT, ivec2(6, 37), 0).rgb / PI;

	float noise = blueNoise(gl_FragCoord.xy, frameCounter);
	float shading = 1.0;

	// compute shadows only if not backface
	if (diffuseSun > 0.001) {
		vec3 projectedShadowPosition = mul3(shadowModelView, localPos);
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
//			float noise = blueNoise(gl_FragCoord.xy, frameCounter);
			float rdMul = 4.0 / shadowMapResolution;

			for (int i = 0; i < SHADOW_FILTER_SAMPLE_COUNT; i++) {
				vec2 offsetS = tapLocation_Shadow(i, SHADOW_FILTER_SAMPLE_COUNT, 2.0, noise);
				float bias = 1.0 + (i + noise) * rdMul/SHADOW_FILTER_SAMPLE_COUNT * shadowMapResolution;
				shading += texture(shadowtex0HW, vec3(projectedShadowPosition + vec3(rdMul*offsetS, -diffthresh*bias)));
			}

			direct *= shading / SHADOW_FILTER_SAMPLE_COUNT;
		}
	}

	direct *= (iswater > 0.9 ? 0.2 : 1.0) * diffuseSun * vIn.lmtexcoord.w;

	vec3 diffuseLight = direct + texture(TEX_SKY_LUT, (vIn.lmtexcoord.zw * 15.0 + 0.5) * texelSize).rgb;
	vec3 color = diffuseLight * albedo * 8.0 / 150.0 / 3.0;

	float normalDotEye = dot(normal, normalize(viewPos));
	float fresnel = pow(clamp(1.0 + normalDotEye, 0.0, 1.0), 5.0);
	fresnel = mix(f0, 1.0, fresnel);

	// premultiply alpha
	outColor2.rgb = color * outColor2.a;

	#ifdef MAT_SPECULAR_ENABLED
		const bool hand = false;

		vec2 noise2 = blueNoise(texBlueNoise, gl_FragCoord.xy).rg;
		vec3 lightCol2 = texelFetch(TEX_SKY_LUT, ivec2(6, 37), 0).rgb / PI;

		vec3 localNormal = mat3(gbufferModelViewInverse) * normal;
		vec3 localViewDir = normalize(localPos);

		float lightCol_a = float(sunElevation > 1.e-5) * 2.0 - 1.0;
		vec3 localSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
		vec3 WsunVec = lightCol_a * localSunDir;

		MaterialReflections(outColor2.rgb, roughness, vec3(f0), albedo, WsunVec, lightCol2, shading * diffuseSun, vIn.lmtexcoord.w, localNormal, localViewDir, viewPos, vec3(noise2, noise), hand);
	#endif

	outColor2.rgb *= 0.1;
	outColor7 = vec4(albedo, iswater);
}
