shader_type canvas_item;

uniform float glow_strength : hint_range(0.0, 1.0) = 0.8;
uniform float speed : hint_range(0.1, 10.0) = 2.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float pulse = (sin(TIME * speed) * 0.5) + 0.5;
	vec3 glow_color = mix(tex_color.rgb, vec3(1.0), pulse * glow_strength);
	COLOR = vec4(glow_color, tex_color.a);
}
