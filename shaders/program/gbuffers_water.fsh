#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;
	vec3 binormal;
	vec3 tangent;
	vec3 viewVector;
//	float dist;
} vIn;

uniform sampler2D gtexture;
uniform sampler2D noisetex;
uniform sampler2D texBlueNoise;
uniform sampler2DShadow shadowtex0HW;
uniform sampler2D gaux2;
uniform sampler2D texWave;
uniform sampler2D gaux1;
uniform sampler2D depthtex1;

uniform vec4 lightCol;
uniform vec3 sunVec;
uniform float frameTimeCounter;
uniform float waveScale;
uniform float lightSign;
uniform float near;
uniform float far;
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
//uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;
uniform int isEyeInWater;
uniform int frameCounter;
uniform int framemod8;

#include "/lib/ign.glsl"
#include "/lib/ggx.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/projections.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/shadowSampling.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/clouds.glsl"
#include "/lib/stars.glsl"


float invLinZ(float lindepth) {
	return -((2.0*near/lindepth)-far-near)/(far-near);
}

vec3 nvec3(vec4 pos) {
    return pos.xyz / pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

vec3 rayTrace(vec3 dir,vec3 position,float dither, float fresnel) {
    float quality = mix(15,SSR_STEPS,fresnel);
    vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
       (-near -position.z) / dir.z : far*sqrt(3.);

    vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
    direction.xy = normalize(direction.xy);

    //get at which length the ray intersects with the edge of the screen
    vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
    float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z);

    vec3 stepv = direction * mult / quality * vec3(RENDER_SCALE_2, 1.0);

	vec3 spos = clipPosition * vec3(RENDER_SCALE_2, 1.0) + stepv*dither;
	float minZ = clipPosition.z;
	float maxZ = spos.z+stepv.z * 0.5;
	spos.xy += taa_offsets[framemod8] * texelSize * 0.5 / RENDER_SCALE;

    for (int i = 0; i <= int(quality); i++) {
		#ifdef USE_QUARTER_RES_DEPTH
			// decode depth buffer
			float sp = sqrt(texelFetch(gaux1, ivec2(spos.xy/texelSize/4), 0).w / 65000.0);
			sp = invLinZ(sp);

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
		minZ = maxZ - 0.00004 / linZ(spos.z, near, far);
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
	if (all(lessThan(gl_FragCoord.xy * texelSize.xy, RENDER_SCALE_2))) {
		vec2 tempOffset = taa_offsets[framemod8];
		float iswater = vIn.normalMat.w;

		vec3 fragC = gl_FragCoord.xyz * vec3(texelSize, 1.0);
		vec3 fragpos = toScreenSpace(gl_FragCoord.xyz * vec3(texelSize / RENDER_SCALE, 1.0) - vec3(vec2(tempOffset) * texelSize * 0.5, 0.0));

		float avgBlockLum = luma(textureLod(gtexture, vIn.lmtexcoord.xy, 128).rgb * vIn.color.rgb);

		outColor2 = texture(gtexture, vIn.lmtexcoord.xy) * vIn.color;
		outColor2.rgb = saturate(outColor2.rgb * pow(avgBlockLum, -0.33) * 0.85);
		vec3 albedo = toLinear(outColor2.rgb);

		if (iswater > 0.4) {
			albedo = vec3(0.42, 0.6, 0.7);
			outColor2 = vec4(0.42, 0.6, 0.7, 0.7);
		}

		if (iswater > 0.9) {
			outColor2 = vec4(0.0);
		}

		vec3 normal = vIn.normalMat.xyz;

		vec3 p3 = mul3(gbufferModelViewInverse, fragpos);

		mat3 tbnMatrix = mat3(
			vIn.tangent.x, vIn.binormal.x, normal.x,
			vIn.tangent.y, vIn.binormal.y, normal.y,
			vIn.tangent.z, vIn.binormal.z, normal.z);

		if (iswater > 0.4) {
			float bumpmult = 1.0;
			if (iswater > 0.9) bumpmult = 1.0;

			float parallaxMult = bumpmult;

			vec3 posxz = p3 + cameraPosition;
			posxz.xz -= posxz.y;

			if (iswater < 0.9) posxz.xz *= 3.0;

			posxz.xyz = getParallaxDisplacement(posxz, iswater, bumpmult, normalize(tbnMatrix * fragpos));

			vec3 bump = normalize(getWaveHeight(posxz.xz, iswater));

			bump = bump * vec3(bumpmult) + vec3(0.0, 0.0, 1.0 - bumpmult);

			normal = normalize(bump * tbnMatrix);
		}

		float NdotL = lightSign * dot(normal, sunVec);
		float NdotU = dot(upVec, normal);
		float diffuseSun = saturate(NdotL);

		vec3 direct = texelFetch(gaux1, ivec2(6, 37), 0).rgb / PI;

		float shading = 1.0;

		//compute shadows only if not backface
		if (diffuseSun > 0.001) {
			vec3 p3 = mul3(gbufferModelViewInverse, fragpos);
			vec3 projectedShadowPosition = mul3(shadowModelView, p3);
			projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

			//apply distortion
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;

			//do shadows only if on shadow map
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

		direct *= (iswater > 0.9 ? 0.2 : 1.0) * diffuseSun * vIn.lmtexcoord.w;

		vec3 diffuseLight = direct + texture(gaux1, (vIn.lmtexcoord.zw * 15.0 + 0.5) * texelSize).rgb;
		vec3 color = diffuseLight * albedo * 8.0 / 150.0 / 3.0;

		if (iswater > 0.0) {
			float f0 = iswater > 0.1 ? 0.02 : 0.05 * (1.0 - outColor2.a);

			float roughness = 0.02;
			float emissive = 0.0;
			float F0 = f0;

			vec3 reflectedVector = reflect(normalize(fragpos), normal);
			float normalDotEye = dot(normal, normalize(fragpos));
			float fresnel = pow(clamp(1.0 + normalDotEye, 0.0, 1.0), 5.0);
			fresnel = mix(F0, 1.0, fresnel);

			if (iswater > 0.4) {
				roughness = 0.1;
			}

			vec3 wrefl = mat3(gbufferModelViewInverse) * reflectedVector;
			vec3 sky_c = mix(skyCloudsFromTex(wrefl, gaux1).rgb, texture(gaux1, (vIn.lmtexcoord.zw * 15.0 + 0.5) * texelSize).rgb * 0.5, isEyeInWater);
			sky_c.rgb *= vIn.lmtexcoord.w * vIn.lmtexcoord.w * 255.0*255.0/240.0/240.0 / 150.0*8.0/3.0;

			vec4 reflection = vec4(sky_c.rgb, 0.0);
			#ifdef SCREENSPACE_REFLECTIONS
				vec3 rtPos = rayTrace(reflectedVector, fragpos.xyz, blueNoise(gl_FragCoord.xy, frameCounter), fresnel);

				if (rtPos.z < 1.0) {
					vec3 previousPosition = mul3(gbufferModelViewInverse, toScreenSpace(rtPos));
					previousPosition += cameraPosition - previousCameraPosition;
					previousPosition = mul3(gbufferPreviousModelView, previousPosition);
					previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;

					if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
						reflection.rgb = texture(gaux2, previousPosition.xy).rgb;
						reflection.a = 1.0;
					}
				}
			#endif

			reflection.rgb = mix(sky_c.rgb, reflection.rgb, reflection.a);

			vec3 lightCol2 = texelFetch(gaux1, ivec2(6, 37), 0).rgb / PI;
			#ifdef SUN_MICROFACET_SPECULAR
				vec3 sunSpec = GGX(normal, -normalize(fragpos), lightSign*sunVec, rainStrength*0.2 + roughness + 0.05+saturate(lightSign * -0.15), f0) * lightCol2 * 8.0/3.0/150.0;
			#else
				vec3 sunSpec = drawSun(dot(lightSign * sunVec, reflectedVector), 0.0, lightCol2, vec3(0.0)) * fresnel * 8.0/3.0/150.0;
			#endif
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
}
