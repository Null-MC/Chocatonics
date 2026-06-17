#version 430 compatibility

// Photonics world-space reflection accumulation

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


//in VertexData {
//} vIn;

uniform sampler2D depthtex0;
uniform sampler2D colortex3;
uniform sampler2D colortex13;
uniform sampler2D TEX_GB_COLOR;
uniform sampler2D TEX_GB_SPECULAR;

uniform vec2 texelSize;


/* RENDERTARGETS: 3,14 */
layout(location = 0) out vec4 outFinal;
layout(location = 1) out vec4 outHistory;

void main() {
	vec2 texcoord = gl_FragCoord.xy * texelSize;
	float z = texture(depthtex0, texcoord).x;

	ivec2 uv = ivec2(gl_FragCoord.xy);
	vec3 dest_color = texelFetch(colortex3, uv, 0).rgb;
	vec4 reflect_color = vec4(0.0);

	if (z < 1.0) {
		vec4 color = texture(TEX_GB_COLOR, texcoord);
		vec3 albedo = toLinear(color.rgb);

		vec4 specularData = texture(TEX_GB_SPECULAR, texcoord);
		float f0 = specularData.g;

		reflect_color = texelFetch(colortex13, uv, 0);

		vec3 final_color = reflect_color.rgb;

		// check if the f0 is within the metal ranges, then tint by albedo if it's true.
		final_color *= mix(vec3(1.0), albedo, f0 > 229.5/255.0);

		dest_color += final_color;
	}

	dest_color = clamp(dest_color, 0.000001, 65000.0);
	reflect_color.rgb = clamp(reflect_color.rgb, 0.000001, 65000.0);

	outFinal = vec4(dest_color, 1.0);
	outHistory = reflect_color;
}
