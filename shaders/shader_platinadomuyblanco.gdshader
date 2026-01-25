shader_type canvas_item;

uniform float distortion_strength : hint_range(0.0, 0.08) = 0.025;
uniform float reflect_strength    : hint_range(0.0, 0.3)  = 0.12;
uniform float alpha_strength      : hint_range(0.0, 0.3)  = 0.08;

uniform vec2 foil_dir = vec2(0.0, 0.0);

void fragment() {
	/* Distorsión tipo vidrio */
	vec2 offset = foil_dir * distortion_strength * (UV - 0.5);
	vec4 base = texture(TEXTURE, UV + offset);

	/* Fresnel simplificado (ángulo) */
	float fresnel = clamp(length(foil_dir), 0.0, 1.0);
	fresnel = pow(fresnel, 1.5);

	/* Reflexión suave (NO blanco puro) */
	base.rgb *= 1.0 + fresnel * reflect_strength;

	/* Transparencia variable */
	base.a *= 1.0 - fresnel * alpha_strength;

	COLOR = base;
}
