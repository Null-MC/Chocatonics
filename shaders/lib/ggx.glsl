void frisvad(in vec3 n, out vec3 f, out vec3 r) {
    if (n.z < -0.9) {
        f = vec3(0, -1, 0);
        r = vec3(-1, 0, 0);
    } else {
        float a = 1.0 / (1.0 + n.z);
        float b = -n.x*n.y*a;
        f = vec3(1.0 - n.x*n.x*a, b, -n.x) ;
        r = vec3(b, 1.0 - n.y*n.y*a , -n.y);
    }
}

mat3 CoordBase(vec3 n) {
    vec3 x, y;
    frisvad(n, x, y);
    return mat3(x, y, n);
}

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

vec3 sampleGGXVNDF(vec3 view, vec2 alpha, float U1, float U2, bool ishand) {
    // stretch view
    vec3 V = normalize(vec3(alpha.xy * view.xy, view.z));

    // orthonormal basis
    vec3 T1 = (V.z < 0.9999) ? normalize(cross(V, vec3(0, 0, 1))) : vec3(1, 0, 0);
    vec3 T2 = cross(T1, V);

    // sample point with polar coordinates (r, phi)
    float a = 1.0 / (1.0 + V.z);
    float r = sqrt(U1);
    float phi = (U2 < a) ? U2/a * PI : PI + (U2-a)/(1.0-a) * PI;
    float P1 = r * cos(phi);
    float P2 = r * sin(phi) * ((U2 < a) ? 1.0 : V.z);

    // compute normal
    vec3 N = P1*T1 + P2*T2 + sqrt(max(0.0, 1.0 - P1*P1 - P2*P2)) * V;

    // unstretch
    return normalize(vec3(alpha.xy * N.xy, max(0.0, N.z)));
}
