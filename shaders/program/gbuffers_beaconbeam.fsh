#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
} vIn;

uniform sampler2D gtexture;
uniform sampler2D gaux1;


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor2;

void main() {
	outColor2 = texture(gtexture, vIn.lmtexcoord.xy) * vIn.color;
	outColor2.a = 1.0;

	float torch_lightmap = vIn.lmtexcoord.z;
	float exposure = texelFetch(gaux1, ivec2(10, 37), 0).r;
	vec3 diffuseLight = torch_lightmap * vec3(20.0, 30.0, 50.0) * 2.0 / 10.0;

	vec3 albedo = toLinear(outColor2.rgb);
	vec3 color = diffuseLight * albedo / exposure * 5.0;

	outColor2.rgb = color * 0.01;
}
