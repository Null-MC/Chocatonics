float mat_emission_lab(const in float specular_a) {
    return fract(specular_a);
}

float mat_sss_lab(const in float specular_b) {
    return max(specular_b - (64.0/255.0), 0.0) * (255.0/191.0);
}
