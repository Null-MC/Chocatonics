#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;

	#ifdef MC_NORMAL_MAP
		vec4 tangent;
	#endif
} vIn;

uniform sampler2D gtexture;

#ifdef MC_TEXTURE_FORMAT_LAB_PBR
	uniform sampler2D specular;
#endif

uniform float frameTimeCounter;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform float alphaTestRef;
uniform vec4 entityColor;

#include "/lib/ign.glsl"
#include "/lib/material.glsl"
#include "/lib/octohedral.glsl"
#include "/lib/projections.glsl"


/* RENDERTARGETS: 8,9,10,11 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outSpecular;
layout(location = 3) out vec4 outWorld;

void main() {
	float noise = IGN_time(frameTimeCounter);
	vec3 normal = vIn.normalMat.xyz;

	vec4 color = texture(gtexture, vIn.lmtexcoord.xy) * vIn.color;
	float avgBlockLum = luma(textureLod(gtexture, vIn.lmtexcoord.xy, 128).rgb * vIn.color.rgb);
	color.rgb = saturate(color.rgb * pow(avgBlockLum, -0.33) * 0.85);
	color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);

	if (color.a < alphaTestRef) discard;

	#ifdef MC_TEXTURE_FORMAT_LAB_PBR
		vec4 specularData = texture(specular, vIn.lmtexcoord.xy);

		float roughness = specularData.r;
		float f0 = specularData.g;
		float sss = mat_sss_lab(specularData.b);
		float emission = mat_emission_lab(specularData.a);
	#else
		const float roughness = 1.0;
		const float f0 = 0.04;
		const float sss = 0.0;
		const float emission = 0.0;
	#endif

	outColor = color;
	outNormal = vec4(OctEncode(vIn.normalMat.xyz), OctEncode(normal));
	outSpecular = vec4(roughness, f0, sss, emission);
	outWorld = vec4(vIn.lmtexcoord.zw, 0.0, vIn.normalMat.a);
}
