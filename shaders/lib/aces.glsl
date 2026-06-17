const float ToneMap_Saturation = 0.8;
const float DIM_SURROUND_GAMMA = 0.9811;
const float ODT_SAT_FACTOR = 0.93;


const float HALF_MAX = 65000.0;

const vec3 AP1_RGB2Y = vec3(0.272229, 0.674082, 0.0536895);

const mat3 D60_2_D65_CAT = mat3(
     0.98722400, -0.00759836,  0.00307257,
    -0.00611327,  1.00186000, -0.00509595,
     0.01595330,  0.00533020,  1.08168000);

const mat3 AP1_2_XYZ_MAT = mat3(
    0.6624541811, 0.2722287168, -0.0055746495,
    0.1340042065, 0.6740817658,  0.0040607335,
    0.1561876870, 0.0536895174,  1.0103391003);

const mat3 XYZ_2_AP1_MAT = mat3(
     1.6410233797, -0.6636628587,  0.0117218943,
    -0.3248032942,  1.6153315917, -0.0082844420,
    -0.2364246952,  0.0167563477,  0.9883948585);

const mat3 XYZ_2_REC709_MAT = mat3(
     3.2409699419, -0.9692436363,  0.0556300797,
    -1.5373831776,  1.8759675015, -0.2039769589,
    -0.4986107603,  0.0415550574,  1.0569715142);


vec3 XYZ_2_xyY(vec3 XYZ) {
    float divisor = max(dot(XYZ, (1.0).xxx), 1e-4);
    return vec3(XYZ.xy / divisor, XYZ.y);
}

vec3 xyY_2_XYZ(vec3 xyY) {
    float m = xyY.z / max(xyY.y, 1e-4);
    vec3 XYZ = vec3(xyY.xz, (1.0 - xyY.x - xyY.y));
    XYZ.xz *= m;
    return XYZ;
}

float ACEScct_from_Linear(float lin) {
    if (lin > 0.0078125)
    return log2(lin) / 17.52 + (9.72/17.52);

    return lin * 10.5402377416545 + 0.0729055341958355;
}

vec3 ACEScct_from_Linear(vec3 lin) {
    return vec3(
        ACEScct_from_Linear(lin.r),
        ACEScct_from_Linear(lin.g),
        ACEScct_from_Linear(lin.b));
}

float Linear_from_ACEScct(float cct) {
    if (cct > 0.155251141552511)
    return exp2(cct * 17.52 - 9.72);

    return cct / 10.5402377416545 - (0.0729055341958355/10.5402377416545);
}

vec3 Linear_from_ACEScct(vec3 cct) {
    return vec3(
        Linear_from_ACEScct(cct.r),
        Linear_from_ACEScct(cct.g),
        Linear_from_ACEScct(cct.b));
}

vec3 ACES_DarkToDimSurround(vec3 linearCV) {
    vec3 XYZ = AP1_2_XYZ_MAT * linearCV;

    vec3 xyY = XYZ_2_xyY(XYZ);
    xyY.z = clamp(xyY.z, 0.0, HALF_MAX);
    xyY.z = pow(xyY.z, DIM_SURROUND_GAMMA);
    XYZ = xyY_2_XYZ(xyY);

    return XYZ_2_AP1_MAT * XYZ;
}

vec3 ApplyRRT(const in vec3 aces_cg) {
    // --- Global desaturation --- //
    vec3 x = mix(vec3(dot(aces_cg, AP1_RGB2Y)), aces_cg, ToneMap_Saturation);

    // Luminance fitting of *RRT.a1.0.3 + ODT.Academy.RGBmonitor_100nits_dim.a1.0.3*.
    // https://github.com/colour-science/colour-unity/blob/master/Assets/Colour/Notebooks/CIECAM02_Unity.ipynb
    // RMSE: 0.0012846272106
    const float a = 278.5085;
    const float b =  10.7772;
    const float c = 293.6045;
    const float d =  88.7122;
    const float e =  80.6889;

    return (x * (a * x + b)) / (x * (c * x + d) + e);
}

vec3 ApplyODT(const in vec3 rgb_post) {
    // Apply gamma adjustment to compensate for dim surround
    vec3 linear_CV = ACES_DarkToDimSurround(rgb_post);

    // Apply desaturation to compensate for luminance difference
    linear_CV = mix(vec3(dot(linear_CV, AP1_RGB2Y)), linear_CV, ODT_SAT_FACTOR);

    vec3 XYZ = AP1_2_XYZ_MAT * linear_CV;
    XYZ = D60_2_D65_CAT * XYZ;

    vec3 final = XYZ_2_REC709_MAT * XYZ;
    return saturate(final);
}
