#version 120

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec4 lmtexcoord;
varying vec4 color;

uniform sampler2D texture;
uniform sampler2D gaux1;

uniform vec2 texelSize;
uniform mat4 gbufferProjectionInverse;
uniform float alphaTestRef;


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor2;

void main() {
	outColor2 = texture2D(texture, lmtexcoord.xy) * color;
	outColor2.a = saturate(outColor2.a - 0.1) * 0.5;

//	if (outColor2.a < alphaTestRef) discard;

	vec3 albedo = toLinear(outColor2.rgb * color.rgb);
	vec3 ambient = texture2D(gaux1, (lmtexcoord.zw * 15.0 + 0.5) * texelSize).rgb;

	outColor2.rgb = dot(albedo, vec3(1.0)) * ambient * 10.0/3.0/150.0 * 0.1;
}
