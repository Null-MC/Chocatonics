#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
//	vec4 normalMat;
} vIn;

uniform sampler2D gtexture;
uniform sampler2D gaux1;

#include "/lib/color_transforms.glsl"


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor2;

void main() {
	outColor2 = texture(gtexture, vIn.lmtexcoord.xy);

	vec3 albedo = InputTransform(outColor2.rgb * vIn.color.rgb);

	float exposure = texelFetch(gaux1, ivec2(10, 37), 0).r;

	vec3 col = albedo * exp(exposure * -3.0);

	outColor2.rgb = col * vIn.color.a;
	outColor2.a = outColor2.a * 0.1;
}
