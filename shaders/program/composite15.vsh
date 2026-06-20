#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	vec2 texcoord;
	flat vec4 exposure;
	flat vec2 rodExposureDepth;
} vOut;

uniform sampler2D colortex4;


void main() {
	gl_Position = ftransform();

	vOut.texcoord = gl_MultiTexCoord0.xy;

	const vec3 final = vec3(POST_FINAL_R, POST_FINAL_G, POST_FINAL_B);

	vOut.exposure = vec4(texelFetch(colortex4, ivec2(10, 37), 0).r * final, texelFetch(colortex4, ivec2(10, 37), 0).r);
	vOut.rodExposureDepth = texelFetch(colortex4, ivec2(14, 37), 0).rg;
	vOut.rodExposureDepth.y = sqrt(vOut.rodExposureDepth.y / 65000.0);
}
