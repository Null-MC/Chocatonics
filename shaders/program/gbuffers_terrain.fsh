#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec3 normalMat;
	flat int blockId;

	#ifdef MAT_PARALLAX_ENABLED
		vec4 vtexcoordam; // .st for add, .pq for mul
		vec4 vtexcoord;
	#endif

	#ifdef MAT_PBR_ENABLED
		vec4 tangent;
	#endif
} vIn;

uniform sampler2D gtexture;
uniform sampler2D noisetex;

#ifdef MAT_PBR_ENABLED
	uniform sampler2D normals;
	uniform sampler2D specular;
#else
	uniform usampler2D texBlockMeta;
#endif

uniform vec2 texelSize;
uniform float rainStrength;
uniform float rainWetness;
uniform float alphaTestRef;
uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform int framemod8;

//#ifdef MAT_PBR_ENABLED
//	uniform float wetness;
//#endif

#include "/lib/blocks.glsl"

#include "/lib/ign.glsl"
#include "/lib/material.glsl"
#include "/lib/octohedral.glsl"
#include "/lib/projections.glsl"
#include "/lib/color_transforms.glsl"

#ifdef MAT_PBR_ENABLED
	#include "/lib/normal_map.glsl"
#else
	#include "/lib/blockMeta.glsl"
#endif


const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;

const float MIX_OCCLUSION_DISTANCE = MAT_PARALLAX_MAX_DIST * 0.9;

#ifdef MAT_PARALLAX_ENABLED
	vec2 dcdx = dFdx(vIn.vtexcoord.st * vIn.vtexcoordam.pq) * exp2(Texture_MipMap_Bias);
	vec2 dcdy = dFdy(vIn.vtexcoord.st * vIn.vtexcoordam.pq) * exp2(Texture_MipMap_Bias);

	vec4 readNormal(in vec2 coord) {
		return textureGrad(normals, fract(coord) * vIn.vtexcoordam.pq + vIn.vtexcoordam.st, dcdx, dcdy);
	}

	vec4 readTexture(in vec2 coord) {
		return textureGrad(gtexture, fract(coord) * vIn.vtexcoordam.pq + vIn.vtexcoordam.st, dcdx, dcdy);
	}
#endif


/* RENDERTARGETS: 8,9,10,11 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outSpecular;
layout(location = 3) out vec4 outWorld;

void main() {
	float noise = IGN_time(frameTimeCounter);
	vec3 normal = vIn.normalMat;

	#ifdef MAT_PBR_ENABLED
		vec3 tangent2 = normalize(cross(vIn.tangent.rgb, normal) * vIn.tangent.w);

		mat3 tbnMatrix = mat3(
			vIn.tangent.x, tangent2.x, normal.x,
			vIn.tangent.y, tangent2.y, normal.y,
			vIn.tangent.z, tangent2.z, normal.z);
	#endif

	vec2 taa_offset = taa_offsets[framemod8];
	vec3 viewPos = toScreenSpace(gl_FragCoord.xyz * vec3(texelSize / RENDER_SCALE, 1.0) - vec3(taa_offset * texelSize * 0.5, 0.0));

	float wetness = 0.0;
	if (rainStrength > 0.0 || rainWetness > 0.0) {
		vec3 localPos = mul3(gbufferModelViewInverse, viewPos);

		vec3 localNormal = mat3(gbufferModelViewInverse) * normal;
		float skyExposure = smoothstep((13.5/15.0), (14.5/15.0), vIn.lmtexcoord.w);
		float wetnessF = saturate(localNormal.y); //saturate(unmix(-0.4, 0.1, localTexNormal.y));

		vec2 texcoord = localPos.xz + cameraPosition.xz;
		float puddleF = smoothstep(0.06, 0.24, rainWetness * texture(noisetex, texcoord*0.05).g);

		wetness = skyExposure * max(rainStrength * wetnessF * 0.6, puddleF);
	}

	#ifdef MAT_PARALLAX_ENABLED
//		vec2 taa_offset = taa_offsets[framemod8];
		vec2 adjustedTexCoord = fract(vIn.vtexcoord.st) * vIn.vtexcoordam.pq + vIn.vtexcoordam.st;
//		vec3 viewPos = toScreenSpace(gl_FragCoord.xyz * vec3(texelSize/RENDER_SCALE, 1.0) - vec3(taa_offset*texelSize*0.5, 0.0));
		vec3 viewVector = normalize(tbnMatrix * viewPos);
		float dist = length(viewPos);

		#ifdef MAT_PARALLAX_DEPTH_WRITE
			gl_FragDepth = gl_FragCoord.z;
		#endif

		if (dist < MAT_PARALLAX_MAX_DIST) {
  			#ifndef MAT_PARALLAX_GENERATED
				if (viewVector.z < 0.0 && readNormal(vIn.vtexcoord.st).a < 0.9999 && readNormal(vIn.vtexcoord.st).a > 0.00001) {
					vec3 interval = viewVector.xyz / -viewVector.z / MAT_PARALLAX_ITERATIONS * Parallax_Depth;
					vec3 coord = vec3(vIn.vtexcoord.st, 1.0);

					coord += noise*interval;
					float sumVec = noise;

					for (int loopCount = 0; (loopCount < MAT_PARALLAX_ITERATIONS) && (1.0 - Parallax_Depth + Parallax_Depth*readNormal(coord.st).a < coord.p) &&coord.p >= 0.0; ++loopCount) {
						coord = coord+interval;
						sumVec += 1.0;
					}

					if (coord.t < mincoord) {
						if (readTexture(vec2(coord.s, mincoord)).a < alphaTestRef) {
							coord.t = mincoord;
							discard;
						}
					}

					adjustedTexCoord = mix(fract(coord.st) * vIn.vtexcoordam.pq + vIn.vtexcoordam.st, adjustedTexCoord, max(dist - MIX_OCCLUSION_DISTANCE, 0.0) / (MAT_PARALLAX_MAX_DIST-MIX_OCCLUSION_DISTANCE));

					vec3 truePos = viewPos + sumVec * inverse(tbnMatrix) * interval;

					#ifdef MAT_PARALLAX_DEPTH_WRITE
						gl_FragDepth = toClipSpace3(truePos).z;
					#endif
				}
  			#else
				if (viewVector.z < 0.0) {
					vec3 interval = viewVector.xyz / -viewVector.z / MAT_PARALLAX_ITERATIONS * Parallax_Depth;
					vec3 coord = vec3(vIn.vtexcoord.st, 1.0);
					coord += noise*interval;
					float sumVec = noise;
					float lum0 = luma(textureLod(gtexture, vIn.lmtexcoord.xy, 100).rgb);

					for (int loopCount = 0; (loopCount < MAT_PARALLAX_ITERATIONS) && (1.0 - Parallax_Depth + Parallax_Depth*luma(readTexture(coord.st).rgb)/lum0*0.5 < coord.p) && coord.p >= 0.0; ++loopCount) {
						 coord = coord+interval;
						 sumVec += 1.0;
					}

					if (coord.t < mincoord) {
						if (readTexture(vec2(coord.s, mincoord)).a < alphaTestRef) {
							coord.t = mincoord;
							discard;
						}
					}

					adjustedTexCoord = mix(fract(coord.st) * vIn.vtexcoordam.pq + vIn.vtexcoordam.st, adjustedTexCoord, max(dist - MIX_OCCLUSION_DISTANCE, 0.0) / (MAT_PARALLAX_MAX_DIST - MIX_OCCLUSION_DISTANCE));

					vec3 truePos = viewPos + sumVec * inverse(tbnMatrix) * interval;

					#ifdef MAT_PARALLAX_DEPTH_WRITE
						gl_FragDepth = toClipSpace3(truePos).z;
					#endif
				}
			#endif
		}

		vec4 color = textureGrad(gtexture, adjustedTexCoord.xy, dcdx, dcdy);
		#ifdef DISABLE_ALPHA_MIPMAPS
			color.a = textureGrad(gtexture, adjustedTexCoord.xy, vec2(0.0), vec2(0.0)).a;
		#endif

		color.rgb *= vIn.color.rgb;

		vec4 normalData = textureGrad(normals, adjustedTexCoord.xy, dcdx, dcdy);
		#ifdef MAT_PBR_ENABLED
			vec4 specularData = textureGrad(specular, adjustedTexCoord.xy, dcdx, dcdy);
		#endif
	#else
		vec4 color = texture(gtexture, vIn.lmtexcoord.xy, Texture_MipMap_Bias);
		color.rgb *= vIn.color.rgb;

		#ifdef DISABLE_ALPHA_MIPMAPS
			color.a = textureLod(gtexture, vIn.lmtexcoord.xy, 0).a;
		#endif

		#ifdef MAT_PBR_ENABLED
			vec4 normalData = texture(normals, vIn.lmtexcoord.xy, Texture_MipMap_Bias);
			vec4 specularData = texture(specular, vIn.lmtexcoord.xy, Texture_MipMap_Bias);
		#endif
	#endif

	if (color.a < alphaTestRef) discard;

	#ifdef MAT_PBR_ENABLED
		vec3 tex_normal = mat_normal(normalData.rgb);
		normal = applyBump(tbnMatrix, tex_normal, wetness);
	#endif

	#ifdef MAT_SPECULAR_ENABLED
		float smoothness = specularData.r;
		float f0 = specularData.g;
		float sss = mat_sss(specularData.b);
		float porosity = mat_porosity(specularData.rgb);
		float emission = mat_emission(specularData);

		if (f0 < EPSILON) f0 = 0.04;
	#else
		float smoothness = 0.0;
		float f0 = 0.04;
		float emission = 0.0;
		float porosity = 0.85;
		float sss = 0.0;

		uint blockMeta = SampleBlockMeta(vIn.blockId);

		if (hasBit(blockMeta, BIT_REFLECTIVE)) {
			smoothness = 0.98;
			f0 = 0.05;
		}

		if (hasBit(blockMeta, BIT_SSS_HIGH)) {
			sss = 0.5;
		}

		if (hasBit(blockMeta, BIT_SSS_LOW)) {
			sss = 0.2;
		}

		if (hasBit(blockMeta, BIT_EMISSIVE)) {
			emission = saturate(luma(toLinear(color.rgb)));
			emission = pow(emission, 1.4);
//			vOut.color.rgb = normalize(vOut.color.rgb) * sqrt(3.0);
		}
	#endif

	if (wetness > 0.0) {
		vec3 albedo = toLinear(color.rgb) * (1.0 - 0.5 * wetness * porosity);
		albedo *= exp(-2.0 * wetness * porosity * (1.0 - albedo));
//		albedo *= (1.0 - 0.4 * wetness * porosity);

		smoothness = mix(smoothness, 1.0, smoothstep(0.0, 1.0, wetness));
		color.rgb = linearToSRGB(albedo);
	}

	const float mat = 0.0;

	outColor = color;
	outNormal = vec4(OctEncode(vIn.normalMat.xyz), OctEncode(normal));
	outSpecular = vec4(smoothness, f0, sss, emission);
	outWorld = vec4(vIn.lmtexcoord.zw, 0.0, mat);
}
