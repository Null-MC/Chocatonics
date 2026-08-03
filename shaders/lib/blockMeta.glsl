const uint BIT_WAVING_TOP = 1;
const uint BIT_WAVING_FULL = 2;
const uint BIT_SSS_LOW = 4;
const uint BIT_SSS_HIGH = 8;
const uint BIT_EMISSIVE = 16;
const uint BIT_REFLECTIVE = 32;


ivec2 GetBlockMetaUV(const in uint blockId) {
    return ivec2(blockId % 256, blockId / 256);
}

#ifndef RENDER_SETUP
    uint SampleBlockMeta(const in uint blockId) {
        ivec2 blockMetaUV = GetBlockMetaUV(blockId);
        return texelFetch(texBlockMeta, blockMetaUV, 0).r;
    }
#endif
