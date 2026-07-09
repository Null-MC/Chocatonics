#version 430 compatibility

//Render sky, volumetric clouds, direct lighting

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#define RENDER_OPAQUE_DEFERRED
#define TEX_SKY_LUT colortex4
#define TEX_FINAL_PREV colortex5

#ifdef VOXY
	#define TEX_DEPTH_OPAQUE texVoxyDepthOpaque
	#define TEX_DEPTH_TRANSLUCENT texVoxyDepthTranslucent
	#define TEX_DEPTH_REFLECT texVoxyDepthOpaque
#else
	#define TEX_DEPTH_OPAQUE depthtex1
	#define TEX_DEPTH_TRANSLUCENT depthtex0
	#define TEX_DEPTH_REFLECT depthtex1
#endif


in VertexData {
	flat vec4 lightCol; // main light source color (rgb), used light source (1=sun, -1=moon)
	flat vec3 WsunVec;
	flat vec3 ambientUp;
	flat vec3 ambientLeft;
	flat vec3 ambientRight;
	flat vec3 ambientB;
	flat vec3 ambientF;
	flat vec3 ambientDown;
//	flat float tempOffsets;
	flat vec2 TAA_Offset;
	flat vec3 refractedSunVec;
} vIn;

uniform sampler2D TEX_GB_COLOR;
uniform sampler2D TEX_GB_NORMAL;
uniform sampler2D TEX_GB_SPECULAR;
uniform sampler2D TEX_GB_WORLD;
uniform sampler2D colortex0;//clouds
//uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16
uniform sampler2D TEX_SKY_LUT;//Skybox
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex7;
//uniform sampler2D depthtex1;//depth
//uniform sampler2D depthtex0;//depth
uniform sampler2D noisetex;//depth
uniform sampler2D texBlueNoise;
uniform sampler2D texDepthQ;
uniform sampler2DShadow shadowtex0HW;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef VOXY
	uniform sampler2D texVoxyDepthOpaque;
	uniform sampler2D texVoxyDepthTranslucent;
#else
//	uniform sampler2D depthtex0;
#endif

#ifdef SHADOW_COLORED
	uniform sampler2DShadow shadowtex1HW;
	uniform sampler2D shadowcolor0;
#endif

#ifdef LIGHTING_COLORED
	uniform usampler3D texVoxels;
	uniform sampler3D texFloodFill;
	uniform sampler2D texBlockLight;
	uniform usampler2D texBlockLightMask;
#endif

#ifdef REFLECTION_ENABLED
	uniform sampler2D gaux2;
#endif

//#ifdef PH_ENABLE_GI
//	uniform sampler2D texPhotonicsIndirect;
//#endif

uniform int frameCounter;
uniform int isEyeInWater;
uniform int heldItemId;
uniform int heldItemId2;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform float far;
uniform float near;
//uniform float wetness;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelView;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform vec2 texelSize;
uniform vec3 cameraPosition;
uniform vec3 sunVec;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 relativeEyePosition;
uniform int framemod8;


//vec3 toScreenSpacePrev(vec3 p) {
//	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
//    vec3 p3 = p * 2.0 - 1.0;
//    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
//    return fragposition.xyz / fragposition.w;
//}

#include "/lib/blocks.glsl"

#include "/lib/r2.glsl"
#include "/lib/ign.glsl"
#include "/lib/ggx.glsl"
#include "/lib/dither.glsl"
#include "/lib/fresnel.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/octohedral.glsl"
#include "/lib/projections.glsl"
#include "/lib/lod_projections.glsl"
#include "/lib/waterOptions.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/shadowSampling.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/stars.glsl"
#include "/lib/volumetricClouds.glsl"

#ifdef LIGHTING_COLORED
	#include "/lib/voxel.glsl"
	#include "/lib/blockLights.glsl"
	#include "/lib/blockLightMask.glsl"
	#include "/lib/floodfill.glsl"
	#include "/lib/floodfillMasked.glsl"
#endif

#include "/lib/handLight.glsl"

vec2 v_taa_offset = vIn.TAA_Offset;
#include "/lib/specular.glsl"

#if defined(PHOTONICS_BLOCK_LIGHT_ENABLED) || defined(PHOTONICS_HAND_LIGHT_ENABLED) || defined(PHOTONICS_GI_ENABLED)
	#include "/photonics/samplers.glsl"
#endif


float rayTraceShadow(vec3 dir, vec3 position, float dither) {
    const int quality = 16;

    vec3 clipPosition = toClipSpace3_lod(position);

	// prevents the ray from going behind the camera
	float rayLength = ((position.z + dir.z * farPlane*sqrt(3.0)) > -nearPlane) ?
       (-nearPlane -position.z) / dir.z : farPlane*sqrt(3.0);

    vec3 direction = toClipSpace3_lod(dir * rayLength + position) - clipPosition;  // convert to clip space
    direction = direction / max(abs(direction.x) / texelSize.x, abs(direction.y) / texelSize.y);	// fixed step size

    vec3 stepv = direction * 3.0 * clamp(MC_RENDER_QUALITY, 1.0, 2.0) * vec3(RENDER_SCALE_2, 1.0);

	vec3 spos = clipPosition * vec3(RENDER_SCALE_2, 1.0) + vec3(vIn.TAA_Offset * texelSize.xy * 0.5, 0.0) + stepv * dither;

	for (int i = 0; i < quality; i++) {
		spos += stepv;

		float sp = texture(TEX_DEPTH_OPAQUE, spos.xy).x;

        if (isDepthNearer(sp, spos.z)) {
			#ifdef VOXY
				float z2 = near / spos.z;
				float dist = abs(near / sp - z2) / z2;
			#else
				float z2 = depthScreenToLinear(spos.z, nearPlane, farPlane);
				float dist = abs(depthScreenToLinear(sp, nearPlane, farPlane) - z2) / z2;
			#endif

			if (dist < 0.01) return 0.0;
		}
	}

    return 1.0;
}

vec2 tapLocation_AO(int sampleNumber, float spinAngle, int nb, float nbRot, float r0) {
	float alpha = (sampleNumber + r0) * (1.0 / nb);
	float angle = (alpha * nbRot + spinAngle) * (PI*2.0);

	return vec2(cos(angle), sin(angle)) * alpha;
}

vec3 BilateralFiltering(sampler2D tex, sampler2D depth, vec2 coord, float frDepth, float maxZ) {
	vec4 sampled = vec4(texelFetch(tex, ivec2(coord), 0).rgb, 1.0);
	return vec3(sampled.x, sampled.yz / sampled.w);
}

float waterCaustics(vec3 wPos, vec3 lightSource) {
	vec2 pos = (wPos.xz - lightSource.xz/lightSource.y * wPos.y) * 4.0;
	vec2 movement = vec2(-0.02 * frameTimeCounter);

	float caustic = 0.0;
	float weightSum = 0.0;
	float radiance = 2.39996;

	mat2 rotationMatrix  = mat2(
		vec2(cos(radiance), -sin(radiance)),
		vec2(sin(radiance),  cos(radiance)));

	vec2 displ = texture(noisetex, pos * vec2(3.0, 1.0) / 96.0 + movement).bb * 2.0 - 1.0;
	pos = pos/2.0 + vec2(1.74 * frameTimeCounter);

	for (int i = 0; i < 3; i++) {
		pos = rotationMatrix * pos;

		float w = exp2(-0.8 * i);
		caustic += pow(0.5 + sin(dot(pos * exp2(0.8*i) + displ*PI, vec2(0.5)))*0.5, 6.0) * w/1.41;
		weightSum += w;
	}

	return caustic * weightSum;
}

void waterVolumetrics(inout vec3 inColor, vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL){
	inColor *= exp(-rayLength * waterCoefs); // No need to take the integrated value

	vec3 startWorld = toWorldSpace(rayStart);

	vec3 start = worldToShadowSpaceProjected(startWorld);
	vec3 end = worldToShadowSpaceProjected(toWorldSpace(rayEnd));
	vec3 dV = end - start;

	// limit ray length at 32 blocks for performance and reducing integration error
	// you can't see above this anyway
	float maxZ = min(rayLength, 32.0) / (1e-8 + rayLength);
	dV *= maxZ;

	vec3 dVWorld = mat3(gbufferModelViewInverse) * (rayEnd - rayStart) * maxZ;

	rayLength *= maxZ;
	estEndDepth *= maxZ;
	estSunDepth *= maxZ;

	vec3 absorbance = vec3(1.0);
	vec3 vL = vec3(0.0);
	float phase = phaseg(VdotL, Dirt_Mie_Phase);
	float expFactor = 11.0;

//	vec3 progressW = gbufferModelViewInverse[3].xyz + cameraPosition;
	const int spCount = rayMarchSampleCount;
	const float sampleCountInv = 1.0 / spCount;

	for (int i = 0; i < spCount; i++) {
		float stepF = pow(expFactor, (i + dither) * sampleCountInv);
		float d = (stepF/expFactor - 1.0/expFactor)/(1.0 - 1.0/expFactor);
		float dd = stepF * log(expFactor) * sampleCountInv / (expFactor-1.0);

		vec3 spPos = start.xyz + d*dV;

		vec3 progressL = startWorld + d*dVWorld;
//		vec3 progressW = progressL + cameraPosition;

		// project into biased shadowmap space
		float distortFactor = calcDistort(spPos.xy);
		vec3 pos = vec3(spPos.xy * distortFactor, spPos.z);
		float sh = 1.0;

		if (IsInShadowMap(pos)) {
			pos = pos * vec3(0.5, 0.5, 0.5/6.0) + 0.5;
			sh = texture(shadowtex0HW, pos);
		}

		vec3 ambientMul = exp(-estEndDepth * d * waterCoefs * 1.1);
		vec3 sampleLight = ambientMul * ambient;

		#if defined(LIGHTING_COLORED) && defined(LIGHTING_FLOODFILL_FOG)
			vec3 voxelPos = GetVoxelPosition(progressL);
			if (IsInVoxelBounds(voxelPos)) {
				sampleLight += SampleFloodFill(voxelPos, frameCounter);
			}
		#endif

		vec3 sunMul = exp(-estSunDepth * d * waterCoefs);
		vec3 light = (sh * lightSource/150.0 * 8.0/3.0 * phase * sunMul + sampleLight) * scatterCoef;
		vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs * absorbance;
		absorbance *= exp(-dd * rayLength * waterCoefs);
	}

	inColor += vL;
}

vec3 RT(vec3 dir, vec3 position, float noise, vec3 N) {
	float stepSize = STEP_LENGTH;
	int maxSteps = STEPS;

	vec3 clipPosition = toClipSpace3_lod(position);

	float rayLength = ((position.z + dir.z * sqrt(3.0)*farPlane) > -sqrt(3.0)*nearPlane) ?
	   								(-sqrt(3.0)*nearPlane -position.z) / dir.z : sqrt(3.0)*farPlane;

	vec3 end = toClipSpace3_lod(dir * rayLength + position);
	vec3 direction = end - clipPosition;  //convert to clip space
	float len = maxOf(abs(direction.xy) / texelSize.xy) / stepSize;

	// get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.0, direction) - clipPosition) / direction;
	float mult = minOf(maxLengths);
	vec3 stepv = direction / len;

	int iterations = min(int(min(len, mult * len) - 2), maxSteps);

	// Do one iteration for closest texel (good contact shadows)
	vec3 spos = clipPosition * vec3(RENDER_SCALE_2, 1.0) + stepv/stepSize*6.0;
	spos.xy += vIn.TAA_Offset * texelSize * 0.5*RENDER_SCALE;

	#ifdef REFLECTION_QUARTER_RES_DEPTH
		float sp = sqrt(texelFetch(texDepthQ, ivec2(spos.xy / texelSize/4.0), 0).r / 65000.0);
		float spL = sp * farPlane;
	#else
		float sp = texelFetch(TEX_DEPTH_OPAQUE, ivec2(spos.xy / texelSize), 0).r;

		#ifdef VOXY
			float spL = sp > 0.0 ? near / sp : farPlane;
		#else
			float spL = depthScreenToLinear(sp, nearPlane, farPlane);
		#endif
	#endif

	float currZ = depthScreenToLinear(spos.z, nearPlane, farPlane);

	if (spL < currZ) {
		float dist = abs(spL - currZ) / currZ;
		if (dist <= 0.035) {
			return vec3(spos.xy, sp) / vec3(RENDER_SCALE_2, 1.0);
		}
	}

	stepv *= vec3(RENDER_SCALE_2, 1.0);
	spos += stepv * noise;

	for (int i = 0; i < iterations; i++) {
		#ifdef REFLECTION_QUARTER_RES_DEPTH
			float sp = sqrt(texelFetch(texDepthQ, ivec2(spos.xy / texelSize/4.0), 0).r / 65000.0);
			float spL = sp * farPlane;
		#else
			float sp = texelFetch(TEX_DEPTH_OPAQUE, ivec2(spos.xy / texelSize), 0).r;

			#ifdef VOXY
				float spL = sp > 0.0 ? near / sp : farPlane;
			#else
				float spL = depthScreenToLinear(sp, nearPlane, farPlane);
			#endif
		#endif

		float currZ = depthScreenToLinear(spos.z, nearPlane, farPlane);

		if (spL < currZ) {
			float dist = abs(spL - currZ) / currZ;
			if (dist <= 0.035) return vec3(spos.xy, sp) / vec3(RENDER_SCALE_2, 1.0);
		}

		spos += stepv;
	}

	return vec3(1.1);
}

vec3 cosineHemisphereSample(vec2 Xi) {
    float r = sqrt(Xi.x);
    float theta = 2.0 * PI * Xi.y;

    float x = r * cos(theta);
    float y = r * sin(theta);

    return vec3(x, y, sqrt(saturate(1.0 - Xi.x)));
}

vec3 TangentToWorld(vec3 N, vec3 H) {
    vec3 UpVector = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(UpVector, N));
    vec3 B = cross(N, T);

    return vec3((T * H.x) + (B * H.y) + (N * H.z));
}

vec3 rtGI(vec3 normal, vec4 noise, vec3 fragpos, vec3 ambient, float translucent, vec3 torch, vec3 albedo) {
	vec3 intRadiance = vec3(0.0);
	float occlusion = 0.0;
	float accLight = 0.0;

	vec3 viewNormal = mat3(gbufferModelView) * normal;

	for (int i = 0; i < RAY_COUNT; i++) {
		int seed = (frameCounter % 40000) * RAY_COUNT + i;
		vec2 ij = fract(R2_samples(seed) + noise.rg);

		vec3 rayDir = normalize(cosineHemisphereSample(ij));
		rayDir = TangentToWorld(normal, rayDir);

		vec3 rayHit = RT(mat3(gbufferModelView) * rayDir, fragpos, fract(seed/1.6180339887 + noise.b), viewNormal);

		if (!isDepthSky(rayHit.z)) {
			vec3 previousPosition = rayHit;
//			previousPosition = toScreenSpace_lod(previousPosition);
//			previousPosition = toWorldSpaceCamera(previousPosition) - previousCameraPosition;
//			previousPosition = worldToViewSpace_prev(previousPosition);
//			previousPosition = toClipSpace3_lodPrev(previousPosition);

//			if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.y < 1.0)
			if (all(equal(saturate(previousPosition.xy), previousPosition.xy))) {
				intRadiance += texture(colortex5, previousPosition.xy).rgb + ambient * albedo * translucent;
			}
			else {
				intRadiance += ambient + ambient * translucent * albedo;
			}

			occlusion += 1.0;
		}
		else {
		//	float bounceAmount = float(rayDir.y > 0.0) + clamp(-rayDir.y*0.1+0.1, 0.0,1.0);
			//vec3 sky_c = skyCloudsFromTex(rayDir,TEX_SKY_LUT).rgb * bounceAmount;
			intRadiance += ambient;
		}
	}

	return intRadiance / RAY_COUNT + (1.0 - occlusion / RAY_COUNT) * torch;
}

void ssao(inout float occlusion, vec3 fragpos, float mulfov, float dither, vec3 normal) {
	ivec2 pos = ivec2(gl_FragCoord.xy);
	const float tan70 = tan(70.0 * PI / 180.0);
	float mulfov2 = gbufferProjection[1][1] / tan70;

	const float samplingRadius = 0.712;
	float angle_thresh = 0.05;
	float maxR2 = fragpos.z * fragpos.z * mulfov2 * 2.0 * 1.412 / 50.0;

	float rd = mulfov2 * 0.04;

	// pre-rotate direction
	float n = 0.0;

	occlusion = 0.0;

	vec2 acc = -vIn.TAA_Offset * texelSize * 0.5;
	float mult = (dot(normal, normalize(fragpos)) + 1.0) * 0.5 + 0.5;

	vec2 v = fract(vec2(dither, R2_dither(gl_FragCoord.xy, frameCounter)) + (frameCounter % 10000) * vec2(0.75487765, 0.56984026));

	vec2 viewSizeScaled = vec2(viewWidth, viewHeight) * RENDER_SCALE;

	for (int j = 0; j < 7; j++) {
		vec2 sp = tapLocation_AO(j, v.x, 7, 88.0, v.y);
		vec2 sampleOffset = sp * rd;

		ivec2 offset = ivec2(gl_FragCoord.xy + sampleOffset * vec2(viewWidth, viewHeight * aspectRatio) * RENDER_SCALE);

//		if (offset.x >= 0 && offset.y >= 0 && offset.x < viewWidth*RENDER_SCALE && offset.y < viewHeight*RENDER_SCALE) {
		if (all(equal(clamp(offset, ivec2(0), viewSizeScaled), offset))) {
			float z = texelFetch(TEX_DEPTH_OPAQUE, offset, 0).x;
			vec3 t0 = toScreenSpace_lod(vec3((offset + 0.5) * texelSize + acc, z) * vec3(1.0/RENDER_SCALE_2, 1.0));

			vec3 vec = t0.xyz - fragpos;
			float dsquared = dot(vec, vec);

			if (dsquared > 1.e-5) {
				if (dsquared < maxR2) {
					float NdotV = saturate(dot(vec * inversesqrt(dsquared), normalize(normal)));
					occlusion += NdotV * saturate(1.0 - dsquared/maxR2);
				}

				n += 1.0;
			}
		}
	}

	occlusion = saturate(1.0 - occlusion/n*1.6);
}


/* RENDERTARGETS: 3 */
layout(location = 0) out vec3 outColor3;

void main() {
	vec2 texcoord = gl_FragCoord.xy * texelSize;

	float dirtAmount = Dirt_Amount;
	vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
	vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
	vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
	vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B);

	float depth_trans = texture(TEX_DEPTH_TRANSLUCENT, texcoord).x;
	float depth_opaque = texture(TEX_DEPTH_OPAQUE, texcoord).x;

	float noise = blueNoise(gl_FragCoord.xy, frameCounter);

	vec3 screenPos_opaque = vec3(
		texcoord / RENDER_SCALE - vIn.TAA_Offset * texelSize * 0.5,
		max(depth_opaque, near/farPlane));

	vec3 viewPos_opaque = toScreenSpace_lod(screenPos_opaque);
	vec3 localPos_opaque = mat3(gbufferModelViewInverse) * viewPos_opaque;
	vec3 np3 = normVec(localPos_opaque);

	// sky
	if (isDepthSky(depth_opaque)) {
		vec3 color = vec3(0.0);
		vec4 cloud = texture2D_bicubic(colortex0, texcoord * CLOUDS_QUALITY);

		if (np3.y > 0.0) {
			color += stars(np3);
			color += drawSun(dot(vIn.lightCol.a * vIn.WsunVec, np3), 0, vIn.lightCol.rgb/150.0, vec3(0.0));
		}

		vec3 albedo = InputTransform(texture(TEX_GB_COLOR, texcoord).rgb);
		color += skyFromTex(np3, TEX_SKY_LUT)/150.0 + albedo/10.0 * 4.0*ffstep(0.985, -dot(vIn.lightCol.a * vIn.WsunVec, np3));
		color = color * cloud.a + cloud.rgb;

		outColor3 = clamp(fp10Dither(color * 8.0/3.0, triangularize(noise)), 0.0, 65000.0);

		//if (outColor3.r > 65000.) outColor3 = vec3(0.0);
		vec4 trpData = texture(colortex7, texcoord);

		if (trpData.a > 0.99) {
			vec3 fragpos_trans = toScreenSpace_lod(vec3(texcoord/RENDER_SCALE - vIn.TAA_Offset*texelSize*0.5, max(depth_trans, near/farPlane)));
			float Vdiff = distance(viewPos_opaque, fragpos_trans);
			float VdotU = np3.y;

			float estimatedDepth = Vdiff * abs(VdotU); // assuming water plane
			float estimatedSunDepth = estimatedDepth / abs(vIn.refractedSunVec.y); // assuming water plane

			vec3 lightColVol = vIn.lightCol.rgb * (1.0 - pow(1.0 - vIn.WsunVec.y, 5.0)); // fresnel
			vec3 ambientColVol = vIn.ambientUp * 8.0/150.0/3.0 * 0.5 * eyeBrightnessSmooth.y/240.0;

			if (isEyeInWater == 0)
				waterVolumetrics(outColor3, fragpos_trans, viewPos_opaque, estimatedDepth, estimatedSunDepth, Vdiff, noise, totEpsilon, scatterCoef, ambientColVol, lightColVol, dot(np3, vIn.WsunVec));
		}
	}
	// land
	else {
		localPos_opaque += gbufferModelViewInverse[3].xyz;

		vec4 trpData = texture(colortex7, texcoord);
//		bool iswater = texture(colortex7, texcoord).a > 0.99;
		bool iswater = trpData.a > 0.99;

		vec3 albedo = InputTransform(texture(TEX_GB_COLOR, texcoord).rgb);

		vec4 normalData = texture(TEX_GB_NORMAL, texcoord);
		vec3 geoViewNormal = OctDecode(normalData.xy);
		vec3 texViewNormal = OctDecode(normalData.zw);

		vec3 geoLocalNormal = mat3(gbufferModelViewInverse) * geoViewNormal;
		vec3 texLocalNormal = mat3(gbufferModelViewInverse) * texViewNormal;

//		#ifdef MAT_SPECULAR_ENABLED
			vec4 specularData = texture(TEX_GB_SPECULAR, texcoord);
			float emissive = specularData.a;
//		#endif

		vec4 worldData = texture(TEX_GB_WORLD, texcoord);
		vec2 lightmap = worldData.xy;
		float mat = worldData.w;

		bool hand = abs(mat-0.75) < 0.01;
//		bool hand = false;

		float NdotLGeom = dot(texLocalNormal, vIn.WsunVec);
		float NdotL = NdotLGeom;

//		if ((iswater && isEyeInWater == 0) || (!iswater && isEyeInWater == 1))
		if (iswater != (isEyeInWater == 1))
			NdotL = dot(texLocalNormal, vIn.refractedSunVec);

		float diffuseSun = saturate(NdotL);

		vec3 filtered = vec3(1.412, 1.0, 0.0);
		if (!hand) {
			#ifdef Variable_Penumbra_Shadows
				filtered = texture(colortex3, texcoord).rgb;
			#else
				filtered = vec3(Min_Shadow_Filter_Radius, 0.1, 0.0);
			#endif
		}

		float shading = 1.0 - filtered.b;
		float pShadow = filtered.b * 2.0 - 1.0;

		#ifdef SHADOW_COLORED
			vec3 shadowColor = vec3(1.0);
		#endif

		vec3 SSS = vec3(0.0);
		float sssAmount = specularData.b;

		vec3 projectedShadowPosition = worldToShadowSpaceProjected(localPos_opaque);
		bool inShadowMap = IsInShadowMap(projectedShadowPosition);

		#ifdef Variable_Penumbra_Shadows
			// compute shadows only if not backfacing the sun
			// or if the blocker search was full or empty
			// always compute all shadows at close range where artifacts may be more visible
			if (diffuseSun > 0.001)
		#else
			if (sssAmount > 0.5) {
				diffuseSun = mix(max(phaseg(dot(np3, vIn.WsunVec), 0.5), 2.0 * phaseg(dot(np3, vIn.WsunVec), 0.1)) * PI*1.6, diffuseSun, 0.3);
			}

			if (diffuseSun > 0.000)
		#endif
		{
//			vec3 projectedShadowPosition = worldToShadowSpaceProjected(localPos_opaque);

			// apply distortion
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;

			// do shadows only if on shadow map
//			if (IsInShadowMap(projectedShadowPosition)) {
			if (inShadowMap) {
//				inShadowMap = true;

				float rdMul = filtered.x * distortFactor * shadow_d0 * shadow_k / shadowMapResolution;
				const float threshMul = max(2048.0/shadowMapResolution * shadowDistance/128.0, 0.95);
				float distortThresh = (sqrt(1.0 - square(NdotLGeom)) / NdotLGeom + 0.7) / distortFactor;

				#ifdef Variable_Penumbra_Shadows
					float diffthresh = distortThresh/6000.0 * threshMul;
				#else
					float diffthresh = sssAmount > 0.0 ? 0.0001 : distortThresh/6000.0 * threshMul;
				#endif

				#if defined(MAT_PARALLAX_ENABLED) && defined(MAT_PARALLAX_DEPTH_WRITE)
					diffthresh += Parallax_Depth / 128.0/4.0/6.0;
				#endif

				projectedShadowPosition = projectedShadowPosition * vec3(0.5, 0.5, 0.5/6.0) + vec3(0.5, 0.5, 0.5);

				shading = 0.0;

				for (int i = 0; i < SHADOW_FILTER_SAMPLE_COUNT; i++) {
					vec2 offsetS = tapLocation_Shadow(i, SHADOW_FILTER_SAMPLE_COUNT, 84.0, noise);

					float bias = 1.0 + (i+noise) * rdMul/SHADOW_FILTER_SAMPLE_COUNT * shadowMapResolution;
					vec3 samplePos = vec3(projectedShadowPosition + vec3(rdMul * offsetS, -diffthresh * bias));
//					float isShadow = texture(shadowtex0HW, samplePos);

					#ifdef SHADOW_COLORED
						float isShadow = texture(shadowtex1HW, samplePos);

						float shadowColorF = texture(shadowtex0HW, samplePos);

						vec4 sampleColor = texture(shadowcolor0, samplePos.xy);

						sampleColor.rgb = mix(sampleColor.rgb, vec3(1.0), shadowColorF);

						shadowColor += InputTransform(sampleColor.rgb) * isShadow;
					#else
						float isShadow = texture(shadowtex0HW, samplePos);
					#endif

					shading += isShadow;
				}

				shading /= float(SHADOW_FILTER_SAMPLE_COUNT);
				#ifdef SHADOW_COLORED
					shadowColor /= float(SHADOW_FILTER_SAMPLE_COUNT);
				#endif
			}
		}

		// custom shading model for translucent objects
		#ifdef Variable_Penumbra_Shadows
			if (sssAmount > 0.5) {
//				sssAmount = 0.5;
				vec3 extinction = 1.0 - albedo*0.85;

				// Should be somewhat energy conserving
				SSS = exp(-filtered.y*11.0*extinction) + 3.0*exp(-filtered.y*11./3.*extinction);
				float scattering = saturate((0.7+0.3*PI * phaseg(dot(np3, vIn.WsunVec), 0.85)) * 1.5/4.0 * sssAmount);
				SSS *= scattering;
				diffuseSun *= 1.0 - sssAmount;
				SSS *= sqrt(lightmap.y);
			}

			if (sssAmount > 0.2) {
//				sssAmount = 0.2;
				vec3 extinction = 1.0 - albedo*0.85;

				// Should be somewhat energy conserving
				SSS = exp(-filtered.y*11.0*extinction) + 3.0*exp(-filtered.y*11./3.*extinction);
				float scattering = saturate((0.7+0.3*PI * phaseg(dot(np3, vIn.WsunVec), 0.85)) * 1.26/4.0 * sssAmount);
				SSS *= scattering;
				diffuseSun *= 1.0 - sssAmount;
				SSS *= sqrt(lightmap.y);
			}
		#endif

//		bool apply_sss = true;//abs(filtered.y-0.1) < 0.0004;
		if ((diffuseSun * shading > 0.001 || sssAmount > 0.0) && !hand) {
			#ifdef SCREENSPACE_CONTACT_SHADOWS
				vec3 vec = vIn.lightCol.a * sunVec;
				float screenShadow = rayTraceShadow(vec, viewPos_opaque, noise);
				shading = min(screenShadow, shading);

				// Out of shadow map
				if (!inShadowMap) SSS *= screenShadow;
			#endif

			#ifdef CAVE_LIGHT_LEAK_FIX
				shading = mix(0.0, shading, saturate(eyeBrightnessSmooth.y/255.0 + lightmap.y));
			#endif
		}

		#ifdef CLOUDS_SHADOWS
			vec3 worldPos = localPos_opaque + cameraPosition;
			const int rayMarchSteps = 6;
			float cloudShadow = 0.0;

			for (int i = 0; i < rayMarchSteps; i++) {
				vec3 cloudPos = worldPos + vIn.WsunVec / abs(vIn.WsunVec.y) * (1500 + (noise+i) / rayMarchSteps*1700 - worldPos.y);
				cloudShadow += getCloudDensity(cloudPos, 0);
			}

			cloudShadow = mix(1.0, exp(-cloudShadow * cloudDensity * 1700/rayMarchSteps), mix(CLOUDS_SHADOWS_STRENGTH, 1.0, rainStrength));
			shading *= cloudShadow;
			SSS *= cloudShadow;
		#endif

		vec3 directLighting = vec3(0.0);
		#if defined(PHOTONICS_BLOCK_LIGHT_ENABLED) || defined(PHOTONICS_GI_ENABLED)
			directLighting += sample_photonics_direct(texcoord/RENDER_SCALE);
		#endif

		#ifdef PHOTONICS_HAND_LIGHT_ENABLED
			directLighting += sample_photonics_handheld(texcoord/RENDER_SCALE);
		#endif

		#ifdef VOXY
			bool isLod = texture(depthtex0, texcoord).r >= 1.0;
		#else
			const bool isLod = false;
		#endif

		vec3 ambientLight = vec3(0.0);
		bool hasIndirect = true;

		#ifdef PHOTONICS_GI_ENABLED
			if (!isLod) hasIndirect = false;
		#endif

		if (hasIndirect) {
			vec3 ambientCoefs = texLocalNormal / dot(abs(texLocalNormal), vec3(1.0));
			ambientLight = vIn.ambientUp * mix(saturate(ambientCoefs.y), 1.0/6.0, sssAmount);
			ambientLight += vIn.ambientDown * mix(saturate(-ambientCoefs.y), 1.0/6.0, sssAmount);
			ambientLight += vIn.ambientRight * mix(saturate(ambientCoefs.x), 1.0/6.0, sssAmount);
			ambientLight += vIn.ambientLeft * mix(saturate(-ambientCoefs.x), 1.0/6.0, sssAmount);
			ambientLight += vIn.ambientB * mix(saturate(ambientCoefs.z), 1.0/6.0, sssAmount);
			ambientLight += vIn.ambientF * mix(saturate(-ambientCoefs.z), 1.0/6.0, sssAmount);
		}

		#ifdef PHOTONICS_GI_ENABLED
			if (!isLod) {
				lightmap.y = 0.0;
			}
		#endif

		#if !defined(PHOTONICS_HAND_LIGHT_ENABLED) && !defined(LIGHTING_COLORED)
			float maxLit = SampleHandLight(localPos_opaque, texLocalNormal);
			lightmap.x = max(lightmap.x, maxLit);
		#endif

		vec3 custom_lightmap = texture(colortex4, (lightmap * 15.0 + 0.5 + vec2(0.0, 19.0)) * texelSize).rgb / 150.0 * 8.0/3.0;

//		#if defined(PHOTONICS_BLOCK_LIGHT_ENABLED) && defined(PHOTONICS_GI_ENABLED)
//			if (!isLod) custom_lightmap = vec3(0.0);
//		#endif

		if (hand && heldBlockLightValue > 0.1) {
			custom_lightmap.y = 0.0;
		}

		vec3 skyDirectLight = vIn.lightCol.rgb;

		vec4 noise2 = blueNoise(texBlueNoise, gl_FragCoord.xy);

		vec3 torchLight = custom_lightmap.y * TorchColor;

		#ifdef PHOTONICS_BLOCK_LIGHT_ENABLED
			if (!isLod) {
				torchLight = vec3(0.0);
			}
		#elif defined(LIGHTING_COLORED)
			vec3 voxelPos = GetVoxelPosition(localPos_opaque);
			vec3 samplePos = GetFloodFillSamplePos(voxelPos, geoLocalNormal, texLocalNormal);

			if (IsInVoxelBounds(samplePos)) {
				torchLight = SampleFloodFillMasked(samplePos, frameCounter);
			}
		#endif

		#if !defined(PHOTONICS_HAND_LIGHT_ENABLED) && defined(LIGHTING_COLORED)
			torchLight += SampleHandLight(localPos_opaque, texLocalNormal, heldItemId, heldBlockLightValue);
			torchLight += SampleHandLight(localPos_opaque, texLocalNormal, heldItemId2, heldBlockLightValue2);
		#endif

		vec3 fragpos_trans;
		float Vdiff;
		float estimatedDepth;
		float estimatedSunDepth;

		if (iswater != (isEyeInWater == 1)) {
			fragpos_trans = toScreenSpace_lod(vec3(texcoord / RENDER_SCALE - vIn.TAA_Offset * texelSize * 0.5, depth_trans));
			Vdiff = distance(viewPos_opaque, fragpos_trans);

			float VdotU = np3.y;
			estimatedDepth = Vdiff * abs(VdotU); // assuming water plane

			if (isEyeInWater == 1) {
				Vdiff = length(viewPos_opaque);

				#ifdef lightMapDepthEstimation
					estimatedDepth = saturate((15.5 - lightmap.y * 16.0) / 15.5);
					estimatedDepth *= estimatedDepth * estimatedDepth * 32.0;
				#else
					estimatedDepth = max(Water_Top_Layer - (cameraPosition.y + localPos_opaque.y), 0.0);
				#endif
			}

			// k = 1-r*r*(1-sy*sy)
			estimatedSunDepth = estimatedDepth / abs(vIn.refractedSunVec.y); //assuming water plane
			skyDirectLight *= exp(-totEpsilon * estimatedSunDepth) * (1.0 - pow(1.0 - vIn.WsunVec.y, 5.0));

			vec3 worldPos = toWorldSpaceCamera(viewPos_opaque);
			float caustics = waterCaustics(worldPos, vIn.refractedSunVec);
			skyDirectLight *= mix(caustics * 0.5 + 0.5, 1.0, exp(estimatedSunDepth / -3.0));

			if (isEyeInWater == 1) {
				ambientLight += 10.0 * exp(totEpsilon * -8.0);
				ambientLight *= exp(-totEpsilon * estimatedDepth) * 8.0/3.0 / 150.0;
			}
			else {
				ambientLight *= min(exp(-totEpsilon * estimatedDepth), custom_lightmap.x);
				ambientLight += custom_lightmap.z;
			}

			ambientLight *= mix(caustics, 1.0, 0.85);
			ambientLight += torchLight;

			#ifdef SSGI
				if (!hand) {
					float ao = 1.0;
					ssao(ao, viewPos_opaque, 1.0, noise, texViewNormal);
					ambientLight *= ao;
				}
			#endif
		}
		else {
			#ifdef SSGI
				if (!hand)
					ambientLight = rtGI(texLocalNormal, noise2, viewPos_opaque, ambientLight * custom_lightmap.x, sssAmount, custom_lightmap.z * vec3(0.9, 1.0, 1.5) + torchLight, normalize(albedo + 1.e-5) * 0.7);
				else
					ambientLight = ambientLight * custom_lightmap.x + custom_lightmap.z * vec3(0.9, 1.0, 1.5) + torchLight;
			#else
					ambientLight = ambientLight * custom_lightmap.x + custom_lightmap.z * vec3(0.9, 1.0, 1.5) + torchLight;
			#endif
		}

		float emitting = pow(emissive, Emission_Curve) * MAT_EMISSION_SCALE;

		// combine all light sources
		vec3 skyDiffuse = vec3(shading * diffuseSun);

		#ifdef SHADOW_COLORED
			skyDiffuse *= shadowColor;
		#endif

//		skyDiffuse += SSS;

		#ifdef DEBUG_WHITEWORLD
			albedo = vec3(1.0);
		#endif

		outColor3 = ((skyDiffuse + SSS)/PI * skyDirectLight * 8.0/3.0 / 150.0 + ambientLight + directLighting + emitting) * albedo;

		#ifdef MAT_SPECULAR_ENABLED
//			#ifdef MC_TEXTURE_FORMAT_LAB_PBR
				float roughness = square(1.0 - specularData.r);
				float f0 = specularData.g;
				if (f0 < EPSILON) f0 = 0.04;
//			#else
//				float roughness = 1.0;
//				float f0 = 0.04;
//			#endif

//			vec2 noise2 = blueNoise(texBlueNoise, gl_FragCoord.xy).rg;
			MaterialReflections(outColor3, roughness, f0, albedo, vIn.WsunVec, vIn.lightCol.rgb, skyDiffuse, lightmap.y, texLocalNormal, np3, viewPos_opaque, vec3(noise2.rg, noise), hand);
		#endif

		if (iswater && isEyeInWater == 0) {
			// Bruteforce integration is probably overkill
			vec3 lightColVol = vIn.lightCol.rgb * (1.0 - pow(1.0 - vIn.WsunVec.y, 5.0)); // fresnel
			vec3 ambientColVol = vIn.ambientUp * 8.0/3.0 / 150.0 * 0.5 * eyeBrightnessSmooth.y/240.0;

			#ifdef VOXY
				// Fake water depth since we cannot sample it
				if (Vdiff == 0.0) Vdiff = 20.0;
			#endif

			waterVolumetrics(outColor3, fragpos_trans, viewPos_opaque, estimatedDepth, estimatedSunDepth, Vdiff, noise, totEpsilon, scatterCoef, ambientColVol, lightColVol, dot(np3, vIn.WsunVec));
		}
	}
}
