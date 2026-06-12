#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


uniform vec2 texelSize;


void main() {
	gl_Position = ftransform();

	vec2 scaleRatio = max(vec2(0.25), vec2(18.0 + 258.0*2.0, 258.0) * texelSize);

	gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * saturate(scaleRatio + 0.01) * 2.0 - 1.0;
}
