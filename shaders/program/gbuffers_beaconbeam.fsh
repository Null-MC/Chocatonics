#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec4 lmtexcoord;
varying vec4 color;
//varying vec4 normalMat;

uniform sampler2D texture;
uniform sampler2D gaux1;


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor2;

void main() {
	outColor2 = texture2D(texture, lmtexcoord.xy) * color;
	outColor2.a = 1.0;

	vec3 albedo = toLinear(outColor2.rgb);

	float torch_lightmap = lmtexcoord.z;
	float exposure = texelFetch2D(gaux1, ivec2(10, 37), 0).r;
	vec3 diffuseLight = torch_lightmap * vec3(20.0, 30.0, 50.0) * 2.0 / 10.0;

	vec3 color = diffuseLight * albedo / exposure * 5.0;

	outColor2.rgb = color * 0.01;
}
