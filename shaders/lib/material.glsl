vec3 mat_normal_lab(const in vec2 normalData) {
    vec2 normal_xy = fma(normalData.xy, vec2(2.0), vec2(-254.0/255.0));
    float normal_z = sqrt(max(1.0 - dot(normal_xy, normal_xy), 0.0));
    return vec3(normal_xy, normal_z);
}

vec3 mat_normal_old(const in vec3 normalData) {
    return normalize(fma(normalData, vec3(2.0), vec3(-1.0)));
}

vec3 mat_normal(const in vec3 normalData) {
    #if MAT_FORMAT == MAT_FORMAT_LABPBR || defined(MC_TEXTURE_FORMAT_LAB_PBR)
        return mat_normal_lab(normalData.xy);
    #elif MAT_FORMAT == MAT_FORMAT_OLDPBR
        return mat_normal_old(normalData);
    #else
        return vec3(0.0);
    #endif
}


float mat_roughness_lab(const in float specular_r) {
    return square(1.0 - specular_r);
}

float mat_roughness_old(const in float specular_r) {
    return square(1.0 - specular_r);
}

float mat_roughness(const in float specular_r) {
    #if MAT_FORMAT == MAT_FORMAT_LABPBR || defined(MC_TEXTURE_FORMAT_LAB_PBR)
        return mat_roughness_lab(specular_r);
    #elif MAT_FORMAT == MAT_FORMAT_OLDPBR
        return mat_roughness_old(specular_r);
    #else
        return 1.0;
    #endif
}


float mat_metalness_lab(const in float specular_g) {
    return step((229.5/255.0), specular_g);
}

float mat_metalness_old(const in float specular_g) {
    return specular_g;
}

float mat_metalness(const in float specular_g) {
    #if MAT_FORMAT == MAT_FORMAT_LABPBR || defined(MC_TEXTURE_FORMAT_LAB_PBR)
        return mat_metalness_lab(specular_g);
    #elif MAT_FORMAT == MAT_FORMAT_OLDPBR
        return mat_metalness_old(specular_g);
    #else
        return 0.0;
    #endif
}


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


float mat_porosity_lab(const in float specular_b) {
    return specular_b * (255.0/64.0) * step(specular_b, (64.5/255.0));
}

float mat_porosity_old(const in vec2 specular_rg) {
    float roughness = mat_roughness(specular_rg.r);
    float metalness = mat_metalness_old(specular_rg.g);
    return pow(roughness, 1.0 + metalness);
}

float mat_porosity(const in vec3 specular_rgb) {
    #if MAT_FORMAT == MAT_FORMAT_OLDPBR || defined(MAT_POROSITY_INTEGRATED)
        return mat_porosity_old(specular_rgb.rg);
    #elif MAT_FORMAT == MAT_FORMAT_LABPBR || defined(MC_TEXTURE_FORMAT_LAB_PBR)
        return mat_porosity_lab(specular_rgb.b);
    #else
        return 0.85;
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
