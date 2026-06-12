void modify_light(inout Light light, vec3 world_pos) {
    light.color /= light.intensity;

    light.color = toLinear(saturate(light.color));

    light.color *= light.intensity;

    light.color *= 5.0;
}
