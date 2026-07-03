/*
const int colortex0Format = RGBA16F;			// low res clouds (deferred->composite2) + low res VL (composite5->composite15)
const int colortex1Format = RGBA16;				// terrain gbuffer (gbuffer->composite2)
const int colortex2Format = RGBA16F;			// forward + transparencies (gbuffer->composite4)
const int colortex3Format = R11F_G11F_B10F;		// frame buffer + bloom (deferred6->final)
const int colortex4Format = RGBA16F;			// light values and skyboxes (everything)
const int colortex5Format = R11F_G11F_B10F;		// TAA buffer (everything)
const int colortex6Format = R11F_G11F_B10F;		// additionnal buffer for bloom (composite3->final)
const int colortex7Format = RGBA8;			    // Final output, transparencies id (gbuffer->composite4)
const int colortex9Format = RGBA16;             // GBuffer Normals
const int colortex13Format = RGBA16F;            // Rough Reflection Trace
const int colortex14Format = RGBA16F;            // Rough Reflection History
*/
//no need to clear the buffers, saves a few fps
/*
const bool colortex0Clear = false;
const bool colortex1Clear = false;
const bool colortex2Clear = true;
const bool colortex3Clear = false;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
const bool colortex6Clear = false;
const bool colortex7Clear = true;
const bool colortex8Clear = true;
const bool colortex9Clear = false;
const bool colortex10Clear = false;
const bool colortex11Clear = false;
const bool colortex12Clear = false;
const bool colortex13Clear = false;
const bool colortex14Clear = false;
const bool colortex15Clear = false;
*/

const float PI = acos(-1.0);
const float EPSILON = 1.e-6;
const uint USHORT_MAX = uint(-1);

const float vxNearPlane = 16.0;
const float vxFarPlane = 16.0 * 3000.0;


#define BLOCK_SOLID USHORT_MAX

#define lumCoeff vec3(0.2125, 0.7154, 0.0721)

#define saturate(x) clamp(x, 0.0, 1.0)

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

#define mul3(m,v) (mat3(m) * (v) + m[3].xyz)

#define projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

#define fsign(x) (saturate(x * 1e35) * 2.0 - 1.0)

#define fstep(x,y) saturate((y - x) * 1e35)

#ifdef VOXY
    #define nearPlane near
    #define farPlane vxFarPlane
#else
    #define nearPlane near
    #define farPlane far
#endif


//float facos(float sx) {
//    float x = saturate(abs(sx));
//    return sqrt(1.0 - x) * (-0.16882 * x + 1.56734);
//}
float facos(const in float sx) {
    float x = saturate(abs(sx));
    float a = sqrt(1.0 - x) * (-0.16882 * x + 1.56734);
    return sx > 0.0 ? a : PI - a;
}

float depthNdcToLinear(float depth, float near, float far) {
    return (2.0 * near * far) / (far + near - depth * (far - near));
}

float depthScreenToLinear(float depth, float near, float far) {
    return depthNdcToLinear(depth * 2.0 - 1.0, near, far);
}

float depthLinearToNdc(float depth, float near, float far) {
    return (far + near - 2.0 * near * far / depth) / (far - near);
}

float depthLinearToScreen(float depth, float near, float far) {
    return depthLinearToNdc(depth, near, far) * 0.5 + 0.5;
}

float ld_reverse(float depth, float y, float z) {
    return 1.0 / (y - depth * z);
}

vec3 normVec(vec3 vec) {
    return vec * inversesqrt(dot(vec, vec));
}

float luma(const in vec3 color) {return dot(color, lumCoeff);}

float minOf(const in vec3 vec) {return min(min(vec[0], vec[1]), vec[2]);}

float maxOf(const in vec2 vec) {return max(vec[0], vec[1]);}
float maxOf(const in vec3 vec) {return max(vec[0], max(vec[1], vec[2]));}

int sumOf(ivec3 vec) {return vec.x + vec.y + vec.z;}
float sumOf(vec2 vec) {return vec.x + vec.y;}
float sumOf(vec3 vec) {return vec.x + vec.y + vec.z;}

float square(float x) {
    return x * x;
}

void applyLinear(inout vec3 color) {
    color = color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
}

vec3 toLinear(const in vec3 sRGB) {
    return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

float pow5(const in float value) {
    float value2 = value * value;
    return value2 * value2 * value;
}


#define TEX_GB_COLOR colortex8
#define TEX_GB_NORMAL colortex9
#define TEX_GB_SPECULAR colortex10
#define TEX_GB_WORLD colortex11
#define TEX_REFLECT_HISTORY colortex14

#define MAT_FORMAT_OLDPBR 1
#define MAT_FORMAT_LABPBR 2

const vec2[8] taa_offsets = vec2[8](
    vec2( 1.0, -3.0) / 8.0,
    vec2(-1.0,  3.0) / 8.0,
    vec2( 5.0,  1.0) / 8.0,
    vec2(-3.0, -5.0) / 8.0,
    vec2(-5.0,  5.0) / 8.0,
    vec2(-7.0, -1.0) / 8.0,
    vec2( 3.0,  7.0) / 8.0,
    vec2( 7.0, -7.0) / 8.0);
