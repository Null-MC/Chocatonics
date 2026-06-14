#version 430 compatibility

// Prepare dynamic uniforms

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

uniform sampler2D texSkyGradient;
uniform sampler2D colortex6;

//uniform vec3 sunVec;
uniform int frameCounter;
uniform float rainStrength;
uniform float sunElevation;
uniform float eyeAltitude;
uniform float nightVision;
uniform vec2 texelSize;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;

#define WRITE_SCENE
#include "/lib/sceneBuffer.glsl"

#include "/lib/r2.glsl"
#include "/lib/util.glsl"
#include "/lib/bicubic.glsl"
//#include "/lib/blueNoise.glsl"
#include "/lib/ROBOBO_sky.glsl"
#include "/lib/sky_gradient.glsl"


vec3 sunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);

vec3 rodSample(vec2 Xi) {
    float r = sqrt(1.0f - Xi.x*Xi.y);
    float phi = 2.0 * PI * Xi.y;

    return normalize(vec3(cos(phi) * r, sin(phi) * r, Xi.x)).xzy;
}


void main() {
    vec3 ambientUp = vec3(0.0);
    vec3 ambientDown = vec3(0.0);
    vec3 ambientLeft = vec3(0.0);
    vec3 ambientRight = vec3(0.0);
    vec3 ambientB = vec3(0.0);
    vec3 ambientF = vec3(0.0);
    vec3 avgSky = vec3(0.0);

    // Integrate sky light for each block side
    int maxIT = 20;
    for (int i = 0; i < maxIT; i++) {
        vec2 ij = R2_samples((frameCounter % 1000) * maxIT + i);
        vec3 pos = normalize(rodSample(ij));

        vec3 samplee = 1.72 * skyFromTex(pos, texSkyGradient).rgb / maxIT;
        avgSky += samplee / 1.72;

        ambientUp += samplee * (pos.y + abs(pos.x)/7.0 + abs(pos.z)/7.0);
        ambientLeft += samplee * (saturate(-pos.x) + saturate(pos.y/7.0) + abs(pos.z)/7.0);
        ambientRight += samplee * (saturate(pos.x) + saturate(pos.y/7.0) + abs(pos.z)/7.0);
        ambientDown += samplee * (saturate(pos.y / 6.0) + abs(pos.x)/7.0 + abs(pos.z)/7.0);
        ambientB += samplee * (saturate(pos.z) + abs(pos.x)/7.0 + saturate(pos.y/7.0));
        ambientF += samplee * (saturate(-pos.z) + abs(pos.x)/7.0 + saturate(pos.y/7.0));
    }

    vec2 planetSphere = vec2(0.0);
    vec3 sky = vec3(0.0);
    vec3 skyAbsorb = vec3(0.0);

    float sunVis = clamp(sunElevation, 0.0, 0.05) / 0.05 * clamp(sunElevation, 0.0, 0.05) / 0.05;
    float moonVis = clamp(-sunElevation, 0.0, 0.05) / 0.05 * clamp(-sunElevation, 0.0, 0.05) / 0.05;

    const float dSun = 0.03;
    const vec3 up = vec3(0.0, 1.0, 0.0);

    // TODO: unused?
    vec2 tempOffsets = R2_samples(frameCounter % 10000);

    vec3 zenithColor = calculateAtmosphere(vec3(0.0), up, up, sunVec, -sunVec, planetSphere, skyAbsorb, 25, tempOffsets.x);

    skyAbsorb = vec3(0.0);
    vec3 absorb = vec3(0.0);

    vec3 sunColor = calculateAtmosphere(vec3(0.0), sunVec, up, sunVec, -sunVec, planetSphere, skyAbsorb, 25, 0.0);
    sunColor = sunColorBase / 4000.0 * skyAbsorb;

    skyAbsorb = vec3(1.0);

    vec3 modSunVec = sunVec * (1.0 - dSun) + vec3(0.0, dSun, 0.0);
    vec3 modSunVec2 = sunVec * (1.0 - dSun) + vec3(0.0, dSun, 0.0);
    if (modSunVec2.y > modSunVec.y) modSunVec = modSunVec2;

    vec3 sunColorCloud = calculateAtmosphere(vec3(0.0), modSunVec, up, sunVec, -sunVec, planetSphere, skyAbsorb, 25, 0.0);
    sunColorCloud = sunColorBase / 4000.0 * skyAbsorb;

    skyAbsorb = vec3(1.0);

    vec3 moonColor = calculateAtmosphere(vec3(0.0), -sunVec, up, sunVec, -sunVec, planetSphere, skyAbsorb, 25, 0.5);
    moonColor = moonColorBase / 4000.0 * skyAbsorb;

    skyAbsorb = vec3(1.0);

    modSunVec = -sunVec * (1.0 - dSun) + vec3(0.0, dSun, 0.0);
    modSunVec2 = -sunVec * (1.0 - dSun) + vec3(0.0, dSun, 0.0);
    if (modSunVec2.y > modSunVec.y) modSunVec = modSunVec2;

    vec3 moonColorCloud = calculateAtmosphere(vec3(0.0), modSunVec, up, sunVec, -sunVec, planetSphere, skyAbsorb, 25, 0.5);
    moonColorCloud = moonColorBase / 4000.0 * 0.55;

    #ifndef CLOUDS_SHADOWS
        sunColor *= (1.0 - rainStrength * vec3(0.96));
        moonColor *= (1.0 - rainStrength * vec3(0.96));
    #endif

    vec3 lightSourceColor = sunVis >= 1e-5 ? sunColor * sunVis : moonColor * moonVis;

    scene.sunColor = sunColor;
    scene.sunColorCloud = sunColorCloud;
    scene.moonColor = moonColor;
    scene.moonColorCloud = moonColorCloud;
    scene.lightSourceColor = lightSourceColor;

    float lightDir = float(sunVis >= 1e-5) * 2.0 - 1.0;

    // Fake bounced sunlight
    vec3 bouncedSun = lightSourceColor * 0.1/5.0 * 0.5 * saturate(lightDir * sunVec.y) * saturate(lightDir * sunVec.y);
    vec3 cloudAmbientSun = sunColorCloud * (1.0-rainStrength*0.5);
    vec3 cloudAmbientMoon = moonColorCloud * (1.0-rainStrength*0.5);

    ambientUp += bouncedSun * clamp(-lightDir*sunVec.y+4.0,0.0,4.0) + cloudAmbientSun*clamp(sunVec.y+2.,0.,4.0) + cloudAmbientMoon*clamp(-sunVec.y+2.,0.,4.0);
    ambientLeft += bouncedSun * clamp(lightDir*sunVec.x+4.0,0.0,4.0) + cloudAmbientSun*clamp(-sunVec.x+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(sunVec.x+2.,0.0,4.)*0.7;
    ambientRight += bouncedSun * clamp(-lightDir*sunVec.x+4.0,0.0,4.0) + cloudAmbientSun*clamp(sunVec.x+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(-sunVec.x+2.,0.0,4.)*0.7;
    ambientDown += bouncedSun * clamp(lightDir*sunVec.y+4.0,0.0,4.0)*0.7 + cloudAmbientSun*clamp(-sunVec.y+2.,0.0,4.)*0.5 + cloudAmbientMoon*clamp(sunVec.y+2.,0.0,4.)*0.5;
    ambientB += bouncedSun * clamp(-lightDir*sunVec.z+4.0,0.0,4.0) + cloudAmbientSun*clamp(sunVec.z+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(-sunVec.z+2.,0.0,4.)*0.7;
    ambientF += bouncedSun * clamp(lightDir*sunVec.z+4.0,0.0,4.0) + cloudAmbientSun*clamp(-sunVec.z+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(sunVec.z+2.,0.0,4.)*0.7;

    avgSky += bouncedSun * 2.5;

    vec3 rainNightBoost = moonColorCloud * rainStrength * 0.05;

    ambientUp += rainNightBoost;
    ambientLeft += rainNightBoost;
    ambientRight += rainNightBoost;
    ambientDown += rainNightBoost;
    ambientB += rainNightBoost;
    ambientF += rainNightBoost;
    avgSky += rainNightBoost;

    scene.ambientUp = ambientUp;
    scene.ambientLeft = ambientLeft;
    scene.ambientRight = ambientRight;
    scene.ambientDown = ambientDown;
    scene.ambientB = ambientB;
    scene.ambientF = ambientF;
    scene.avgSky = avgSky;

    float avgLuma = 0.0;
    float m2 = 0.0;
    int n = 100;
    float avgExp = 0.0;
    float avgB = 0.0;

    vec2 clampedRes = max(1.0/texelSize, vec2(1920.0, 1080.0));
    vec2 resScale = vec2(1920.0, 1080.0) / clampedRes * BLOOM_QUALITY;

    const int maxITexp = 50;
    float w = 0.0;
    for (int i = 0; i < maxITexp; i++) {
        vec2 ij = R2_samples((frameCounter % 2000) * maxITexp + i);
        vec2 tc = 0.5 + (ij-0.5) * 0.7;
        vec3 sp = texture(colortex6, tc/16.0 * resScale + vec2(0.375*resScale.x + 4.5*texelSize.x, 0.0)).rgb;
        avgExp += log(luma(sp));
        avgB += log(min(dot(sp, vec3(0.07, 0.22, 0.71)), 8.e-2));
    }

    avgExp = exp(avgExp / maxITexp);
    avgB = exp(avgB / maxITexp);

    float avgBrightness = clamp(mix(avgExp, scene.avgBrightness, 0.95), 0.00003051757, 65000.0);
    scene.avgBrightness = avgBrightness;

    float L = max(avgBrightness, 1.e-8);
    float keyVal = 1.03 - 2.0 / (log(L*4000 * 8.0/3.0 + 1.0) / log(10.0) + 2.0);
    float targetExposure = 0.18 / log2(L*2.5 + 1.040 - nightVision*0.038) * 0.7;

    float avgL2 = mix(avgB, scene.avgL2, 0.985);
    scene.avgL2 = clamp(avgL2, 0.00003051757, 65000.0);

    scene.rodExposure = max(0.012 / log2(scene.avgL2 + 1.002) - 0.1, 0.0) * 1.2;

    scene.exposure = targetExposure * EXPOSURE_MULTIPLIER;

//    scene.rodExposure = targetrodExposure;

    #ifndef AUTO_EXPOSURE
        scene.exposure = Manual_exposure_value;
        scene.rodExposure = clamp(log(Manual_exposure_value * 2.0 + 1.0) - 0.1, 0.0, 2.0);
    #endif



//    float modWT = float(worldTime % 24000);
//
//    float fogAmount0 = 1.0/3000.0+FOG_TOD_MULTIPLIER*(1.0/100.0*(clamp(modWT-11000.0,0.0,2000.0)/2000.0+(1.0-clamp(modWT,0.0,3000.0)/3000.0))*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.)) + 1/120.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.));
//    vOut.VFAmount = CLOUDY_FOG_AMOUNT * (fogAmount0*fogAmount0 + FOG_RAIN_MULTIPLIER*1.0/20000.0*rainStrength);
//    vOut.fogAmount = BASE_FOG_AMOUNT*(fogAmount0+max(FOG_RAIN_MULTIPLIER*1.0/10.0*rainStrength , FOG_TOD_MULTIPLIER*1.0/50.0*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.)));



    // Temporally accumulate sky and light values
//    vec3 temp = texelFetch(colortex4, ivec2(gl_FragCoord.xy), 0).rgb;
//    vec3 curr = outColor4.rgb * 150.0;
//
//    outColor4.rgb = clamp(mix(temp, curr, 0.06), 0.0, 65000.0);

    // Exposure values
//    if (gl_FragCoord.x > 10.0 && gl_FragCoord.x < 11.0 && gl_FragCoord.y > 19.0 + 18.0 && gl_FragCoord.y < 19.0 + 18.0 + 1.0)
//        outColor4 = vec4(vIn.exposure, vIn.avgBrightness, vIn.avgL2, 1.0);
//
//    if (gl_FragCoord.x > 14.0 && gl_FragCoord.x < 15.0 && gl_FragCoord.y > 19.0 + 18.0 && gl_FragCoord.y < 19.0 + 18.0 + 1.0)
//        outColor4 = vec4(vIn.rodExposure, vIn.centerDepth, 0.0, 1.0);
}
