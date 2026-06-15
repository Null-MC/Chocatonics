float mat_emission_lab(const in float specular_a) {
    return fract(specular_a);
}

float mat_emission_old(const in float specular_b) {
    return specular_b;
}

float mat_emission(const in vec4 specularData) {
    #if MAT_FORMAT == MAT_FORMAT_LABPBR || defined(MC_TEXTURE_FORMAT_LAB_PBR)
        return mat_emission_lab(specularData.a);
    #elif MAT_FORMAT == MAT_FORMAT_OLDPBR
        return mat_emission_old(specularData.b);
    #else
        return 0.0;
    #endif
}

float mat_sss_lab(const in float specular_b) {
    return max(specular_b - (64.0/255.0), 0.0) * (255.0/191.0);
}

float mat_sss(const in float specular_b) {
    #if MAT_FORMAT == MAT_FORMAT_LABPBR || defined(MC_TEXTURE_FORMAT_LAB_PBR)
        return mat_sss_lab(specular_b);
    #else
        return 0.0;
    #endif
}
