vec3 modify_attenuation(
    const in Light light,
    const in vec3 to_light,
    const in vec3 sample_pos,
    const in vec3 source_pos,
    const in vec3 geometry_normal,
    const in vec3 texture_normal
) {
    float lightDistSq = dot(to_light, to_light);
    float lightDistInv = inversesqrt(lightDistSq);
    float lightDist = lightDistSq * lightDistInv;
    vec3 light_dir = to_light * lightDistInv;

//    float att = 1.0 / (lightDistSq * light.falloff * light.attenuation.y + light.attenuation.x);
    float att = 1.0 / (lightDistSq + 1.0);

    float NoLm = max(dot(texture_normal, light_dir), 0.0);
    NoLm *= step(EPSILON, dot(geometry_normal, light_dir));

    return att * NoLm * light.color;
}
