vec3 decode(const in vec2 enc) {
    vec2 fenc = enc * 4.0 - 2.0;
    float f = dot(fenc, fenc);
    float g = sqrt(1.0 - f/4.0);
    return vec3(fenc * g, 1.0 - f/2.0);
}

vec2 decodeVec2(const in float a) {
    const vec2 constant1 = 65535.0 / vec2(256.0, 65536.0);
    const float constant2 = 256.0 / 255.0;

    return fract(a * constant1) * constant2;
}
