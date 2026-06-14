#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
} vIn;

uniform sampler2D gtexture;
uniform sampler2D texLightMap_forward;

uniform vec2 texelSize;
uniform mat4 gbufferProjectionInverse;
//uniform float alphaTestRef;

#include "/lib/sceneBuffer.glsl"


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor2;

void main() {
	outColor2 = texture(gtexture, vIn.lmtexcoord.xy) * vIn.color;
	outColor2.a = saturate(outColor2.a - 0.1) * 0.5;

//	if (outColor2.a < alphaTestRef) discard;

	vec3 albedo = toLinear(outColor2.rgb * vIn.color.rgb);

	vec2 lmcoord = (vIn.lmtexcoord.zw * 15.0 + 0.5) / 16.0;
	vec3 ambient = texture(texLightMap_forward, lmcoord).rgb;

	outColor2.rgb = dot(albedo, vec3(1.0)) * ambient * 10.0/3.0 * 0.1;
}
