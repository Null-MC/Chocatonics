ivec2 GetBlockLightUV(const in uint blockId) {
    return ivec2(blockId % 256, blockId / 256);
}

vec4 SampleBlockLightRange(const in uint blockId) {
    ivec2 blockLightUV = GetBlockLightUV(blockId);
    return texelFetch(texBlockLight, blockLightUV, 0);
}

float GetBlockLightRange(const in uint blockId) {
    return SampleBlockLightRange(blockId).a * 32.0;
}

void GetBlockColorRange(const in uint blockId, out vec3 lightColor, out float lightRange) {
    vec4 lightColorRange = SampleBlockLightRange(blockId);
    lightColor = InputTransform(lightColorRange.rgb);
    lightRange = lightColorRange.a * 32.0;
}
