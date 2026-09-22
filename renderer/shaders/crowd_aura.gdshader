shader_type canvas_item;
render_mode unshaded, blend_add;

// A shared atmospheric light field for a group of people.
//
// This is deliberately not a cloud, fog or force field. It is a soft, slowly
// breathing membrane of light whose shape follows the spatial spread of the
// group. The field is strongest in the shared space between people and fades
// gently outward, so the "we" appears as a change of the space between bodies
// rather than as one more body.

uniform vec2 centre_uv = vec2(0.5, 0.5);
uniform vec2 half_extent = vec2(0.35, 0.30);
uniform float aspect_ratio = 1.0;
uniform float softness = 0.18;
uniform float padding = 0.12;
uniform float strength = 0.0;
uniform float min_alpha = 0.04;
uniform float max_alpha = 0.20;
uniform float energy = 0.0;
uniform float energy_influence = 0.30;
uniform float pulse_phase = 0.0;
uniform float inner_contrast = 0.35;
uniform float glow_strength = 1.25;
uniform vec4 warm_color : source_color = vec4(1.0, 0.89, 0.63, 1.0);
uniform vec4 cool_color : source_color = vec4(0.36, 0.68, 1.0, 1.0);

// A soft, low-frequency breathing of the whole field. It never switches on or
// off; it only modulates an already present atmosphere.
float breathe(float phase) {
	return 0.5 + 0.5 * sin(phase);
}

void fragment() {
	vec2 delta = UV - centre_uv;
	delta.x *= aspect_ratio;
	// Normalised elliptical distance: 0 at the group centre, 1 at the padded
	// hull edge. The group's real spread sets half_extent, so a wide group
	// produces a wide field and a compact group a concentrated one.
	vec2 scaled = delta / max(half_extent, vec2(0.0001));
	float radial = length(scaled);

	// Wide, soft outer boundary. No hard edge, no visible contour.
	float outer = 1.0 - smoothstep(1.0 - softness, 1.0 + padding, radial);
	// A gentle inner emphasis makes the shared space between people readable
	// without drawing individual silhouettes.
	float inner = 1.0 - smoothstep(0.0, 0.85, radial);
	float field = outer * (1.0 - inner_contrast) + inner * inner_contrast;

	// Energy only animates the field; it never decides whether it exists.
	float breath = breathe(pulse_phase);
	float energy_sway = mix(1.0, 0.75 + 0.5 * breath, clamp(energy_influence, 0.0, 1.0) * clamp(energy, 0.0, 1.0));
	float alpha = clamp(field * strength * energy_sway, 0.0, 1.0);
	alpha = mix(min_alpha, max_alpha, alpha) * step(0.0001, strength);

	// Warm in the shared centre, gently cooler toward the outer atmosphere.
	vec3 colour = mix(warm_color.rgb, cool_color.rgb, clamp(radial * 0.85, 0.0, 1.0));
	COLOR = vec4(colour * glow_strength, alpha);
}