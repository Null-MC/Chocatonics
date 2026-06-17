#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
} vIn;

uniform sampler2D gtexture;
uniform sampler2D gaux1;

uniform vec2 texelSize;
uniform mat4 gbufferProjectionInverse;
//uniform float alphaTestRef;

#include "/lib/color_transforms.glsl"


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor2;

void main() {
	outColor2 = texture(gtexture, vIn.lmtexcoord.xy) * vIn.color;
	outColor2.a = saturate(outColor2.a - 0.1) * 0.5;

//	if (outColor2.a < alphaTestRef) discard;

	vec3 albedo = InputTransform(outColor2.rgb * vIn.color.rgb);
	vec3 ambient = texture(gaux1, (vIn.lmtexcoord.zw * 15.0 + 0.5) * texelSize).rgb;

	outColor2.rgb = dot(albedo, vec3(1.0)) * ambient * 10.0/3.0/150.0 * 0.1;
}
