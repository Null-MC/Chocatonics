const mat3 sRGB_2_AP1 = mat3(
    0.61319, 0.07021, 0.02062,
    0.33951, 0.91634, 0.10957,
    0.04737, 0.01345, 0.86961);

const mat3 AP1_2_sRGB = mat3(
    1.70486, -0.13023, -0.02396,
    -0.62171,  1.14073, -0.12897,
    -0.08329, -0.01050,  1.15301);


const mat3 ACESInputMat = mat3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
const mat3 ACESOutputMat = mat3(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602);


vec3 srgbToLinear(vec3 srgb) {
    return mix(
        srgb / 12.92,
        pow(0.947867 * srgb + 0.0521327, vec3(2.4)),
        step(0.04045, srgb)
    );
}

vec3 linearToSRGB(vec3 linear) {
    return mix(
        linear * 12.92,
        pow(linear, vec3(1.0/2.4)) * 1.055 - 0.055,
        step(0.0031308, linear)
    );
}

vec3 ACES_linear_to_cg(const in vec3 color) {
    return sRGB_2_AP1 * color;
}

vec3 ACES_cg_to_linear(const in vec3 color) {
    return AP1_2_sRGB * color;
}

vec3 InputTransform(const in vec3 color) {
    #ifdef ACES_CG_ENABLED
        return ACES_linear_to_cg(srgbToLinear(color));
    #else
        return toLinear(color);
    #endif
}

vec3 InputTransformLinear(const in vec3 color) {
    #ifdef ACES_CG_ENABLED
        return ACES_linear_to_cg(color);
    #else
        return color;
    #endif
}
