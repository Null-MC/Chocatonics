#version 430 compatibility

// computes center-depth values

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);


layout(rgba16f) uniform image2D colorimg4;

uniform sampler2D depthtex0;

uniform float frameTime;
uniform float near;
uniform float far;
uniform float dhFarPlane;


void main() {
    const ivec2 uv = ivec2(14, 37);
    vec4 data = imageLoad(colorimg4, uv);

    float currCenterDepth = texture(depthtex0, vec2(0.5) * RENDER_SCALE).r;
    currCenterDepth = depthScreenToLinear(currCenterDepth, nearPlane, farPlane);// * farPlane;

    float prevCenterDepth = sqrt(data.g / 65000.0) * farPlane;
    float mixF = DoF_Adaptation_Speed * exp(-0.016/frameTime + 1.0) / (6.0 + currCenterDepth);
    float centerDepth = mix(prevCenterDepth, currCenterDepth, saturate(mixF));

    data.g = square(centerDepth / farPlane) * 65000.0;
    imageStore(colorimg4, uv, data);
}
