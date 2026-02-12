shader_type canvas_item;

uniform float radius : hint_range(0.0, 0.5) = 0.08;
uniform float aa : hint_range(0.0, 0.05) = 0.01;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = UV * 2.0 - 1.0;
	float r = clamp(radius, 0.0, 0.5);
	vec2 b = vec2(1.0 - r);
	vec2 q = abs(p) - b;
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	float alpha = 1.0 - smoothstep(0.0, aa, dist);
	COLOR = vec4(tex.rgb * tint_color.rgb, tex.a * alpha * tint_color.a);
}
