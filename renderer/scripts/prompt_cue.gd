# A quiet visual cue for the idle invitation, not a gesture instruction.
class_name PromptCue
extends Control

const TRAIL_FRACTION := 0.62

var reveal: float = 0.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		queue_redraw()

var intensity: float = 0.0:
	set(value):
		intensity = clampf(value, 0.0, 1.0)
		queue_redraw()

var trail_alpha: float = 1.0:
	set(value):
		trail_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()

var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	if intensity > 0.0:
		queue_redraw()

func _draw() -> void:
	if intensity <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var centre := size * 0.5 + Vector2(0.0, -16.0)
	# Several nearly transparent ellipses make a slow, visible breathing space
	# around the words without becoming a panel or a second visual target.
	draw_set_transform(centre, 0.0, Vector2(1.7, 0.52))
	for ring in range(4):
		var radius := 145.0 + float(ring) * 42.0
		var alpha := (0.030 - float(ring) * 0.005) * intensity
		draw_circle(Vector2.ZERO, radius, Color(0.25, 0.58, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var half_width := minf(size.x * 0.29, 280.0)
	var start := Vector2(centre.x - half_width, centre.y + 86.0)
	var end := Vector2(centre.x + half_width, centre.y + 86.0)
	# A lone star leaves a long, warm tail. Both disappear three seconds after
	# arrival; no permanent divider remains under a resting invitation.
	var star := start.lerp(end, reveal)
	# Once the star has moved far enough, its oldest light has already faded.
	# The tail therefore slides and dissolves from left to right while the star
	# is still travelling, instead of becoming a completed static underline.
	var tail_start_progress := maxf(0.0, reveal - TRAIL_FRACTION)
	var tail_span := maxf(reveal - tail_start_progress, 0.001)
	const tail_segments := 24
	for segment in range(tail_segments):
		var segment_start := tail_start_progress + tail_span * float(segment) / float(tail_segments)
		var segment_end := tail_start_progress + tail_span * float(segment + 1) / float(tail_segments)
		var freshness := float(segment + 1) / float(tail_segments)
		var alpha := 0.90 * intensity * trail_alpha * freshness * freshness
		draw_line(start.lerp(end, segment_start), start.lerp(end, segment_end), Color(1.0, 0.86, 0.52, alpha), 2.5, true)
	_draw_star(star, trail_alpha)

func _draw_star(position: Vector2, accent_alpha: float) -> void:
	var pulse := 0.82 + sin(_time * 2.3) * 0.18
	var glow := intensity * accent_alpha * pulse
	draw_circle(position, 16.0, Color(1.0, 0.78, 0.33, 0.06 * glow))
	draw_circle(position, 9.0, Color(1.0, 0.84, 0.48, 0.16 * glow))
	draw_circle(position, 3.0, Color(1.0, 0.96, 0.78, 0.98 * glow))
	var ray := 8.0 + 4.0 * pulse
	draw_line(position - Vector2(ray, 0.0), position + Vector2(ray, 0.0), Color(1.0, 0.88, 0.58, 0.78 * glow), 1.2, true)
	draw_line(position - Vector2(0.0, ray), position + Vector2(0.0, ray), Color(1.0, 0.88, 0.58, 0.78 * glow), 1.2, true)
