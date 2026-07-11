vec3 GetFloodFillSamplePos(const in vec3 voxelPos, const in vec3 normal) {
    return normal * 0.6 + voxelPos;
}

vec3 GetFloodFillSamplePos(const in vec3 voxelPos, const in vec3 geoNormal, const in vec3 texNormal) {
    const float strength = LIGHTING_FLOODFILL_NORMAL_STRENGTH * 0.01;

    vec3 geoPos = GetFloodFillSamplePos(voxelPos, geoNormal);
    vec3 offsetPos = texNormal - geoNormal * 0.25 + voxelPos;
    return mix(geoPos, offsetPos, strength);
}

vec3 TransformFloodFillSample(in vec3 color) {
    color = InputTransform(color);

    float L = luma(color);
    color *= L * 9.0;

    return color;
}

vec3 SampleFloodFill(const in vec3 voxelPos, const in int frame) {
    vec3 texcoord = voxelPos / VoxelBufferSize;

    texcoord.z *= 0.5;
    if (frame % 2 == 1) texcoord.z += 0.5;

    vec3 color = texture(texFloodFill, texcoord).rgb;
    return TransformFloodFillSample(color);
}
