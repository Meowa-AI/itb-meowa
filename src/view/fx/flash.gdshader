shader_type canvas_item;
// Additive-style hit flash for unit sprites: lerps the sprite toward
// flash_color while `flash` is non-zero (tweened back to 0 from code).

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color = vec3(1.0, 1.0, 1.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	col.rgb = mix(col.rgb, flash_color, flash);
	COLOR = col;
}
