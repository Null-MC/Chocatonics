float GGX(vec3 n, vec3 v, vec3 l, float r, float F0) {
    r*=r; r*=r;

    vec3 h = l + v;
    float hn = inversesqrt(dot(h, h));

    float dotLH = saturate(dot(h, l) * hn);
    float dotNH = saturate(dot(h, n) * hn);
    float dotNL = saturate(dot(n, l));
    float dotNHsq = dotNH * dotNH;

    float denom = dotNHsq * r - dotNHsq + 1.0;

    float D = r / (PI * denom * denom);
    float F = F0 + (1.0 - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
    float k2 = 0.25 * r;

    return dotNL * D * F / (dotLH * dotLH * (1.0 - k2) + k2);
}

//float g(float NdotL, float roughness) {
//    float alpha = square(max(roughness, 0.02));
//    return 2.0 * NdotL / (NdotL + sqrt(square(alpha) + (1.0 - square(alpha)) * square(NdotL)));
//}

float gSimple(float dp, float roughness) {
    float k = roughness + 1.0;
    k *= k/8.0;

    return dp / (dp * (1.0 - k) + k);
}

vec3 GGX2(vec3 n, vec3 v, vec3 l, float r, vec3 F0) {
    float roughness = r; // when roughness is zero it fucks up

    float alpha = square(roughness) + 1e-4;

    vec3 h = normalize(l + v);

    float dotLH = saturate(dot(h,l));
    float dotNH = saturate(dot(h,n));
    float dotNL = saturate(dot(n,l));
    float dotNV = saturate(dot(n,v));
    float dotVH = saturate(dot(h,v));

    float D = alpha / (PI * square(square(dotNH) * (alpha - 1.0) + 1.0));
    float G = gSimple(dotNV, roughness) * gSimple(dotNL, roughness);
    vec3 F = F0 + (1.0 - F0) * exp2((-5.55473*dotVH - 6.98316)*dotVH);

    return dotNL * F * (G * D / (4 * dotNV * dotNL + 1e-7));
}
