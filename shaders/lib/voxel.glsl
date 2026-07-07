const ivec3 VoxelBufferSize = ivec3(LIGHTING_VOXEL_SIZE);
const ivec3 VoxelBufferCenter = VoxelBufferSize / 2;
const float VoxelFrustumOffsetF = LPV_FRUSTUM_OFFSET * 0.01;
const float Voxel_FadePadding = 8.0;


vec3 GetVoxelCenter(const in vec3 viewDir) {
    vec3 offset = viewDir * (VoxelBufferSize * VoxelFrustumOffsetF);
    return VoxelBufferCenter + ivec3(floor(offset));
}

vec3 GetVoxelOffset(const in vec3 cameraPos, const in vec3 playerViewDir) {
    return fract(cameraPos) + GetVoxelCenter(playerViewDir);
}

vec3 GetVoxelPosition(const in vec3 localPos) {
    vec3 viewDir = gbufferModelViewInverse[2].xyz;
    return localPos + GetVoxelOffset(cameraPosition, viewDir);
}

bool IsInVoxelBounds(const in ivec3 voxelPos) {
    return clamp(voxelPos, 0, LIGHTING_VOXEL_SIZE-1) == voxelPos;
}

bool IsInVoxelBounds(const in vec3 voxelPos) {
    return clamp(voxelPos, 0.5, LIGHTING_VOXEL_SIZE-0.5) == voxelPos;
}

bool IsVoxelSolid(const in uint voxelId) {
    if (voxelId == 0u) return false;
    if (voxelId == BLOCK_IGNORED) return false;
    if (voxelId == BLOCK_SNOW_LAYERS) return false;

    return true;
}

float GetVoxelFade(const in vec3 voxelPos) {
    const vec3 lpvSizeInner = VoxelBufferCenter - Voxel_FadePadding;

    vec3 viewDir = gbufferModelViewInverse[2].xyz;
    vec3 lpvDist = abs(voxelPos - VoxelBufferCenter);
    vec3 lpvDistF = max(lpvDist - lpvSizeInner, vec3(0.0));
    return saturate(1.0 - maxOf((lpvDistF / Voxel_FadePadding)));
}
