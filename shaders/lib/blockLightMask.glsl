const uint BLOCKLIGHT_SOLID_MASK = (1u << 7);


uint GetBlockLightMask(const in usampler2D texBlockLightMask, const in uint blockId) {
    ivec2 blockLightUV = GetBlockLightUV(blockId);
    return texelFetch(texBlockLightMask, blockLightUV, 0).r;
}

bool IsLightMaskSolid(const in uint mask) {
    return (mask & BLOCKLIGHT_SOLID_MASK) == BLOCKLIGHT_SOLID_MASK;
}
