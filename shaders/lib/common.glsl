const float PI = acos(-1.0);
//const float pi = 3.141592653589793238462643383279502884197169;

const float EPSILON = 1.e-6;


#define lumCoeff vec3(0.2125, 0.7154, 0.0721)

#define saturate(x) clamp(x, 0.0, 1.0)

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

#define mul3(m,v) (mat3(m) * v + m[3].xyz)

#define projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

#define fsign(x) (saturate(x * 1e35) * 2.0 - 1.0)
#define fstep(x,y) saturate((y - x) * 1e35)


//float facos(float sx) {
//    float x = saturate(abs(sx));
//    return sqrt(1.0 - x) * (-0.16882 * x + 1.56734);
//}
float facos(const in float sx) {
    float x = saturate(abs(sx));
    float a = sqrt(1.0 - x) * (-0.16882 * x + 1.56734);
    return sx > 0.0 ? a : PI - a;
}

float luma(const in vec3 color) {
    return dot(color, lumCoeff);
}

vec3 toLinear(const in vec3 sRGB){
    return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}


const vec2[8] taa_offsets = vec2[8](
    vec2(1./8.,-3./8.),
    vec2(-1.,3.)/8.,
    vec2(5.0,1.)/8.,
    vec2(-3,-5.)/8.,
    vec2(-5.,5.)/8.,
    vec2(-7.,-1.)/8.,
    vec2(3,7.)/8.,
    vec2(7.,-7.)/8.);
