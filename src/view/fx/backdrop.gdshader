shader_type canvas_item;
// Battle backdrop: vertical navy gradient with a soft teal glow pooled
// behind the board so the field reads as lit from within.

uniform vec3 top_color = vec3(0.020, 0.038, 0.066);
uniform vec3 bottom_color = vec3(0.038, 0.075, 0.094);
uniform vec3 glow_color = vec3(0.075, 0.20, 0.235);
uniform vec2 glow_center = vec2(0.5, 0.42);
uniform float glow_radius = 0.62;

void fragment() {
	vec3 col = mix(top_color, bottom_color, UV.y);
	float dist = distance(UV * vec2(1.778, 1.0), glow_center * vec2(1.778, 1.0));
	col += glow_color * smoothstep(glow_radius, 0.0, dist);
	COLOR = vec4(col, 1.0);
}
