float shadow2D_bicubic(sampler2DShadow tex, vec3 sc) {
    vec2 uv = sc.xy * shadowMapResolution;
    vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

    vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - 0.5) / shadowMapResolution;
    vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - 0.5) / shadowMapResolution;
    vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - 0.5) / shadowMapResolution;
    vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - 0.5) / shadowMapResolution;

    return g0(fuv.y) * (g0x * texture(tex, vec3(p0,sc.z))  +
                        g1x * texture(tex, vec3(p1,sc.z))) +
           g1(fuv.y) * (g0x * texture(tex, vec3(p2,sc.z))  +
                        g1x * texture(tex, vec3(p3,sc.z)));
}
