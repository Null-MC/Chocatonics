#version 120
#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_shader_texture_lod : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#ifdef POM
	varying vec4 vtexcoordam; // .st for add, .pq for mul
	varying vec4 vtexcoord;
#endif

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;

#ifdef MC_NORMAL_MAP
	varying vec4 tangent;
#endif

uniform sampler2D texture;

#ifdef MC_NORMAL_MAP
	uniform sampler2D normals;
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

#ifdef POM
	uniform int framemod8;
#endif

#ifdef MC_NORMAL_MAP
	uniform float wetness;
#endif

#include "/lib/ign.glsl"
#include "/lib/encoding.glsl"
#include "/lib/projections.glsl"


const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;

const float MAX_OCCLUSION_DISTANCE = MAX_DIST;
const float MIX_OCCLUSION_DISTANCE = MAX_DIST*0.9;
const int   MAX_OCCLUSION_POINTS   = MAX_ITERATIONS;

#ifdef POM
	vec2 dcdx = dFdx(vtexcoord.st * vtexcoordam.pq) * exp2(Texture_MipMap_Bias);
	vec2 dcdy = dFdy(vtexcoord.st * vtexcoordam.pq) * exp2(Texture_MipMap_Bias);
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

#ifdef POM
	vec4 readNormal(in vec2 coord) {
		return texture2DGradARB(normals, fract(coord) * vtexcoordam.pq + vtexcoordam.st, dcdx, dcdy);
	}

	vec4 readTexture(in vec2 coord) {
		return texture2DGradARB(texture, fract(coord) * vtexcoordam.pq + vtexcoordam.st, dcdx, dcdy);
	}
#endif


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 outColor1;

void main() {
	float noise = IGN_time(frameTimeCounter);
	vec3 normal = normalMat.xyz;

	#ifdef MC_NORMAL_MAP
		vec3 tangent2 = normalize(cross(tangent.rgb, normal) * tangent.w);

		mat3 tbnMatrix = mat3(
			tangent.x, tangent2.x, normal.x,
			tangent.y, tangent2.y, normal.y,
			tangent.z, tangent2.z, normal.z);
	#endif

	#ifdef POM
		vec2 tempOffset = taa_offsets[framemod8];
		vec2 adjustedTexCoord = fract(vtexcoord.st)*vtexcoordam.pq+vtexcoordam.st;
		vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
		vec3 viewVector = normalize(tbnMatrix*fragpos);
		float dist = length(fragpos);

		#ifdef Depth_Write_POM
			gl_FragDepth = gl_FragCoord.z;
		#endif

		if (dist < MAX_OCCLUSION_DISTANCE) {
  			#ifndef AutoGeneratePOMTextures
				if (viewVector.z < 0.0 && readNormal(vtexcoord.st).a < 0.9999 && readNormal(vtexcoord.st).a > 0.00001) {
					vec3 interval = viewVector.xyz / -viewVector.z / MAX_OCCLUSION_POINTS * POM_DEPTH;
					vec3 coord = vec3(vtexcoord.st, 1.0);

					coord += noise*interval;
					float sumVec = noise;

					for (int loopCount = 0; (loopCount < MAX_OCCLUSION_POINTS) && (1.0 - POM_DEPTH + POM_DEPTH*readNormal(coord.st).a < coord.p) &&coord.p >= 0.0; ++loopCount) {
						coord = coord+interval;
						sumVec += 1.0;
					}

					if (coord.t < mincoord) {
						if (readTexture(vec2(coord.s, mincoord)).a < alphaTestRef) {
							coord.t = mincoord;
							discard;
						}
					}

					adjustedTexCoord = mix(fract(coord.st)*vtexcoordam.pq+vtexcoordam.st , adjustedTexCoord , max(dist-MIX_OCCLUSION_DISTANCE,0.0)/(MAX_OCCLUSION_DISTANCE-MIX_OCCLUSION_DISTANCE));

					vec3 truePos = fragpos + sumVec*inverse(tbnMatrix)*interval;
					#ifdef Depth_Write_POM
						gl_FragDepth = toClipSpace3(truePos).z;
					#endif
				}
  			#else
				if (viewVector.z < 0.0) {
					vec3 interval = viewVector.xyz / -viewVector.z / MAX_OCCLUSION_POINTS * POM_DEPTH;
					vec3 coord = vec3(vtexcoord.st, 1.0);
					coord += noise*interval;
					float sumVec = noise;
					float lum0 = luma(texture2DLod(texture, lmtexcoord.xy, 100).rgb);

					for (int loopCount = 0; (loopCount < MAX_OCCLUSION_POINTS) && (1.0 - POM_DEPTH + POM_DEPTH*luma(readTexture(coord.st).rgb)/lum0*0.5 < coord.p) && coord.p >= 0.0; ++loopCount) {
						 coord = coord+interval;
						 sumVec += 1.0;
					}

					if (coord.t < mincoord) {
						if (readTexture(vec2(coord.s, mincoord)).a < alphaTestRef) {
							coord.t = mincoord;
							discard;
						}
					}

					adjustedTexCoord = mix(fract(coord.st) * vtexcoordam.pq + vtexcoordam.st, adjustedTexCoord, max(dist - MIX_OCCLUSION_DISTANCE, 0.0) / (MAX_OCCLUSION_DISTANCE - MIX_OCCLUSION_DISTANCE));

					vec3 truePos = fragpos + sumVec * inverse(tbnMatrix) * (interval);

					#ifdef Depth_Write_POM
						gl_FragDepth = toClipSpace3(truePos).z;
					#endif
				}
			#endif
		}

		vec4 data0 = texture2DGradARB(texture, adjustedTexCoord.xy,dcdx,dcdy);
		#ifdef DISABLE_ALPHA_MIPMAPS
			data0.a = texture2DGradARB(texture, adjustedTexCoord.xy,vec2(0.),vec2(0.0)).a;
		#endif

//		if (data0.a > alphaTestRef) data0.a = normalMat.a;
//		else data0.a = 0.0;

		normal = applyBump(tbnMatrix, texture2DGradARB(normals, adjustedTexCoord.xy, dcdx, dcdy).xyz * 2.0 - 1.0);

		data0.rgb *= color.rgb;

		vec4 data1 = saturate(noise * exp2(-8.0) + encode(normal));
	#else
		vec4 data0 = texture2D(texture, lmtexcoord.xy, Texture_MipMap_Bias);

		data0.rgb *= color.rgb;
		float avgBlockLum = luma(texture2DLod(texture, lmtexcoord.xy,128).rgb * color.rgb);
		data0.rgb = clamp(data0.rgb*pow(avgBlockLum,-0.33) * 0.85, 0.0, 1.0);
		//data0.rgb = vec3(avgBlockLum);
		//data0.rgb = clamp(data0.rgb*pow((0.55+avgBlockLum),-(1.0/2.233)),0.0,1.0);
		//if (toLinear(data0.rgb).g > 0.25) data0.rgb=vec3(1.,0.,0.);

		#ifdef DISABLE_ALPHA_MIPMAPS
			data0.a = texture2DLod(texture,lmtexcoord.xy, 0).a;
		#endif

//		if (data0.a > alphaTestRef) data0.a = normalMat.a;
//		else data0.a = 0.0;

		#ifdef MC_NORMAL_MAP
			normal = applyBump(tbnMatrix, texture2D(normals, lmtexcoord.xy).rgb * 2.0 - 1.0);
		#endif

		vec4 data1 = saturate(noise / 256.0 + encode(normal));
	#endif

	if (data0.a < alphaTestRef) discard;
	data0.a = normalMat.a;

	outColor1 = vec4(
		encodeVec2(data0.x, data1.x),
		encodeVec2(data0.y, data1.y),
		encodeVec2(data0.z, data1.z),
		encodeVec2(data1.w, data0.w));
}
