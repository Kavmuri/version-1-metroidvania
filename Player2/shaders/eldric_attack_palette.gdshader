shader_type canvas_item;

uniform vec4 replacement_color : source_color = vec4(0.10, 0.85, 1.0, 1.0);
uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 vertex_color = COLOR;
	vec4 tex_color = texture(TEXTURE, UV);
	float cyan_dominance = min(tex_color.g, tex_color.b) - tex_color.r;
	float source_brightness = max(tex_color.r, max(tex_color.g, tex_color.b));
	float source_darkest = min(tex_color.r, min(tex_color.g, tex_color.b));
	float source_saturation = source_brightness - source_darkest;
	float cyan_mask = smoothstep(0.18, 0.38, cyan_dominance);
	float brightness_mask = smoothstep(0.50, 0.72, source_brightness);
	float saturation_mask = smoothstep(0.35, 0.55, source_saturation);
	float fire_mask = cyan_mask * brightness_mask * saturation_mask * tex_color.a;
	vec3 recolored = replacement_color.rgb * max(source_brightness, 0.35);
	vec3 final_color = mix(tex_color.rgb, recolored, fire_mask * effect_strength);
	COLOR = vec4(final_color, vertex_color.a);
}
