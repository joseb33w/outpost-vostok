shader_type sky;
uniform sampler2D panorama : filter_linear, hint_default_black; // NO source_color — read raw linear radiance
uniform float exposure : hint_range(0.0, 16.0) = 1.0;
const float PI = 3.14159265359;
void sky() {
	vec3 d = normalize(EYEDIR);
	vec2 uv = vec2(atan(d.x, d.z) / (2.0 * PI) + 0.5, acos(clamp(d.y, -1.0, 1.0)) / PI);
	vec3 rad = texture(panorama, uv).rgb * exposure;
	// pre-encode sRGB so the sky pass's srgb_to_linear(COLOR) cancels it -> true linear HDR into tonemap
	vec3 a = vec3(0.055);
	COLOR = mix(rad * 12.92, (1.0 + a) * pow(max(rad, vec3(0.0)), vec3(1.0 / 2.4)) - a, step(vec3(0.0031308), rad));
}
