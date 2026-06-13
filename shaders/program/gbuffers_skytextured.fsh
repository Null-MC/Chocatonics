#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 color;
	vec2 texcoord;
} vIn;

uniform sampler2D gtexture;


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 outColor1;

void main() {
	outColor1 = texture(gtexture, vIn.texcoord.xy) * vIn.color;
	outColor1.rgb = outColor1.rgb * outColor1.a;
}
