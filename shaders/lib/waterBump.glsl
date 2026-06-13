vec4 smoothfilter(in sampler2D tex, in vec2 uv) {
	uv = uv*512.0 + 0.5;
	vec2 iuv = floor(uv);
	vec2 fuv = fract(uv);
	uv = iuv + (fuv * fuv) * (3.0 - 2.0*fuv);
	uv = uv/512.0 - 0.5/512.0;
	return texture(tex, uv);
}

mat2 getWaterRotation(const in float radiance) {
	float cos_rad = cos(radiance);
	float sin_rad = sin(radiance);

	return mat2(
		vec2(cos_rad, -sin_rad),
		vec2(sin_rad,  cos_rad));
}

float getWaterHeightmap(vec2 posxz, float iswater) {
	vec2 pos = posxz;
	float moving = saturate(iswater * 2.0 - 1.0);
	vec2 movement = vec2(-0.005 * frameTimeCounter*moving, 0.0);
	float caustic = 0.0;
	float weightSum = 0.0;

	const float radiance = 2.39996;
	mat2 rotationMatrix = getWaterRotation(radiance);

	for (int i = 0; i < 4; i++) {
		vec2 displ = texture(noisetex, pos/32.0/1.74/1.74 + movement).bb * 2.0 - 1.0;
    	float wave = texture(texWave, (pos * vec2(3.0, 1.0)/128.0 + movement + displ/128.0) * exp(float(i))).a;

		float w = exp(float(-i));
		caustic += wave * w;
		weightSum += w;

		pos = rotationMatrix * pos;
	}

	return caustic / weightSum;
}

vec3 getWaveHeight(vec2 posxz, float iswater){
	vec2 pos = posxz;
	float moving = saturate(iswater * 2.0 - 1.0);
	vec2 movement = vec2(-0.005 * frameTimeCounter * moving, 0.0);
	vec3 caustic = vec3(0.0);
	float weightSum = 0.0;

	const float radiance = 2.39996;
	mat2 rotationMatrix = getWaterRotation(radiance);

	vec2 displ = texture(noisetex, pos/32.0 + movement).bb * 2.0 - 1.0;

	for (int i = 0; i < 4; i++) {
		vec2 displ = texture2D(noisetex, pos/32.0/1.74/1.74 + movement).bb * 2.0 - 1.0;
    	vec3 wave = texture2D(texWave, (pos * vec2(3.0, 1.0) / 128.0 + movement + displ / 128.0) * exp(float(i))).rgb;

		// Hardcoded normalization
		// The python script will output these values
		wave = wave * vec3(0.28517825805472996, 0.36291568757087544, 0.02637002277616962) + vec3(-0.1532914212634342, -0.13959442174921308, 0.9736299772192376);

		float w = exp(float(-i));
		caustic += wave * w;
		weightSum += w;

		pos = rotationMatrix * pos;
	}

	return normalize(caustic / weightSum);
}
