#version 430 compatibility

// Horizontal bilateral blur for volumetric fog + Forward rendered objects + Draw volumetric fog

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


flat in vec3 zMults;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex7;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform int frameCounter;
uniform float far;
uniform float near;
uniform int isEyeInWater;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec2 texelSize;
uniform vec3 cameraPosition;

uniform mat4 gbufferProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

#include "/lib/projections.glsl"
#include "/lib/waterOptions.glsl"
#include "/lib/color_transforms.glsl"


vec4 BilateralUpscale(sampler2D tex, sampler2D depth, vec2 coord, float frDepth) {
    vec4 vl = vec4(0.0);
    float sum = 0.0;
    mat3x3 weights;

    const ivec2 scaling = ivec2(1.0/VL_RENDER_RESOLUTION);

    ivec2 posD = ivec2(coord * VL_RENDER_RESOLUTION) * scaling;
    ivec2 posVl = ivec2(coord * VL_RENDER_RESOLUTION);
    float dz = zMults.x;
    ivec2 pos = (ivec2(gl_FragCoord.xy + frameCounter) % 2) * 2;
    //pos = ivec2(1,-1);

    ivec2 tcDepth =  posD + ivec2(-2,-2) * scaling + pos * scaling;
    float dsample = ld_reverse(texelFetch(depth, tcDepth, 0).r, zMults.y, zMults.z);
    float w = abs(dsample-frDepth) < dz ? 1.0 : 1.e-5;
    vl += texelFetch(tex, posVl + ivec2(-2) + pos, 0) * w;
    sum += w;

    tcDepth =  posD + ivec2(-2,0) * scaling + pos * scaling;
    dsample = ld_reverse(texelFetch(depth ,tcDepth, 0).r, zMults.y, zMults.z);
    w = abs(dsample-frDepth) < dz ? 1.0 : 1.e-5;
    vl += texelFetch(tex, posVl + ivec2(-2, 0) + pos, 0) * w;
    sum += w;

    tcDepth =  posD + ivec2(0) + pos * scaling;
    dsample = ld_reverse(texelFetch(depth, tcDepth, 0).r, zMults.y, zMults.z);
    w = abs(dsample-frDepth) < dz ? 1.0 : 1.e-5;
    vl += texelFetch(tex, posVl + ivec2(0) + pos, 0) * w;
    sum += w;

    tcDepth =  posD + ivec2(0,-2) * scaling + pos * scaling;
    dsample = ld_reverse(texelFetch(depth, tcDepth, 0).r, zMults.y, zMults.z);
    w = abs(dsample-frDepth) < dz ? 1.0 : 1.e-5;
    vl += texelFetch(tex, posVl + ivec2(0, -2) + pos, 0) * w;
    sum += w;

    return vl / sum;
}

float getWaterHeightmap(vec2 posxz, float iswater) {
	vec2 pos = posxz;
    float moving = saturate(iswater * 2.0 - 1.0);
	vec2 movement = vec2(-0.005 * frameTimeCounter * moving, 0.0);
	float caustic = 0.0;
	float weightSum = 0.0;

	const float radiance =  2.39996;
    const float cos_rad = cos(radiance);
    const float sin_rad = sin(radiance);

    const mat2 rotationMatrix  = mat2(
        vec2(cos_rad, -sin_rad),
        vec2(sin_rad,  cos_rad));

	for (int i = 1; i < 3; i++) {
		vec2 displ = texture(noisetex, pos / 32.0/1.74/1.74 + movement).bb * 2.0 - 1.0;

        float wave = texture(noisetex, (pos * vec2(3.0, 1.0) / 128.0 + movement + displ/128.0) * exp(float(i))).b;
        float w = exp(float(-i));
		caustic += wave * w;
		weightSum += w;

		pos = rotationMatrix * pos;
	}

	return caustic / weightSum;
}


/* RENDERTARGETS: 7,3 */
layout(location = 0) out float outColor7;
layout(location = 1) out vec3 outColor3;

void main() {
    vec2 texcoord = gl_FragCoord.xy * texelSize;

    //3x3 bilateral upscale from half resolution
    float z = texture(depthtex0, texcoord).x;
    float frDepth = ld_reverse(z, zMults.y, zMults.z);

    vec4 vl = BilateralUpscale(colortex0, depthtex0, gl_FragCoord.xy, frDepth);

    vec4 transparencies = texture(colortex2, texcoord);
    vec4 trpData = texture(colortex7, texcoord);
    bool iswater = trpData.a > 0.99;

    #ifdef PHOTONICS_REFRACTION_ENABLED
        vec3 tex_normal = ; // TODO

        vec3 viewPos = toScreenSpace(vec3(texcoord, z));
        vec3 viewDir = normalize(viewPos);

        float eta = ; // TODO
        vec3 refractViewDir = refract(viewDir, tex_normal, eta);

        vec3 localPos = mul3(gbufferModelViewInverse, viewPos);
        vec3 refractLocalDir = mat3(gbufferModelViewInverse) * refractViewDir;

        RayIterator ray;
        ray.iterations = PHOTONICS_REFLECT_STEPS;
        ray_iter_set_position(ray, localPos + rt_camera_position);
        ray_iter_set_direction(ray, refractLocalDir);
        ray_iter_offset_position(ray, 0.004 * geoLocalNormal);

        vec3 radiance = vec3(0.0);
        vec3 transmittance = vec3(1.0);

        bool bounce_hit = true;
        for (int bounce = 0; bounce < PHOTONICS_REFLECT_BOUNCES; bounce++) {
            RayResult hit = ray_iter_next(ray);
            bounce_hit = ray_result_is_hit(hit);
            if (!bounce_hit || !ray_iter_is_in_bounds(ray)) break;

            vec3 hit_position = ray_result_position(hit);

            VoxelData voxel_data = ray_result_voxel_data(hit);
            vec3 hit_albedo = voxel_data_albedo(voxel_data).rgb;

            // TODO
        }
    #else
        vec2 refractedCoord = texcoord;

        if (iswater) {
    //        vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(0.0)*texelSize*0.5,z));
            vec3 fragpos = toScreenSpace(vec3(texcoord, z));
            vec3 np3 = mul3(gbufferModelViewInverse, fragpos) + cameraPosition;
            float norm = getWaterHeightmap(np3.xz + np3.y, 1.0) - 0.5;
            float displ = norm / (length(fragpos) / far) / 2000.0 * (isEyeInWater*2.0 + 1.0);
            refractedCoord += displ * RENDER_SCALE;

            if (texture(colortex7, refractedCoord).a < 0.99)
                refractedCoord = texcoord;
        }

        vec3 color = texture(colortex3, refractedCoord).rgb;

        if (!iswater) {
            // multiplicative tinting
            vec3 albedo_translucent = InputTransform(trpData.rgb);
            albedo_translucent = normalize(albedo_translucent + EPSILON) / sqrt(3.0);
            color *= mix(vec3(1.0), albedo_translucent, sqrt(transparencies.a));
        }
    #endif

    if (frDepth > 2.5/far || transparencies.a < 0.99)  // Discount fix for transparencies through hand
        color = color * (1.0 - transparencies.a) + transparencies.rgb * 10.0;

    float dirtAmount = Dirt_Amount;
    vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
    vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
    vec3 totEpsilon = dirtEpsilon * dirtAmount + waterEpsilon;

    color *= vl.a;

    if (isEyeInWater == 1) {
        vec3 fragpos = toScreenSpace(vec3(texcoord, z));
        color.rgb *= exp(-length(fragpos) * totEpsilon);
        vl.a *= dot(exp(-length(fragpos) * totEpsilon), vec3(0.2, 0.7, 0.1)) * 0.5 + 0.5;
    }

    if (isEyeInWater == 2) {
//        vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(0.0)*texelSize*0.5,z));
        vec3 fragpos = toScreenSpace(vec3(texcoord, z));
        color.rgb *= exp(length(fragpos) * vec3(0.2, 0.7, 4.0) * -4.0);
        color.rgb += vec3(4.0, 0.5, 0.1) * 0.5;
        vl.a = 0.0;
    }
    else {
        color += vl.rgb;
    }

    outColor7 = vl.a;
    outColor3 = clamp(color, 6.11*1.e-5, 65000.0);
}
