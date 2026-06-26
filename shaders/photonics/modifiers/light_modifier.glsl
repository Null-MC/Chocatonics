void modify_light(inout Light light, vec3 world_pos) {
    light.color /= light.intensity;

    light.color = InputTransform(saturate(light.color));

    light.color *= 2.0 * light.intensity;
}
