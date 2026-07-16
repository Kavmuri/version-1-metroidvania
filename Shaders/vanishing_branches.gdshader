shader_type canvas_item;

uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D noise_texture : hint_default_white;
uniform float dissolve_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float edge_sharpness : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);

	// Obtener el valor de ruido
	vec4 noise = texture(noise_texture, UV * 2.0 + TIME * 0.2);
	float noise_value = noise.r;

	// Crear el efecto de desvanecimiento basado en el ruido
	float fade_threshold = dissolve_threshold + (noise_value - 0.5) * edge_sharpness;
	float fade = smoothstep(fade_threshold - 0.1, fade_threshold + 0.1, alpha);

	// Aplicar el efecto
	COLOR = texture_color;
	COLOR.a = texture_color.a * fade * alpha;
}
