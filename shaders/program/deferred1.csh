#version 430 compatibility

// Update center-depth uniform

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

uniform sampler2D depthtex0;

uniform float near;
uniform float far;
uniform float frameTime;

#define WRITE_SCENE
#include "/lib/sceneBuffer.glsl"


void main() {
    float centerDepth_now = texture(depthtex0, vec2(0.5) * RENDER_SCALE).r;
    centerDepth_now = linZ(centerDepth_now, near, far);

    float centerDepth_last = scene.centerDepth;
    float centerDepth_blend = saturate(DoF_Adaptation_Speed * exp(-0.016/frameTime + 1.0) / (centerDepth_now * far + 6.0));

    float centerDepth = mix(centerDepth_last, centerDepth_now, centerDepth_blend);
    scene.centerDepth = centerDepth;
}
