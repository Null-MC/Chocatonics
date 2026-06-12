#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

in vec4 mc_Entity;
in vec4 mc_midTexCoord;

#ifdef MC_NORMAL_MAP
	in vec4 at_tangent;
#endif

out vec4 lmtexcoord;
out vec4 color;
out vec4 normalMat;

#ifdef POM
	out vec4 vtexcoordam; // .st for add, .pq for mul
	out vec4 vtexcoord;
#endif

#ifdef MC_NORMAL_MAP
	out vec4 tangent;
#endif

uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec2 texelSize;
uniform int framemod8;

const float PI48 = 150.796447372 * WAVY_SPEED;
float pi2wt = PI48 * frameTimeCounter;


vec4 toClipSpace3(const in vec3 viewSpacePosition) {
	return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
}

vec2 calcWave(in vec3 pos) {
    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos), vec4(1.0, 0.005, 0.005, 0.005))) * 0.5 + 0.72) * 0.013;
	return (sin(pi2wt * vec2(0.0063, 0.0015) * 4.0 - pos.xz + pos.y * 0.05) + 0.1) * magnitude;
}

vec3 calcMovePlants(in vec3 pos) {
	vec2 move1 = calcWave(pos );
	float move1y = -length(move1);
	return vec3(move1.x, move1y, move1.y) * 5.0 * WAVY_STRENGTH;
}

vec3 calcWaveLeaves(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {
    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos), vec4(1.0, 0.005, 0.005, 0.005))) * 0.5 + 0.72) * 0.013;
	vec3 ret = (sin(pi2wt*vec3(0.0063,0.0224,0.0015)*1.5 - pos))*magnitude;

    return ret;
}

vec3 calcMoveLeaves(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWaveLeaves(pos, 0.0054, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
    return move1*5.*WAVY_STRENGTH;
}


void main() {
	lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	lmtexcoord.zw = gl_MultiTexCoord1.xy / 255.0;

	#ifdef POM
		vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texcoordminusmid = lmtexcoord.xy - midcoord;
		vtexcoordam.pq  = abs(texcoordminusmid) * 2.0;
		vtexcoordam.st  = min(lmtexcoord.xy, midcoord - texcoordminusmid);
		vtexcoord.xy    = sign(texcoordminusmid) * 0.5 + 0.5;
	#endif

	vec3 position = mul3(gl_ModelViewMatrix, gl_Vertex.xyz);
	color = gl_Color;

	bool istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t;
	#ifdef MC_NORMAL_MAP
		tangent = vec4(normalize(gl_NormalMatrix * at_tangent.rgb), at_tangent.w);
	#endif

	normalMat.xyz = normalize(gl_NormalMatrix * gl_Normal);
	normalMat.w = mc_Entity.x == 10004 || mc_Entity.x == 10003 || mc_Entity.x == 10001 ? 0.5 : 1.0;

	if (mc_Entity.x == 10006) normalMat.a = 0.6;

	#ifdef WAVY_PLANTS
		if ((mc_Entity.x == 10001 && istopv) && abs(position.z) < 64.0) {
    		vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz + cameraPosition;
			worldpos.xyz += calcMovePlants(worldpos.xyz) * lmtexcoord.w - cameraPosition;
    		position = mul3(gbufferModelView, worldpos);
		}

		if (mc_Entity.x == 10003 && abs(position.z) < 64.0) {
    		vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz + cameraPosition;
			worldpos.xyz += calcMoveLeaves(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0,0.2,1.0), vec3(0.5,0.1,0.5))*lmtexcoord.w  - cameraPosition;
    		position = mul3(gbufferModelView, worldpos);
		}
	#endif

	if (mc_Entity.x == 10005) {
		color.rgb = normalize(color.rgb) * sqrt(3.0);
		normalMat.a = 0.9;
	}

	gl_Position = toClipSpace3(position);

	#ifdef SEPARATE_AO
		lmtexcoord.z *= sqrt(color.a);
		lmtexcoord.w *= color.a;
	#else
		color.rgb *= color.a;
	#endif

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
