#version 120

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec4 color;
varying vec2 texcoord;

uniform sampler2D texture;


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor2;

void main() {
	vec4 albedo = texture2D(texture, texcoord);
	albedo *= color;

	albedo.rgb = toLinear(albedo.rgb) * 0.33;

	outColor2 = albedo;
}
