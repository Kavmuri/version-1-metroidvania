shader_type canvas_item;
render_mode unshaded;

uniform vec4 shield_color : source_color = vec4(0.18, 0.75, 1.0, 0.70);
uniform float radius : hint_range(0.2, 0.5) = 0.43;
uniform float thickness : hint_range(0.01, 0.15) = 0.05;
uniform float softness : hint_range(0.001, 0.05) = 0.01;
uniform float pulse_speed : hint_range(0.1, 8.0) = 2.5;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float angle = atan(centered_uv.y, centered_uv.x);
	float moving_wave = sin(angle * 10.0 - TIME * 3.0) * 0.006;
	float distance_from_center = length(centered_uv) + moving_wave;

	float outer_circle = 1.0 - smoothstep(radius, radius + softness, distance_from_center);
	float inner_circle = 1.0 - smoothstep(
		radius - thickness,
		radius - thickness + softness,
		distance_from_center
	);
	float ring = max(outer_circle - inner_circle, 0.0);
	float pulse = 0.8 + sin(TIME * pulse_speed) * 0.2;
	float inner_fill = outer_circle * 0.08;
	float alpha = (inner_fill + ring * pulse) * shield_color.a * strength;
	vec3 final_color = mix(
		shield_color.rgb,
		vec3(1.0),
		clamp(ring * 0.45 + hit_flash, 0.0, 1.0)
	);
	alpha += outer_circle * hit_flash * 0.35;
	COLOR = vec4(final_color, clamp(alpha, 0.0, 1.0));
}
