shader_type canvas_item;
// Full-screen grade: gentle contrast/saturation lift, teal shadow tint,
// vignette, and a whisper of animated grain. Applied above every screen.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.30;
uniform float saturation = 1.07;
uniform float contrast = 1.045;
uniform vec3 shadow_tint = vec3(0.90, 1.0, 1.08);
uniform float grain_amount : hint_range(0.0, 0.2) = 0.020;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	col = (col - 0.5) * contrast + 0.5;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = mix(col * shadow_tint, col, smoothstep(0.0, 0.55, luma));

	float dist = length((SCREEN_UV - 0.5) * vec2(1.25, 1.0)) * 1.41421;
	col *= 1.0 - smoothstep(0.55, 1.15, dist) * vignette_strength;

	float grain = fract(sin(dot(SCREEN_UV + fract(TIME), vec2(12.9898, 78.233))) * 43758.5453);
	col += (grain - 0.5) * grain_amount;

	COLOR = vec4(col, 1.0);
}
