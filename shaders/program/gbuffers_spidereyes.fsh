#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 color;
	vec2 texcoord;
} vIn;

uniform sampler2D gtexture;

#include "/lib/color_transforms.glsl"


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor2;

void main() {
	vec4 outColor2 = texture(gtexture, vIn.texcoord, Texture_MipMap_Bias) * vIn.color;
	outColor2.rgb = InputTransform(outColor2.rgb) * 0.33;
}
