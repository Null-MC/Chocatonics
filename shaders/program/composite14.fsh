#version 430 compatibility

// Merge and upsample the blurs into a 1/4 res bloom buffer

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


uniform sampler2D colortex3;
uniform sampler2D colortex6;

uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;

#include "/lib/bicubic.glsl"


vec4 texture2D_bicubic(sampler2D tex, vec2 uv) {
	vec4 texelSize = vec4(texelSize, 1.0/texelSize);
	uv = uv*texelSize.zw;

	vec2 iuv = floor(uv);
	vec2 fuv = fract(uv);

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - 0.5) * texelSize.xy;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - 0.5) * texelSize.xy;

    return g0(fuv.y) * (g0x * texture(tex, p0)  +
                        g1x * texture(tex, p1)) +
           g1(fuv.y) * (g0x * texture(tex, p2)  +
                        g1x * texture(tex, p3));
}


/* RENDERTARGETS: 3 */
layout(location = 0) out vec3 outColor3;

void main() {
    vec2 resScale = vec2(1920.0, 1080.0) / (max(vec2(viewWidth, viewHeight), vec2(1920.0, 1080.0)) / BLOOM_QUALITY);
    vec2 texcoord = (gl_FragCoord.xy * 2.0 + 0.5) * texelSize;

    vec3 bloom = texture2D_bicubic(colortex3, texcoord/2.0).rgb;	//1/4 res

    bloom += texture2D_bicubic(colortex6, texcoord/4.0).rgb; //1/8 res

    bloom += texture2D_bicubic(colortex6, texcoord/8.0+vec2(0.25*resScale.x+2.5*texelSize.x,.0)).rgb;  //1/16 res

    bloom += texture2D_bicubic(colortex6, texcoord/16.0+vec2(0.375*resScale.x+4.5*texelSize.x,.0)).rgb; //1/32 res

    bloom += texture2D_bicubic(colortex6, texcoord/32.0+vec2(0.4375*resScale.x+6.5*texelSize.x,.0)).rgb*1.0; //1/64 res
    bloom += texture2D_bicubic(colortex6, texcoord/64.0+vec2(0.46875*resScale.x+8.5*texelSize.x,.0)).rgb*1.0; //1/128 res
    bloom += texture2D_bicubic(colortex6, texcoord/128.0+vec2(0.484375*resScale.x+10.5*texelSize.x,.0)).rgb*1.0; //1/256 res

    //bloom = texture2D_bicubic(colortex6,texcoord).rgb*6.; //1/8 res

    outColor3 = bloom * 2.0;
    outColor3 = clamp(outColor3, 0.0, 65000.0);
}
