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


void main() {
	lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	lmtexcoord.zw = gl_MultiTexCoord1.xy / 255.0;
	gl_Position = ftransform();
	color = gl_Color;

	normalMat = vec4(normalize(gl_NormalMatrix * gl_Normal), 1.0);

	#ifdef MC_NORMAL_MAP
		tangent = vec4(normalize(gl_NormalMatrix * at_tangent.rgb), at_tangent.w);
	#endif

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
