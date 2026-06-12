#version 430 compatibility

//Render sky, volumetric clouds, direct lighting

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


flat varying vec4 lightCol; //main light source color (rgb),used light source(1=sun,-1=moon)
flat varying vec3 ambientUp;
flat varying vec3 ambientLeft;
flat varying vec3 ambientRight;
flat varying vec3 ambientB;
flat varying vec3 ambientF;
flat varying vec3 ambientDown;
flat varying vec3 WsunVec;
flat varying vec2 TAA_Offset;
flat varying float tempOffsets;
flat varying vec3 refractedSunVec;

uniform sampler2D TEX_GB_COLOR;
uniform sampler2D TEX_GB_NORMAL;
uniform sampler2D TEX_GB_SPECULAR;
uniform sampler2D TEX_GB_WORLD;
uniform sampler2D colortex0;//clouds
//uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16
uniform sampler2D colortex4;//Skybox
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex7;
uniform sampler2D depthtex1;//depth
uniform sampler2D depthtex0;//depth
uniform sampler2D noisetex;//depth
uniform sampler2D texBlueNoise;
uniform sampler2DShadow shadowtex0HW;

#ifdef SHADOW_COLORED
	uniform sampler2DShadow shadowtex1HW;
	uniform sampler2D shadowcolor0;
#endif

//#ifdef PH_ENABLE_GI
//	uniform sampler2D texPhotonicsIndirect;
//#endif

uniform int heldBlockLightValue;
uniform int frameCounter;
uniform int isEyeInWater;
uniform float far;
uniform float near;
uniform float frameTimeCounter;
uniform float rainStrength;
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


vec3 toScreenSpacePrev(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

#include "/lib/r2.glsl"
#include "/lib/ign.glsl"
#include "/lib/dither.glsl"
#include "/lib/decode.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/octohedral.glsl"
#include "/lib/projections.glsl"
#include "/lib/waterOptions.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/shadowSampling.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/stars.glsl"
#include "/lib/volumetricClouds.glsl"

#if defined(PH_ENABLE_BLOCKLIGHT) || defined(PH_ENABLE_HANDHELD_LIGHT)
	#include "/photonics/samplers.glsl"
#endif

vec3 normVec(vec3 vec) {
	return vec * inversesqrt(dot(vec, vec));
}

float lengthVec(vec3 vec) {
	return sqrt(dot(vec, vec));
}

float linZ(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
	// l = (2*n)/(f+n-d(f-n))
	// f+n-d(f-n) = 2n/l
	// -d(f-n) = ((2n/l)-f-n)
	// d = -((2n/l)-f-n)/(f-n)
}

float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}

float rayTraceShadow(vec3 dir, vec3 position, float dither) {
    const float quality = 16.0;

    vec3 clipPosition = toClipSpace3(position);
	//prevents the ray from going behind the camera
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
       (-near -position.z) / dir.z : far*sqrt(3.);

    vec3 direction = toClipSpace3(position+dir*rayLength)-clipPosition;  //convert to clip space
    direction.xyz = direction.xyz/max(abs(direction.x)/texelSize.x,abs(direction.y)/texelSize.y);	//fixed step size

    vec3 stepv = direction *3. * clamp(MC_RENDER_QUALITY,1.,2.0)*vec3(RENDER_SCALE,1.0);

	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0)+vec3(TAA_Offset*vec2(texelSize.x,texelSize.y)*0.5,0.0)+stepv*dither;

	for (int i = 0; i < int(quality); i++) {
		spos += stepv;

		float sp = texture2D(depthtex1,spos.xy).x;
        if (sp < spos.z) {
			float dist = abs(linZ(sp)-linZ(spos.z))/linZ(spos.z);

			if (dist < 0.01 ) return 0.0;
		}
	}

    return 1.0;
}

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

vec2 tapLocation_AO(int sampleNumber, float spinAngle, int nb, float nbRot, float r0) {
	float alpha = (float(sampleNumber * 1.0f + r0) * (1.0 / nb));
	float angle = alpha * nbRot * 6.28 + spinAngle*6.28;

	return vec2(cos(angle), sin(angle)) * alpha;
}

vec3 BilateralFiltering(sampler2D tex, sampler2D depth,vec2 coord,float frDepth,float maxZ){
	vec4 sampled = vec4(texelFetch2D(tex, ivec2(coord), 0).rgb, 1.0);
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

	vec2 displ = texture2D(noisetex, pos * vec2(3.0, 1.0) / 96.0 + movement).bb * 2.0 - 1.0;
	pos = pos/2.0 + vec2(1.74 * frameTimeCounter);

	for (int i = 0; i < 3; i++) {
		pos = rotationMatrix * pos;
		caustic += pow(0.5+sin(dot(pos * exp2(0.8*i)+ displ*3.1415,vec2(0.5)))*0.5,6.0)*exp2(-0.8*i)/1.41;
		weightSum += exp2(-0.8 * i);
	}

	return caustic * weightSum;
}

void waterVolumetrics(inout vec3 inColor, vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL){
	inColor *= exp(-rayLength * waterCoefs);	//No need to take the integrated value
	int spCount = rayMarchSampleCount;
	vec3 start = toShadowSpaceProjected(rayStart);
	vec3 end = toShadowSpaceProjected(rayEnd);
	vec3 dV = (end-start);

	//limit ray length at 32 blocks for performance and reducing integration error
	//you can't see above this anyway
	float maxZ = min(rayLength,32.0)/(1e-8+rayLength);
	dV *= maxZ;
	vec3 dVWorld = -mat3(gbufferModelViewInverse) * (rayEnd - rayStart) * maxZ;
	rayLength *= maxZ;
	estEndDepth *= maxZ;
	estSunDepth *= maxZ;
	vec3 absorbance = vec3(1.0);
	vec3 vL = vec3(0.0);
	float phase = phaseg(VdotL, Dirt_Mie_Phase);
	float expFactor = 11.0;
	vec3 progressW = gbufferModelViewInverse[3].xyz + cameraPosition;

	for (int i = 0; i < spCount; i++) {
		float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);
		vec3 spPos = start.xyz + dV*d;
		progressW = gbufferModelViewInverse[3].xyz + cameraPosition + d*dVWorld;

		//project into biased shadowmap space
		float distortFactor = calcDistort(spPos.xy);
		vec3 pos = vec3(spPos.xy * distortFactor, spPos.z);
		float sh = 1.0;

		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
			pos = pos * vec3(0.5, 0.5, 0.5/6.0) + 0.5;
			sh = texture(shadowtex0HW, pos);
		}

		vec3 ambientMul = exp(-estEndDepth * d * waterCoefs * 1.1);
		vec3 sunMul = exp(-estSunDepth * d * waterCoefs);
		vec3 light = (sh * lightSource*8./150./3.0 * phase * sunMul + ambientMul * ambient)*scatterCoef;
		vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs *absorbance;
		absorbance *= exp(-dd * rayLength * waterCoefs);
	}

	inColor += vL;
}

vec3 RT(vec3 dir, vec3 position, float noise, vec3 N) {
	float stepSize = STEP_LENGTH;
	int maxSteps = STEPS;

	vec3 clipPosition = toClipSpace3(position);

	float rayLength = ((position.z + dir.z * sqrt(3.0)*far) > -sqrt(3.0)*near) ?
	   								(-sqrt(3.0)*near -position.z) / dir.z : sqrt(3.0)*far;

	vec3 end = toClipSpace3(position+dir*rayLength);
	vec3 direction = end-clipPosition;  //convert to clip space
	float len = max(abs(direction.x)/texelSize.x,abs(direction.y)/texelSize.y)/stepSize;
	//get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
	float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z);
	vec3 stepv = direction/len;
	int iterations = min(int(min(len, mult*len)-2), maxSteps);
	//Do one iteration for closest texel (good contact shadows)
	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) + stepv/stepSize*6.0;
	spos.xy += TAA_Offset*texelSize*0.5*RENDER_SCALE;
	float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/texelSize/4),0).w/65000.0);
	float currZ = linZ(spos.z);

	if (sp < currZ) {
		float dist = abs(sp-currZ)/currZ;
		if (dist <= 0.035) return vec3(spos.xy, invLinZ(sp))/vec3(RENDER_SCALE,1.0);
	}

	stepv *= vec3(RENDER_SCALE, 1.0);
	spos += stepv*noise;

	for (int i = 0; i < iterations; i++) {
		float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/texelSize/4),0).w/65000.0);
		float currZ = linZ(spos.z);
		if (sp < currZ) {
			float dist = abs(sp-currZ)/currZ;
			if (dist <= 0.035) return vec3(spos.xy, invLinZ(sp))/vec3(RENDER_SCALE,1.0);
		}

		spos += stepv;
	}

	return vec3(1.1);
}

vec3 cosineHemisphereSample(vec2 Xi) {
    float r = sqrt(Xi.x);
    float theta = 2.0 * 3.14159265359 * Xi.y;

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

	for (int i = 0; i < RAY_COUNT; i++) {
		int seed = (frameCounter % 40000) * RAY_COUNT + i;
		vec2 ij = fract(R2_samples(seed) + noise.rg);

		vec3 rayDir = normalize(cosineHemisphereSample(ij));
		rayDir = TangentToWorld(normal, rayDir);

		vec3 rayHit = RT(mat3(gbufferModelView) * rayDir, fragpos, fract(seed/1.6180339887 + noise.b), mat3(gbufferModelView) * normal);

		if (rayHit.z < 1.0) {
			vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rayHit) + gbufferModelViewInverse[3].xyz + cameraPosition - previousCameraPosition;
			previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
			previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;

			if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0)
				intRadiance += texture2D(colortex5,previousPosition.xy).rgb + ambient*albedo*translucent;
			else
				intRadiance += ambient + ambient*translucent*albedo;

			occlusion += 1.0;
		}
		else {
		//	float bounceAmount = float(rayDir.y > 0.0) + clamp(-rayDir.y*0.1+0.1, 0.0,1.0);
			//vec3 sky_c = skyCloudsFromTex(rayDir,colortex4).rgb * bounceAmount;
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

	vec2 acc = -vec2(TAA_Offset) * texelSize * 0.5;
	float mult = (dot(normal,normalize(fragpos))+1.0)*0.5+0.5;

	vec2 v = fract(vec2(dither, R2_dither(gl_FragCoord.xy, frameCounter)) + (frameCounter % 10000) * vec2(0.75487765, 0.56984026));

	for (int j = 0; j < 7; j++) {
		vec2 sp = tapLocation_AO(j, v.x, 7, 88.0, v.y);
		vec2 sampleOffset = sp*rd;
		ivec2 offset = ivec2(gl_FragCoord.xy + sampleOffset * vec2(viewWidth, viewHeight * aspectRatio) * RENDER_SCALE);
		if (offset.x >= 0 && offset.y >= 0 && offset.x < viewWidth*RENDER_SCALE.x && offset.y < viewHeight*RENDER_SCALE.y ) {
			vec3 t0 = toScreenSpace(vec3(offset*texelSize+acc+0.5*texelSize,texelFetch2D(depthtex1,offset,0).x) * vec3(1.0/RENDER_SCALE, 1.0));

			vec3 vec = t0.xyz - fragpos;
			float dsquared = dot(vec,vec);
			if (dsquared > 1e-5){
				if (dsquared < maxR2){
					float NdotV = clamp(dot(vec*inversesqrt(dsquared), normalize(normal)),0.,1.);
					occlusion += NdotV * clamp(1.0-dsquared/maxR2,0.0,1.0);
				}
				n += 1.0;
			}
		}
	}

	occlusion = saturate(1.0 - occlusion/n*1.6);
	//occlusion = mult;
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

	float z0 = texture2D(depthtex0, texcoord).x;
	float z = texture2D(depthtex1, texcoord).x;

	vec2 tempOffset = TAA_Offset;

	float noise = blueNoise(gl_FragCoord.xy, frameCounter);

	vec3 fragpos = toScreenSpace(vec3(texcoord / RENDER_SCALE - vec2(tempOffset) * texelSize * 0.5, z));
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);

	// sky
	if (z >= 1.0) {
		vec3 color = vec3(0.0);
		vec4 cloud = texture2D_bicubic(colortex0, texcoord * CLOUDS_QUALITY);

		if (np3.y > 0.0) {
			color += stars(np3);
			color += drawSun(dot(lightCol.a * WsunVec, np3), 0, lightCol.rgb/150.0, vec3(0.0));
		}

		vec3 albedo = toLinear(texture(TEX_GB_COLOR, texcoord).rgb);
		color += skyFromTex(np3, colortex4)/150.0 + albedo/10.0 * 4.0*ffstep(0.985, -dot(lightCol.a * WsunVec, np3));
		color = color * cloud.a + cloud.rgb;

		outColor3 = clamp(fp10Dither(color * 8.0/3.0, triangularize(noise)), 0.0, 65000.0);

		//if (outColor3.r > 65000.) outColor3 = vec3(0.0);
		vec4 trpData = texture2D(colortex7, texcoord);

		if (trpData.a > 0.99) {
			vec3 fragpos0 = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z0));
			float Vdiff = distance(fragpos,fragpos0);
			float VdotU = np3.y;
			float estimatedDepth = Vdiff * abs(VdotU);	//assuming water plane
			float estimatedSunDepth = estimatedDepth/abs(refractedSunVec.y); //assuming water plane

			vec3 lightColVol = lightCol.rgb * (1.0-pow(1.0-WsunVec.y,5.0));	//fresnel
			vec3 ambientColVol = ambientUp*8./150./3.*0.5 * eyeBrightnessSmooth.y / 240.0;

			if (isEyeInWater == 0)
				waterVolumetrics(outColor3, fragpos0, fragpos, estimatedDepth, estimatedSunDepth, Vdiff, noise, totEpsilon, scatterCoef, ambientColVol, lightColVol, dot(np3, WsunVec));
		}
	}
	// land
	else {
		p3 += gbufferModelViewInverse[3].xyz;

		vec4 trpData = texture2D(colortex7, texcoord);
		bool iswater = texture2D(colortex7, texcoord).a > 0.99;

		vec4 color = texture(TEX_GB_COLOR, texcoord);
		vec3 albedo = toLinear(color.rgb);

		vec4 normalData = texture(TEX_GB_NORMAL, texcoord);
		vec3 geo_normal = mat3(gbufferModelViewInverse) * OctDecode(normalData.xy);
		vec3 tex_normal = mat3(gbufferModelViewInverse) * OctDecode(normalData.zw);
		vec3 normal = tex_normal;

		vec4 specularData = texture(TEX_GB_SPECULAR, texcoord);
		float emissive = specularData.a;

		vec4 worldData = texture(TEX_GB_WORLD, texcoord);
		vec2 lightmap = worldData.xy;

		bool hand = false;

//		bool hand = abs(dataUnpacked1.w-0.75) < 0.01;
//		bool emissive = abs(dataUnpacked1.w-0.9) < 0.01;

		float NdotLGeom = dot(normal, WsunVec);
		float NdotL = NdotLGeom;

		if ((iswater && isEyeInWater == 0) || (!iswater && isEyeInWater == 1))
			NdotL = dot(normal, refractedSunVec);

		float diffuseSun = saturate(NdotL);
		vec3 filtered = vec3(1.412, 1.0, 0.0);

		if (!hand) {
			filtered = texture2D(colortex3, texcoord).rgb;
		}

		float shading = 1.0 - filtered.b;
		float pShadow = filtered.b * 2.0 - 1.0;

		#ifdef SHADOW_COLORED
			vec3 shadowColor = vec3(0.0);
		#endif

		vec3 SSS = vec3(0.0);
		float sssAmount = specularData.b;

		#ifdef Variable_Penumbra_Shadows
			// compute shadows only if not backfacing the sun
			// or if the blocker search was full or empty
			// always compute all shadows at close range where artifacts may be more visible
			if (diffuseSun > 0.001)
		#else
			if (sssAmount > 0.5) {
				diffuseSun = mix(max(phaseg(dot(np3, WsunVec), 0.5), 2.0 * phaseg(dot(np3, WsunVec), 0.1)) * PI*1.6, diffuseSun, 0.3);
			}

			if (diffuseSun > 0.000)
		#endif
		{
			vec3 projectedShadowPosition = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
			projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

			// apply distortion
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;

			// do shadows only if on shadow map
			if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0){
				float rdMul = filtered.x * distortFactor * shadow_d0 * shadow_k / shadowMapResolution;
				const float threshMul = max(2048.0 / shadowMapResolution * shadowDistance/128.0, 0.95);
				float distortThresh = (sqrt(1.0-NdotLGeom*NdotLGeom)/NdotLGeom+0.7)/distortFactor;

				#ifdef Variable_Penumbra_Shadows
					float diffthresh = distortThresh/6000.0 * threshMul;
				#else
					float diffthresh = sss > 0.0 ? 0.0001 : distortThresh/6000.0 * threshMul;
				#endif

				#ifdef POM
					#ifdef Depth_Write_POM
						diffthresh += POM_DEPTH / 128.0/4.0/6.0;
					#endif
				#endif

				projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5);

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

						shadowColor += toLinear(sampleColor.rgb) * isShadow;
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
				float scattering = clamp((0.7+0.3*PI*phaseg(dot(np3, WsunVec),0.85))*1.5/4.0*sssAmount,0.0,1.0);
				SSS *= scattering;
				shading *= 1.0 - sssAmount;
				SSS *= sqrt(lightmap.y);
			}

			if (sssAmount > 0.2) {
//				sssAmount = 0.2;
				vec3 extinction = 1.0 - albedo*0.85;
				// Should be somewhat energy conserving
				SSS = exp(-filtered.y*11.0*extinction) + 3.0*exp(-filtered.y*11./3.*extinction);
				float scattering = clamp((0.7+0.3*PI*phaseg(dot(np3, WsunVec),0.85))*1.26/4.0*sssAmount,0.0,1.0);
				SSS *= scattering;
				shading *= 1.0 - sssAmount;
				SSS *= sqrt(lightmap.y);
			}
		#endif

		if ((diffuseSun*shading > 0.001 || abs(filtered.y-0.1) < 0.0004) && !hand) {
			#ifdef SCREENSPACE_CONTACT_SHADOWS
				vec3 vec = lightCol.a*sunVec;
				float screenShadow = rayTraceShadow(vec,fragpos,noise);
				shading = min(screenShadow, shading);
				// Out of shadow map
				if (abs(filtered.y-0.1) < 0.0004)
					SSS *= screenShadow;
			#endif

			#ifdef CAVE_LIGHT_LEAK_FIX
				shading = mix(0.0, shading, saturate(eyeBrightnessSmooth.y/255.0 + lightmap.y));
			#endif
		}

		#ifdef CLOUDS_SHADOWS
			vec3 pos = p3 + cameraPosition;
			const int rayMarchSteps = 6;
			float cloudShadow = 0.0;

			for (int i = 0; i < rayMarchSteps; i++){
				vec3 cloudPos = pos + WsunVec/abs(WsunVec.y)*(1500+(noise+i)/rayMarchSteps*1700-pos.y);
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

		#ifdef PHOTONICS_GI_ENABLED
//			vec3 ambientLight = texture(texPhotonicsIndirect, texcoord).rgb;
			vec3 ambientLight = vec3(0.0);
		#else
			vec3 ambientCoefs = normal / dot(abs(normal), vec3(1.0));
			vec3 ambientLight = ambientUp * mix(saturate(ambientCoefs.y), 1.0/6.0, sssAmount);
			ambientLight += ambientDown * mix(saturate(-ambientCoefs.y), 1.0/6.0, sssAmount);
			ambientLight += ambientRight * mix(saturate(ambientCoefs.x), 1.0/6.0, sssAmount);
			ambientLight += ambientLeft * mix(saturate(-ambientCoefs.x), 1.0/6.0, sssAmount);
			ambientLight += ambientB * mix(saturate(ambientCoefs.z), 1.0/6.0, sssAmount);
			ambientLight += ambientF * mix(saturate(-ambientCoefs.z), 1.0/6.0, sssAmount);
		#endif

		vec3 skyDirectLight = lightCol.rgb;

		#ifdef PHOTONICS_BLOCK_LIGHT_ENABLED
			vec3 custom_lightmap = vec3(0.0);
		#else
			vec3 custom_lightmap = texture2D(colortex4, (lightmap * 15.0 + 0.5 + vec2(0.0, 19.0)) * texelSize).rgb * 8.0 / 150.0 / 3.0;
		#endif

		float emitting = 0.0;

//		emitting = luma(albedo) * 3.0 * Emissive_Strength;
		emitting = emissive*emissive * 5.0 * Emissive_Strength;

		if (hand && heldBlockLightValue > 0.1) {
			custom_lightmap.y = 0.0;
		}

		vec3 fragpos0;
		float Vdiff;
		float estimatedDepth;
		float estimatedSunDepth;
		if (iswater != (isEyeInWater == 1)) {
			fragpos0 = toScreenSpace(vec3(texcoord / RENDER_SCALE - vec2(tempOffset) * texelSize * 0.5, z0));
			Vdiff = distance(fragpos, fragpos0);
			float VdotU = np3.y;
			estimatedDepth = Vdiff * abs(VdotU);	//assuming water plane

			if (isEyeInWater == 1) {
				Vdiff = length(fragpos);
				estimatedDepth = saturate((15.5 - lightmap.y * 16.0) / 15.5);
				estimatedDepth *= estimatedDepth * estimatedDepth * 32.0;

				#ifndef lightMapDepthEstimation
					estimatedDepth = max(Water_Top_Layer - (cameraPosition.y + p3.y), 0.0);
				#endif
			}

			// k = 1-r*r*(1-sy*sy)
			estimatedSunDepth = estimatedDepth/abs(refractedSunVec.y); //assuming water plane
			skyDirectLight *= exp(-totEpsilon * estimatedSunDepth) * (1.0 - pow(1.0 - WsunVec.y, 5.0));

			vec3 worldPos = toWorldSpaceCamera(fragpos);
			float caustics = waterCaustics(worldPos, refractedSunVec);
			skyDirectLight *= mix(caustics * 0.5 + 0.5, 1.0, exp(estimatedSunDepth / -3.0));

			if (isEyeInWater == 0) {
				ambientLight *= min(exp(-totEpsilon * estimatedDepth), custom_lightmap.x);
				ambientLight += custom_lightmap.z;
			}
			else {
				ambientLight += 10.0 * exp(totEpsilon * -8.0);
				ambientLight *= exp(-totEpsilon * estimatedDepth) * 8.0/150.0/3.0;
			}

			ambientLight *= mix(caustics, 1.0, 0.85);
			ambientLight += custom_lightmap.y * TorchColor;

			#ifdef SSGI
				float ao = 1.0;
				if (!hand) ssao(ao, fragpos, 1.0, noise, decode(dataUnpacked0.yw));
				ambientLight *= ao;
			#endif
		}
		else {
			#ifdef SSGI
				if (!hand)
					ambientLight = rtGI(normal, blueNoise(gl_FragCoord.xy), fragpos, ambientLight * custom_lightmap.x, sssAmount, custom_lightmap.z * vec3(0.9, 1.0, 1.5) + custom_lightmap.y * TorchColor, normalize(albedo + 1.e-5) * 0.7);
				else
					ambientLight = ambientLight * custom_lightmap.x + custom_lightmap.z * vec3(0.9, 1.0, 1.5) + custom_lightmap.y * TorchColor;
			#else
					ambientLight = ambientLight * custom_lightmap.x + custom_lightmap.z * vec3(0.9, 1.0, 1.5) + custom_lightmap.y * TorchColor;
			#endif
		}

		// combine all light sources
		vec3 skyLightFinal = vec3(shading * diffuseSun);
		#ifdef SHADOW_COLORED
			skyLightFinal *= shadowColor;
		#endif
		skyLightFinal += SSS;

		outColor3 = (skyLightFinal/PI * 8.0/150.0/3.0 * skyDirectLight + ambientLight + directLighting + emitting) * albedo;

		if (iswater != (isEyeInWater == 1)) {
			// Bruteforce integration is probably overkill
			vec3 lightColVol = lightCol.rgb * (1.0 - pow(1.0 - WsunVec.y, 5.0));	//fresnel
			vec3 ambientColVol = ambientUp * 8.0/150.0/3.0 * 0.5 * eyeBrightnessSmooth.y/240.0;

			if (isEyeInWater == 0)
				waterVolumetrics(outColor3, fragpos0, fragpos, estimatedDepth, estimatedSunDepth, Vdiff, noise, totEpsilon, scatterCoef, ambientColVol, lightColVol, dot(np3, WsunVec));
		}
	}
}
