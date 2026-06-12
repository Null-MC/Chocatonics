#define NO_SHADOW_MAPPING

uniform sampler2D colortex4;

uniform vec3 sunPosition;
uniform float sunElevation;

#include "/lib/bicubic.glsl"
#include "/lib/sky_gradient.glsl"


vec3 get_sun_direction() {
    vec3 localSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);

    return (float(sunElevation > 1.e-5) * 2.0 - 1.0) * localSunDir;
}

vec3 get_sun_color(vec3 playerPos, vec3 direction) {
    return texelFetch(colortex4, ivec2(6, 37), 0).rgb / 150.0;
}

vec3 get_sky_color(vec3 playerPos, vec3 direction) {
    vec3 color = skyFromTex(direction, colortex4) / 150.0;
    return clamp(color * 8.0/3.0, 0.0, 65000.0);
}

// bool is_in_shadow_at(vec3 scene_pos, vec3 geo_normal) {
//     //
// }
