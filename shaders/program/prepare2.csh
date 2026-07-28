#version 430 compatibility

// Clear voxel depth map for Photonics

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

layout(r32f) uniform image2D imgVoxelDepth;

uniform float viewWidth;
uniform float viewHeight;

ivec2 viewSizeScaled = ivec2(ceil(vec2(viewWidth, viewHeight) * RENDER_SCALE));


void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(uv, viewSizeScaled))) return;

    imageStore(imgVoxelDepth, uv, vec4(1.0));
}
