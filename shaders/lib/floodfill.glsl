vec3 GetFloodFillSamplePos(const in vec3 voxelPos, const in vec3 normal) {
    return normal * 0.50 + voxelPos;
}

vec3 GetFloodFillSamplePos(const in vec3 voxelPos, const in vec3 geoNormal, const in vec3 texNormal) {
    return texNormal - geoNormal * 0.25 + voxelPos;
}

vec3 SampleFloodFill(const in vec3 voxelPos, const in int frame) {
    vec3 texcoord = voxelPos / VoxelBufferSize;

    texcoord.z *= 0.5;
    if (frame % 2 == 1) texcoord.z += 0.5;

    vec3 color = texture(texFloodFill, texcoord).rgb;
    return InputTransform(color);
}
