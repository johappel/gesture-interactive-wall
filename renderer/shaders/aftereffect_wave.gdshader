shader_type canvas_item;
render_mode unshaded, blend_add;

// A diffuse light resonance, deliberately without a contour or water texture.
uniform vec2 origin_uv = vec2(1.05, 0.5);
uniform float radius = 0.03;
uniform float band_width = 0.09;
uniform float source_glow_radius = 0.16;
uniform float echo_spacing = 0.15;
uniform float echo_strength = 0.28;
uniform float aspect_ratio = 1.0;
uniform float intensity = 0.28;
uniform float progress = 0.0;
uniform float fade_start_progress = 0.15;
uniform float fade_end_progress = 0.92;
uniform float glow_strength = 1.55;
uniform vec4 warm_color : source_color = vec4(1.0, 0.94, 0.74, 1.0);
uniform vec4 blue_color : source_color = vec4(0.36, 0.68, 1.0, 1.0);

float gaussian_band(float value, float centre, float width) {
	float normalized = (value - centre) / max(width, 0.0001);
	return exp(-normalized * normalized * 2.0);
}

void fragment() {
	vec2 delta = UV - origin_uv;
	delta.x *= aspect_ratio;
	float distance_from_origin = length(delta);

	// The broad main resonance has no hard centre line. A much wider halo and
	// one faint inner echo let it dissolve into the night rather than read as UI.
	float main_band = gaussian_band(distance_from_origin, radius, band_width);
	float halo = gaussian_band(distance_from_origin, radius, band_width * 2.8) * 0.34;
	float echo_radius = max(radius - echo_spacing, 0.0);
	float echo = gaussian_band(distance_from_origin, echo_radius, band_width * 1.65) * echo_strength;
	float source = gaussian_band(distance_from_origin, 0.0, source_glow_radius) * (1.0 - progress);
	float field = main_band + halo + echo + source * 0.72;

	vec3 travelling_colour = mix(warm_color.rgb, blue_color.rgb, smoothstep(0.08, 0.92, progress));
	vec3 colour = mix(travelling_colour, warm_color.rgb, clamp(source, 0.0, 1.0));
	// The wave starts to recede well before it reaches the facade centre and
	// arrives at zero opacity before the manager releases its shader surface.
	// smoothstep keeps both ends soft: no visible switch-off at its lifetime end.
	float fade = 1.0 - smoothstep(fade_start_progress, fade_end_progress, progress);
	float alpha = clamp(field * intensity * fade, 0.0, 0.72);
	COLOR = vec4(colour * glow_strength, alpha);
}
