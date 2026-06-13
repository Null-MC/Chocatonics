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
