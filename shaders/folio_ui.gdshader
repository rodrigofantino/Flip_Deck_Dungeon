shader_type canvas_item;

uniform float distortion_strength : hint_range(0.0, 0.08) = 0.02;
uniform float reflect_strength    : hint_range(0.0, 0.25) = 0.08;
uniform float alpha_strength      : hint_range(0.0, 0.25) = 0.06;

uniform vec2 foil_dir = vec2(0.0, 0.0);

void fragment() {
	/* Distorsión tipo vidrio */
	vec2 offset = foil_dir * distortion_strength * (UV - 0.5);
	vec4 base = texture(TEXTURE, UV + offset);

	/* Intensidad según tilt */
	float intensity = clamp(length(foil_dir), 0.0, 1.0);
	intensity = smoothstep(0.0, 1.0, intensity);

	/* Reflejo MUY sutil (no blanco) */
	base.rgb *= 1.0 + intensity * reflect_strength;

	/* Transparencia real */
	base.a *= intensity * alpha_strength;

	COLOR = base;
}
