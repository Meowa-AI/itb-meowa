shader_type canvas_item;
// Subtle ripple for water tiles: tiny horizontal sway + brightness shimmer.

uniform float strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	uv.x += sin(TIME * 1.3 + UV.y * 14.0) * 0.0035 * strength;
	vec4 col = texture(TEXTURE, uv);
	col.rgb *= 1.0 + sin(TIME * 1.7 + UV.x * 9.0 + UV.y * 4.0) * 0.045 * strength;
	COLOR = col;
}
