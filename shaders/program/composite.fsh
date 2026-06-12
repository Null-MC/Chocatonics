#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


flat varying vec3 WsunVec;
flat varying vec2 TAA_Offset;

uniform sampler2D TEX_GB_NORMAL;
uniform sampler2D TEX_GB_SPECULAR;
uniform sampler2D TEX_GB_WORLD;
uniform sampler2D depthtex1;
//uniform sampler2D colortex1;
uniform sampler2D shadowtex0;
uniform sampler2D noisetex;
//uniform sampler2D texBlueNoise;

uniform vec3 sunVec;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int frameCounter;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform float viewWidth;
uniform float aspectRatio;
uniform float viewHeight;
uniform float far;
uniform float near;

#include "/lib/ign.glsl"
#include "/lib/decode.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/octohedral.glsl"
#include "/lib/projections.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/shadowSampling.glsl"


/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor3;

void main() {
	vec2 texcoord = gl_FragCoord.xy * texelSize;

	outColor3 = vec4(Min_Shadow_Filter_Radius, 0.1, 0.0, 0.0);

	float z = texture2D(depthtex1, texcoord).x;
	vec2 tempOffset = TAA_Offset;

	if (z < 1.0) {
		vec4 normalData = texture(TEX_GB_NORMAL, texcoord);
		vec3 normal = mat3(gbufferModelViewInverse) * OctDecode(normalData.xy);

		vec4 specularData = texture(TEX_GB_SPECULAR, texcoord);
		float sss = specularData.b;

		vec4 worldData = texture(TEX_GB_WORLD, texcoord);
		vec2 lightmap = worldData.xy;

//		bool hand = abs(dataUnpacked1.w-0.75) < 0.01;
		bool hand = false;

		if (!hand) {
			float NdotL = saturate(dot(normal, WsunVec));
			float bn = blueNoise(gl_FragCoord.xy).a;
			float noise = fract(bn + frameCounter/1.6180339887);
			vec3 fragpos = toScreenSpace(vec3(texcoord/RENDER_SCALE - vec2(tempOffset)*texelSize*0.5, z));

			#ifdef Variable_Penumbra_Shadows
				if (NdotL > 0.001 || sss > 0.001) {
					vec3 p3 = toWorldSpace(fragpos);
					vec3 projectedShadowPosition = mul3(shadowModelView, p3);
					projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

					// apply distortion
					float distortFactor = calcDistort(projectedShadowPosition.xy);
					projectedShadowPosition.xy *= distortFactor;

					// do shadows only if on shadow map
					if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0){
						const float threshMul = max(2048.0/shadowMapResolution*shadowDistance/128.0,0.95);
						float distortThresh = (sqrt(1.0-NdotL*NdotL)/NdotL+0.7)/distortFactor;
						float diffthresh = distortThresh/6000.0*threshMul;
						projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5);

						const float mult = Max_Shadow_Filter_Radius;
						float avgBlockerDepth = 0.0;
						vec2 scales = vec2(0.0,Max_Filter_Depth);
						float blockerCount = 0.0;
						float rdMul = distortFactor * (1.0+mult)*shadow_d0*shadow_k/shadowMapResolution;
						float diffthreshM = diffthresh*mult*shadow_d0*shadow_k/20.0;
						float avgDepth = 0.0;

						for (int i = 0; i < VPS_Search_Samples; i++) {
							vec2 offsetS = tapLocation_Shadow(i, VPS_Search_Samples, 84.0, noise);
							float weight = 3.0 + (i+noise) *rdMul/SHADOW_FILTER_SAMPLE_COUNT*shadowMapResolution*distortFactor/2.7;
							float d = texelFetch(shadowtex0, ivec2((projectedShadowPosition.xy + offsetS * rdMul) * shadowMapResolution), 0).x;
							float b = smoothstep(weight * diffthresh / 2.0, weight * diffthresh, projectedShadowPosition.z - d);

							blockerCount += b;
							avgDepth += max(projectedShadowPosition.z - d, 0.0) * 1000.0;
							avgBlockerDepth += d * b;
						}

						outColor3.g = avgDepth / VPS_Search_Samples;
						outColor3.b = blockerCount / VPS_Search_Samples;

						if (blockerCount >= 0.9) {
							avgBlockerDepth /= blockerCount;
							float ssample = max(projectedShadowPosition.z - avgBlockerDepth, 0.0) * 1500.0;
							outColor3.r = clamp(ssample, scales.x, scales.y) / scales.y * (mult - Min_Shadow_Filter_Radius) + Min_Shadow_Filter_Radius;
						}
					}
				}
			#endif
		}
	}
}
