vec3 cloud2D(vec3 fragpos, vec3 col) {
	vec3 wpos = fragpos;
	float wind = frameTimeCounter / 200.0;
	vec2 intersection = ((2000.0 - cameraPosition.y) * wpos.xz * inversesqrt(wpos.y + cameraPosition.y/512.0-50.0/512.0) + cameraPosition.xz + wind)/40000.0;

	float phase = pow(saturate(dot(fragpos, sunVec)), 2.0) * 0.5 + 0.5;
	
	float fbm = saturate((texture(noisetex, intersection * vec2(1.0, 1.5)).a + texture(noisetex, intersection * vec2(2.0, 7.0) + wind*0.4).a / 2.0) - 0.5*(1.0-rainStrength));

//	return mix(col, 6.0 * (vec3(0.9, 1.2, 1.5) * skyIntensityNight * 0.02 * (1.0 - 0.9*rainStrength) + 17.0*phase*nsunColor*skyIntensity*0.7*(1.0-rainStrength*0.9)), 0.0*(fbm*fbm)*(fbm*fbm) * (fbm * saturate(wpos.y * 0.9)));
	return mix(col, 6.0 * (vec3(0.9, 1.2, 1.5) * skyIntensityNight * 0.02 * (1.0 - 0.9*rainStrength) + 17.0*phase * nsunColor * skyIntensity*0.7 * (1.0 - 0.9*rainStrength)), 0.0);
}
