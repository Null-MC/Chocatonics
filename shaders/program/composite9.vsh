#version 120

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

uniform float viewWidth;
uniform float viewHeight;


void main() {
	// Improves performances and makes sure bloom radius stays the same at high resolution (>1080p)
	vec2 clampedRes = max(vec2(viewWidth, viewHeight), vec2(1920.0, 1080.0));

	gl_Position = ftransform();

	// *0.51 to avoid errors when sampling outside since clearing is disabled
	gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * 0.51 * BLOOM_QUALITY / clampedRes * vec2(1920.0, 1080.0) * 2.0 - 1.0;
}
