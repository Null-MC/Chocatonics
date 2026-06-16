#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


uniform sampler2D depthtex1;

uniform float near;
uniform float far;


/* RENDERTARGETS: 12 */
layout(location = 0) out float outDepthL;

void main() {
	float depth = texelFetch(depthtex1, ivec2(gl_FragCoord.xy * 4.0), 0).x;

    if (depth < 1.0) {
        float z = linZ(depth, nearPlane, farPlane);
        outDepthL = z*z * 65000.0;
    }
    else {
        outDepthL = 2.0;
    }
}
