#include "/lib/common.glsl"
#include "/lib/settings.glsl"


// TODO: UNDEFINED!
const float skyIntensity = 0.0;
const float skyIntensityNight = 0.0;
const vec3 nsunColor = vec3(0.0);

#include "/lib/blocks.glsl"

#include "/lib/ign.glsl"
#include "/lib/ggx.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/shadowSampling.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/clouds.glsl"
#include "/lib/stars.glsl"


vec3 toScreenSpace(const in vec3 p) {
	vec4 iProjDiag = vec4(vxProjInv[0].x, vxProjInv[1].y, vxProjInv[2].zw);
	vec3 p3 = p * 2.0 - 1.0;
	vec4 fragposition = iProjDiag * p3.xyzz + vxProjInv[3];
	return fragposition.xyz / fragposition.w;
}

vec3 toClipSpace3(const in vec3 viewSpacePosition) {
	return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 rayTrace(vec3 dir, vec3 position, float dither, float fresnel) {
    float quality = mix(15, REFLECTION_QUALITY, fresnel);
    vec3 clipPosition = toClipSpace3(position);

	float rayLength = ((position.z + dir.z * farPlane*sqrt(3.0)) > -nearPlane) ?
       (-nearPlane -position.z) / dir.z : farPlane*sqrt(3.0);

    vec3 direction = normalize(toClipSpace3(dir*rayLength + position) - clipPosition);  //convert to clip space
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
		// voxy runs too early for 1/4 depth buffer, use full-res depth
		float sp = texelFetch(depthtex1, ivec2(spos.xy / texelSize), 0).r;
		if (sp <= max(maxZ, minZ) && sp >= min(maxZ, minZ)) {
			return vec3(spos.xy / RENDER_SCALE, sp);
		}

		spos += stepv;

		// small bias
		minZ = maxZ - 0.00004 / linZ(spos.z, near, far);
		maxZ += stepv.z;
    }

    return vec3(1.1);
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

void voxy_emitFragment(VoxyFragmentParameters parameters) {
	if (!all(lessThan(gl_FragCoord.xy * texelSize.xy, RENDER_SCALE_2))) return;

	vec2 tempOffset = taa_offsets[framemod8];

	float iswater = 0.0;
	if (parameters.customId == BLOCK_ICE) iswater = 0.50;
	if (parameters.customId == BLOCK_WATER) iswater = 1.00;
	if (parameters.customId == BLOCK_REFLECTIVE) iswater = 0.01;

	vec3 fragC = gl_FragCoord.xyz * vec3(texelSize, 1.0);
	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz * vec3(texelSize / RENDER_SCALE, 1.0) - vec3(vec2(tempOffset) * texelSize * 0.5, 0.0));

	outColor2 = parameters.sampledColour * parameters.tinting;
	vec3 albedo = InputTransform(outColor2.rgb);

	if (iswater > 0.4) {
		albedo = vec3(0.42, 0.6, 0.7);
		outColor2 = vec4(0.42, 0.6, 0.7, 0.7);
	}

	if (iswater > 0.9) {
		outColor2 = vec4(0.0);
	}

	// TODO: normalize?
	vec2 lmcoord = parameters.lightMap;

	vec3 localNormal = vec3(
		uint((parameters.face >> 1) == 2),
		uint((parameters.face >> 1) == 0),
		uint((parameters.face >> 1) == 1)
	) * (float(int(parameters.face) & 1) * 2.0 - 1.0);

	vec3 p3 = mul3(vxModelViewInv, fragpos);

	if (iswater > 0.4) {
		float bumpmult = 1.0;
		if (iswater > 0.9) bumpmult = 1.0;

		float parallaxMult = bumpmult;

		vec3 posxz = p3 + cameraPosition;
		posxz.xz -= posxz.y;

		if (iswater < 0.9) posxz.xz *= 3.0;

		vec3 bump = normalize(getWaveHeight(posxz.xz, iswater));

		bump = bump * vec3(bumpmult) + vec3(0.0, 0.0, 1.0 - bumpmult);

		localNormal = TangentToWorld(localNormal, bump);
	}

	vec3 viewNormal = mat3(vxModelView) * localNormal;

	float NdotL = lightSign * dot(viewNormal, sunVec);
	float NdotU = dot(upVec, viewNormal);
	float diffuseSun = saturate(NdotL);

	vec3 direct = texelFetch(gaux1, ivec2(6, 37), 0).rgb / PI;

	float shading = 1.0;

	// compute shadows only if not backface
	if (diffuseSun > 0.001) {
		vec3 p3 = mul3(vxModelViewInv, fragpos);
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
			float noise = blueNoise(gl_FragCoord.xy, frameCounter);
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
	vec3 color = diffuseLight * albedo * 8.0 / 150.0 / 3.0;

	if (iswater > 0.0) {
		float f0 = iswater > 0.1 ? 0.02 : 0.05 * (1.0 - outColor2.a);

		float roughness = 0.02;
		float emissive = 0.0;
		float F0 = f0;

		vec3 reflectedVector = reflect(normalize(fragpos), viewNormal);
		float normalDotEye = dot(viewNormal, normalize(fragpos));
		float fresnel = pow(clamp(1.0 + normalDotEye, 0.0, 1.0), 5.0);
		fresnel = mix(F0, 1.0, fresnel);

		if (iswater > 0.4) {
			roughness = 0.1;
		}

		vec3 wrefl = mat3(vxModelViewInv) * reflectedVector;
		vec3 sky_c = mix(skyCloudsFromTex(wrefl, gaux1).rgb, texture(gaux1, (lmcoord * 15.0 + 0.5) * texelSize).rgb * 0.5, isEyeInWater);
		sky_c.rgb *= lmcoord.y * lmcoord.y * 255.0*255.0/240.0/240.0 / 150.0*8.0/3.0;

		vec4 reflection = vec4(sky_c.rgb, 0.0);
		#ifdef REFLECTION_ENABLED
			vec3 rtPos = rayTrace(reflectedVector, fragpos.xyz, blueNoise(gl_FragCoord.xy, frameCounter), fresnel);

			if (rtPos.z < 1.0) {
				vec3 previousPosition = mul3(vxModelViewInv, toScreenSpace(rtPos));
				previousPosition += cameraPosition - previousCameraPosition;
				previousPosition = mul3(gbufferPreviousModelView, previousPosition);

				previousPosition.xy = projMAD(vxProjPrev, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;

				if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
					reflection.rgb = texture(gaux2, previousPosition.xy).rgb;
					reflection.a = 1.0;
				}
			}
		#endif

		reflection.rgb = mix(sky_c.rgb, reflection.rgb, reflection.a);

		vec3 lightCol = texelFetch(gaux1, ivec2(6, 37), 0).rgb / PI;
		vec3 sunSpec = GGX(viewNormal, -normalize(fragpos), lightSign*sunVec, rainStrength*0.2 + roughness + 0.05+saturate(lightSign * -0.15), f0) * lightCol * 8.0/3.0/150.0;
		sunSpec *= 1.0 - 0.9*rainStrength;

		vec3 reflected = reflection.rgb * fresnel + shading * sunSpec;

		float alpha0 = outColor2.a;

		// correct alpha channel with fresnel
		outColor2.a = -outColor2.a * fresnel + outColor2.a + fresnel;
		outColor2.rgb = clamp(color/outColor2.a * alpha0 * (1.0 - fresnel) * 0.1+reflected/outColor2.a * 0.1, 0.0, 65100.0);

		if (outColor2.r > 65000.0) outColor2.rgba = vec4(0.0);
	}
	else {
		outColor2.rgb = color * 0.1;
	}

	outColor7 = vec4(albedo, iswater);
}
