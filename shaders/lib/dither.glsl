float triangularize(float dither) {
    float center = dither * 2.0 - 1.0;
    dither = center * inversesqrt(abs(center));
    return saturate(dither - fsign(center));
}

vec3 fp10Dither(vec3 color, float dither) {
    const vec3 mantissaBits = vec3(6.0, 6.0, 5.0);
    vec3 exponent = floor(log2(color));
    return color + dither * exp2(-mantissaBits) * exp2(exponent);
}
