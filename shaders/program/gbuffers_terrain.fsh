#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;

	#ifdef MAT_PARALLAX_ENABLED
		vec4 vtexcoordam; // .st for add, .pq for mul
		vec4 vtexcoord;
	#endif

	#ifdef MC_NORMAL_MAP
		vec4 tangent;
	#endif
} vIn;

uniform sampler2D gtexture;

#ifdef MC_NORMAL_MAP
	uniform sampler2D normals;
#endif

#ifdef MC_TEXTURE_FORMAT_LAB_PBR
	uniform sampler2D specular;
#endif

uniform vec2 texelSize;
uniform float alphaTestRef;
uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;

#ifdef MAT_PARALLAX_ENABLED
	uniform int framemod8;
#endif

#ifdef MC_NORMAL_MAP
	uniform float wetness;
#endif

#include "/lib/ign.glsl"
#include "/lib/material.glsl"
#include "/lib/octohedral.glsl"
#include "/lib/projections.glsl"


const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;

const float MIX_OCCLUSION_DISTANCE = MAT_PARALLAX_MAX_DIST * 0.9;

#ifdef MAT_PARALLAX_ENABLED
	vec2 dcdx = dFdx(vIn.vtexcoord.st * vIn.vtexcoordam.pq) * exp2(Texture_MipMap_Bias);
	vec2 dcdy = dFdy(vIn.vtexcoord.st * vIn.vtexcoordam.pq) * exp2(Texture_MipMap_Bias);
#endif

mat3 inverse(mat3 m) {
	float a00 = m[0][0], a01 = m[0][1], a02 = m[0][2];
	float a10 = m[1][0], a11 = m[1][1], a12 = m[1][2];
	float a20 = m[2][0], a21 = m[2][1], a22 = m[2][2];

	float b01 = a22 * a11 - a12 * a21;
	float b11 = -a22 * a10 + a12 * a20;
	float b21 = a21 * a10 - a11 * a20;

	float det = a00 * b01 + a01 * b11 + a02 * b21;

	return mat3(
		b01, (-a22 * a01 + a02 * a21), (a12 * a01 - a02 * a11),
		b11, (a22 * a00 - a02 * a20), (-a12 * a00 + a02 * a10),
		b21, (-a21 * a00 + a01 * a20), (a11 * a00 - a01 * a10)) / det;
}

#ifdef MC_NORMAL_MAP
	vec3 applyBump(mat3 tbnMatrix, vec3 bump) {
		float bumpmult = 1.0 - wetness * 0.95;

		bump = bump * vec3(bumpmult) + vec3(0.0, 0.0, 1.0 - bumpmult);

		return normalize(bump * tbnMatrix);
	}
#endif

#ifdef MAT_PARALLAX_ENABLED
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
	vec3 normal = vIn.normalMat.xyz;

	#ifdef MC_NORMAL_MAP
		vec3 tangent2 = normalize(cross(vIn.tangent.rgb, normal) * vIn.tangent.w);

		mat3 tbnMatrix = mat3(
			vIn.tangent.x, tangent2.x, normal.x,
			vIn.tangent.y, tangent2.y, normal.y,
			vIn.tangent.z, tangent2.z, normal.z);
	#endif

	#ifdef MAT_PARALLAX_ENABLED
		vec2 tempOffset = taa_offsets[framemod8];
		vec2 adjustedTexCoord = fract(vIn.vtexcoord.st) * vIn.vtexcoordam.pq + vIn.vtexcoordam.st;
		vec3 fragpos = toScreenSpace(gl_FragCoord.xyz * vec3(texelSize/RENDER_SCALE, 1.0) - vec3(vec2(tempOffset)*texelSize*0.5, 0.0));
		vec3 viewVector = normalize(tbnMatrix * fragpos);
		float dist = length(fragpos);

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

					vec3 truePos = fragpos + sumVec * inverse(tbnMatrix) * interval;

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

					vec3 truePos = fragpos + sumVec * inverse(tbnMatrix) * interval;

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

		normal = applyBump(tbnMatrix, textureGrad(normals, adjustedTexCoord.xy, dcdx, dcdy).xyz * 2.0 - 1.0);

		#ifdef MC_TEXTURE_FORMAT_LAB_PBR
			vec4 specularData = textureGrad(specular, adjustedTexCoord.xy, dcdx, dcdy);
		#endif
	#else
		vec4 color = texture(gtexture, vIn.lmtexcoord.xy, Texture_MipMap_Bias);
		color.rgb *= vIn.color.rgb;

		float avgBlockLum = luma(textureLod(gtexture, vIn.lmtexcoord.xy, 128).rgb * vIn.color.rgb);
		color.rgb = saturate(color.rgb * pow(avgBlockLum, -0.33) * 0.85);

		#ifdef DISABLE_ALPHA_MIPMAPS
			color.a = textureLod(gtexture, vIn.lmtexcoord.xy, 0).a;
		#endif

		#ifdef MC_NORMAL_MAP
			normal = applyBump(tbnMatrix, texture(normals, vIn.lmtexcoord.xy).rgb * 2.0 - 1.0);
		#endif

		#ifdef MC_TEXTURE_FORMAT_LAB_PBR
			vec4 specularData = texture(specular, vIn.lmtexcoord.xy);
		#endif
	#endif

	if (color.a < alphaTestRef) discard;

	#ifdef MC_TEXTURE_FORMAT_LAB_PBR
		float roughness = specularData.r;
		float f0 = specularData.g;
		float sss = mat_sss_lab(specularData.b);
		float emission = mat_emission_lab(specularData.a);
	#else
		const float roughness = 1.0;
		const float f0 = 0.04;
		float emission = 0.0;
		float sss = 0.0;

		if (vIn.normalMat.a < 0.51) {
			sss = 0.5;
		}
		else if (vIn.normalMat.a < 0.61) {
			sss = 0.2;
		}
		else if (vIn.normalMat.a < 0.91) {
			vec3 albedo = toLinear(color.rgb);
			emission = saturate(luma(albedo) * 3.0);
		}
	#endif

	outColor = color;
	outNormal = vec4(OctEncode(vIn.normalMat.xyz), OctEncode(normal));
	outSpecular = vec4(roughness, f0, sss, emission);
	outWorld = vec4(vIn.lmtexcoord.zw, 0.0, vIn.normalMat.a);
}
