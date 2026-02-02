shader_type canvas_item;

uniform float top_scale_x : hint_range(0.5, 1.0) = 1.0;
uniform float anchor_x : hint_range(0.0, 1.0) = 0.5;
uniform bool flip_h = false;

void fragment() {
	float t = clamp(UV.y, 0.0, 1.0);
	float scale_x = mix(top_scale_x, 1.0, t);
	vec2 uv = UV;
	if (flip_h) { uv.x = 1.0 - uv.x; }
	uv.x = (uv.x - anchor_x) / scale_x + anchor_x;
	COLOR = texture(TEXTURE, uv);
}
