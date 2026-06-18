#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;
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

	vec4 color = texture(gtexture, vIn.lmtexcoord.xy);
	#ifdef DISABLE_ALPHA_MIPMAPS
		color.a = textureLod(gtexture, vIn.lmtexcoord.xy, 0).a;
	#endif

	if (color.a < alphaTestRef) discard;

	color.rgb *= vIn.color.rgb;

//	float avgBlockLum = luma(textureLod(gtexture, vIn.lmtexcoord.xy, 128).rgb * vIn.color.rgb);
//	color.rgb = saturate((1.e-3 + color.rgb) * pow(avgBlockLum, -0.33) * 0.859);

	#ifdef MC_TEXTURE_FORMAT_LAB_PBR
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
