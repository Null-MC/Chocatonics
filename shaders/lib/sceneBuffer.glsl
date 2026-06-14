#ifdef WRITE_SCENE
    #define SCENE_ATTR
#else
    #define SCENE_ATTR readonly
#endif


layout(std430, binding = 0) SCENE_ATTR buffer sceneData {
    float centerDepth;
    float exposure;
    float rodExposure;
    float avgBrightness;
    float avgL2;

    vec3 ambientUp;
    vec3 ambientLeft;
    vec3 ambientRight;
    vec3 ambientDown;
    vec3 ambientB;
    vec3 ambientF;
    vec3 avgSky;

    vec3 sunColor;
    vec3 sunColorCloud;
    vec3 moonColor;
    vec3 moonColorCloud;
    vec3 lightSourceColor;

    vec2 tempOffsets;

    float fogAmount;
    float VFAmount;
} scene;
