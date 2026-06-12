#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


#ifdef MC_NORMAL_MAP
	attribute vec4 at_tangent;
#endif

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;

#ifdef MC_NORMAL_MAP
	varying vec4 tangent;
#endif

uniform vec2 texelSize;
uniform int framemod8;


vec4 toClipSpace3(vec3 viewSpacePosition) {
	return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}


void main() {
	lmtexcoord.xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;

	vec2 lmcoord = gl_MultiTexCoord1.xy/255.;
	lmtexcoord.zw = lmcoord*lmcoord;

	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;

	color = gl_Color;
	gl_Position = toClipSpace3(position);

	#ifdef MC_NORMAL_MAP
		tangent = vec4(normalize(gl_NormalMatrix * at_tangent.rgb), at_tangent.w);
	#endif

	normalMat = vec4(normalize(gl_NormalMatrix * gl_Normal), 1.0);

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
