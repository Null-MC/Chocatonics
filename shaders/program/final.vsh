#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	vec2 texcoord;
//	flat vec4 exposure;
} vOut;

//uniform sampler2D colortex4;


void main() {
	gl_Position = ftransform();

	vOut.texcoord = gl_MultiTexCoord0.xy;

//	vOut.exposure = vec4(texelFetch(colortex4, ivec2(10, 37), 0).r * vec3(FinalR, FinalG, FinalB), texelFetch(colortex4, ivec2(10, 37), 0).r);
}
