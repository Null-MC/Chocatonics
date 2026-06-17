vec3 blackbody(float Temp) {
    float t = pow(Temp, -1.5);
    float lt = log(Temp);

    vec3 col = vec3(0.0);
    col.x = 220000.0 * t + 0.58039215686;
    col.y = 0.39231372549 * lt - 2.44549019608;
    col.y = Temp > 6500. ? 138039.215686 * t + 0.72156862745 : col.y;
    col.z = 0.76078431372 * lt - 5.68078431373;
    col = saturate(col);
    col = Temp < 1000. ? col * Temp * 0.001 : col;

    return srgbToLinear(col);
}
