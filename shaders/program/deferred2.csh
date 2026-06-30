#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#define TEX_DEPTH depthtex1


layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(RENDER_SCALE*0.25, RENDER_SCALE*0.25);

layout(r16f) uniform writeonly image2D imgDepthQ;

uniform sampler2D TEX_DEPTH;

uniform float near;
uniform float far;


void main() {
    ivec2 bufferSize = imageSize(imgDepthQ);

    ivec2 uv_dest = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(uv_dest, bufferSize))) return;

    ivec2 uv_src = ivec2((uv_dest + 0.5) * 4.0);
	float depth = texelFetch(TEX_DEPTH, uv_src, 0).r;
    float depthL;

    if (depth < 1.0) {
        float z = depthScreenToLinear(depth, nearPlane, farPlane) / farPlane;
        depthL = z*z * 65000.0;
    }
    else {
        depthL = 2.0;
    }

    imageStore(imgDepthQ, uv_dest, vec4(depthL));
}
