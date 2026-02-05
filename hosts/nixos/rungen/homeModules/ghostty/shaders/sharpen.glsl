float SHARPEN_STRENGTH = 0.70;
float RADIUS_PX = 1.00;
float EDGE_THRESHOLD = 0.015;
float CLAMP_MAX = 0.060;

float luma(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  vec2 texel = 1.0 / iResolution.xy;
  vec2 d = texel * RADIUS_PX;

  vec3 c = texture(iChannel0, uv).rgb;
  vec3 l = texture(iChannel0, uv + vec2(-d.x, 0.0)).rgb;
  vec3 r = texture(iChannel0, uv + vec2(d.x, 0.0)).rgb;
  vec3 u = texture(iChannel0, uv + vec2(0.0, -d.y)).rgb;
  vec3 dn = texture(iChannel0, uv + vec2(0.0, d.y)).rgb;

  vec3 blur = (c + l + r + u + dn) * 0.2;
  vec3 detail = c - blur;

  float e = abs(luma(c) - luma(blur));
  float mask = smoothstep(EDGE_THRESHOLD, EDGE_THRESHOLD * 4.0, e);

  detail = clamp(detail, vec3(-CLAMP_MAX), vec3(CLAMP_MAX));
  vec3 outColor = c + detail * (SHARPEN_STRENGTH * mask);

  fragColor = vec4(outColor, 1.0);
}