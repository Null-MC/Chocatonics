#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;

	#ifdef MAT_PBR_ENABLED
		vec4 tangent;
	#endif
} vIn;

uniform sampler2D gtexture;

#ifdef MAT_PBR_ENABLED
	uniform sampler2D normals;
	uniform sampler2D specular;
#endif

uniform float frameTimeCounter;
uniform mat4 gbufferProjectionInverse;
uniform float alphaTestRef;

#include "/lib/ign.glsl"
#include "/lib/material.glsl"
#include "/lib/octohedral.glsl"

#ifdef MAT_PBR_ENABLED
//	const float wetness = 0.0;
	#include "/lib/normal_map.glsl"
#endif


/* RENDERTARGETS: 8,9,10,11 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outSpecular;
layout(location = 3) out vec4 outWorld;

void main() {
	vec4 color = texture(gtexture, vIn.lmtexcoord.xy, Texture_MipMap_Bias);

	#ifdef DISABLE_ALPHA_MIPMAPS
		color.a = textureLod(gtexture, vIn.lmtexcoord.xy, 0).a;
	#endif

	if (color.a < alphaTestRef) discard;

	color.rgb *= vIn.color.rgb;

	vec3 normal = vIn.normalMat.xyz;

	#ifdef MAT_PBR_ENABLED
		vec3 bitangent = normalize(cross(vIn.tangent.rgb, normal) * vIn.tangent.w);

		mat3 tbnMatrix = mat3(
				vIn.tangent.x, bitangent.x, normal.x,
				vIn.tangent.y, bitangent.y, normal.y,
				vIn.tangent.z, bitangent.z, normal.z);

		vec3 tex_normal = mat_normal(texture(normals, vIn.lmtexcoord.xy).rgb);

		const float wetness = 0.0; // TODO
		normal = applyBump(tbnMatrix, tex_normal, wetness);
	#endif

	#ifdef MAT_PBR_ENABLED
		vec4 specularData = texture(specular, vIn.lmtexcoord.xy);

		float smoothness = specularData.r;
		float f0 = specularData.g;
		float sss = mat_sss(specularData.b);
		float emission = mat_emission(specularData);
	#else
		const float smoothness = 0.0;
		const float f0 = 0.04;
		const float sss = 0.0;
		const float emission = 0.0;
	#endif

	outColor = color;
	outNormal = vec4(OctEncode(vIn.normalMat.xyz), OctEncode(normal));
	outSpecular = vec4(smoothness, f0, sss, emission);
	outWorld = vec4(vIn.lmtexcoord.zw, 0.0, vIn.normalMat.a);
}
