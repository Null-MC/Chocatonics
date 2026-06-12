#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;

uniform vec2 texelSize;
uniform int framemod8;


vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
}


void main() {
	lmtexcoord.xy = (gl_MultiTexCoord0).xy;

	vec2 lmcoord = gl_MultiTexCoord1.xy / 255.0;
	lmtexcoord.zw = lmcoord;

	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;

	color = gl_Color;

	normalMat = vec4(normalize(gl_NormalMatrix * gl_Normal), 0.0);

	gl_Position = toClipSpace3(position);
	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
