float getWaterHeightmap(vec2 posxz, float iswater) {
	const float radiance = 2.39996;
	const float cos_rad = cos(radiance);
	const float sin_rad = sin(radiance);
	const mat2 rotationMatrix = mat2(
		vec2(cos_rad, -sin_rad),
		vec2(sin_rad,  cos_rad));

	float moving = saturate(iswater * 2.0 - 1.0);
	vec2 movement = vec2(-0.005 * frameTimeCounter * moving);
	vec2 pos = posxz * vec2(3.0, 1.0)/128.0 + movement;

	float caustic = 0.0;
	float weightSum = 0.0;

	for (int i = 0; i < 3; i++) {
    	float wave = texture(noisetex, pos * exp(i)).b;

		float w = exp(-i);
		caustic += wave * w;
		weightSum += w;

		pos = rotationMatrix * pos;
	}

	return caustic / weightSum;
}
