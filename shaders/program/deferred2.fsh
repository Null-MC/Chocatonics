#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


uniform sampler2D colortex4;
uniform sampler2D depthtex1;

uniform float near;
uniform float far;


/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outColor4;

void main() {
	vec3 oldTex = texelFetch(colortex4, ivec2(gl_FragCoord.xy), 0).xyz;
	float newTex = texelFetch(depthtex1, ivec2(gl_FragCoord.xy * 4.0), 0).x;

    if (newTex < 1.0) {
        float z = linZ(newTex, near, far);
        outColor4 = vec4(oldTex, z * z * 65000.0);
    }
    else {
        outColor4 = vec4(oldTex, 2.0);
    }
}
