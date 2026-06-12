vec4 blueNoise(const in vec2 coord) {
    return texelFetch(noisetex, ivec2(coord) % 512, 0);
}

float blueNoise(const in vec2 coord, const in float time) {
    return fract(blueNoise(coord).a + 1.0/1.6180339887 * time);
}
