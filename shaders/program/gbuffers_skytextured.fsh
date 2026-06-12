#version 120

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec4 color;
varying vec2 texcoord;

uniform sampler2D texture;


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 outColor1;

void main() {
	outColor1 = texture2D(texture, texcoord.xy) * color;
	outColor1.rgb = outColor1.rgb * outColor1.a;
}
