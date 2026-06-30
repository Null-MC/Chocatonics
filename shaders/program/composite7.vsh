#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


flat out vec3 zMults;

uniform float far;
uniform float near;


void main() {
	gl_Position = ftransform();

	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy * 0.5 + 0.5) * RENDER_SCALE * 2.0 - 1.0;
	#endif

	zMults = vec3(1.0 / (farPlane * nearPlane), farPlane + nearPlane, farPlane - nearPlane);
}
