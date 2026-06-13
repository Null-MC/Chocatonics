#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;
} vOut;

uniform vec2 texelSize;
uniform int framemod8;


vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
}


void main() {
	vOut.lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	vOut.lmtexcoord.zw = gl_MultiTexCoord1.xy / 255.0;

	vOut.normalMat = vec4(normalize(gl_NormalMatrix * gl_Normal), 0.0);

	vOut.color = gl_Color;

	gl_Position = toClipSpace3(mul3(gl_ModelViewMatrix, gl_Vertex.xyz));

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
