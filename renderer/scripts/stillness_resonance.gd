# A quiet field around an anonymous body that has remained present and calm.
# Sustained stillness sends a restrained ripple outward, in dialogue with the
# aftereffect waves but without turning stillness into a command or a new family.
class_name StillnessResonance
extends Node2D

const GOLD := Color(1.0, 0.78, 0.38)
const RIPPLE_COLOR := Color(0.79, 0.87, 1.0)
const RING_SEGMENTS := 64
const RIPPLE_START_SCALE := 0.35
const RIPPLE_END_SCALE := 2.8
const RIPPLE_VISIBLE_AT := 0.18

var _sprite: Sprite2D
var _rings: Array[Line2D] = []
var _presence_time := 0.0
var _stillness := 0.0
var _min_presence_seconds := 3.0
var _pulse_seconds := 6.0
var _max_scale := 1.3
var _ripple_duration_seconds := 5.8
var _ripple_interval_seconds := 3.3
var _ripple_radius := 48.0
var _ripple_alpha := 0.22
var _ripple_threshold := 0.32
var _elapsed := 0.0
var _strength := 0.0

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = _make_field_texture(256)
	add_child(_sprite)
	_create_rings()
	_refresh()

func configure(config: Dictionary) -> void:
	_min_presence_seconds = max(float(config.get("min_presence_seconds", 3.0)), 0.1)
	_pulse_seconds = max(float(config.get("pulse_seconds", 6.0)), 0.5)
	_max_scale = max(float(config.get("max_scale", 1.3)), 0.1)
	_ripple_duration_seconds = max(float(config.get("ripple_duration_seconds", 5.8)), 0.5)
	_ripple_interval_seconds = max(float(config.get("ripple_interval_seconds", 3.3)), 0.5)
	_ripple_radius = max(float(config.get("ripple_radius", 48.0)), 4.0)
	_ripple_alpha = clamp(float(config.get("ripple_alpha", 0.22)), 0.0, 1.0)
	_ripple_threshold = clamp(float(config.get("ripple_threshold", 0.32)), 0.0, 1.0)
	if is_node_ready():
		_refresh()

func update_state(pos: Vector2, presence_time: float, stillness: float) -> void:
	global_position = pos
	_presence_time = max(presence_time, 0.0)
	_stillness = clamp(stillness, 0.0, 1.0)
	if is_node_ready():
		_refresh()

func _process(delta: float) -> void:
	_elapsed += delta
	var maturity: float = clamp(_presence_time / _min_presence_seconds, 0.0, 1.0)
	var target_strength: float = maturity * _stillness
	_strength = move_toward(_strength, target_strength, delta * 0.7)
	_update_rings()
	_refresh()

func _create_rings() -> void:
	for index in range(2):
		var ring := Line2D.new()
		ring.width = 1.5
		ring.default_color = RIPPLE_COLOR
		ring.closed = true
		ring.antialiased = true
		ring.z_index = 1
		for point_index in range(RING_SEGMENTS):
			var angle := TAU * float(point_index) / float(RING_SEGMENTS)
			ring.add_point(Vector2(cos(angle), sin(angle)) * _ripple_radius)
		add_child(ring)
		_rings.append(ring)
	_update_rings()

func _update_rings() -> void:
	for index in range(_rings.size()):
		var ring := _rings[index]
		var phase: float = fposmod((_elapsed + float(index) * _ripple_interval_seconds * 0.5) / _ripple_duration_seconds, 1.0)
		var can_emit := _strength >= _ripple_threshold
		var envelope := 0.0
		if can_emit:
			if phase < RIPPLE_VISIBLE_AT:
				envelope = lerp(0.0, 0.55, phase / RIPPLE_VISIBLE_AT)
			else:
				envelope = 0.55 * (1.0 - (phase - RIPPLE_VISIBLE_AT) / (1.0 - RIPPLE_VISIBLE_AT))
		ring.visible = can_emit and envelope > 0.005
		if not ring.visible:
			continue
		var scale_factor := lerp(RIPPLE_START_SCALE, RIPPLE_END_SCALE, phase)
		ring.scale = Vector2(scale_factor, scale_factor)
		ring.modulate = Color(1.0, 1.0, 1.0, envelope * _ripple_alpha * _strength)

func _refresh() -> void:
	if _sprite == null:
		return
	var maturity: float = clamp(_presence_time / _min_presence_seconds, 0.0, 1.0)
	var strength: float = maturity * _stillness
	_sprite.visible = strength > 0.002
	if not _sprite.visible:
		return
	var pulse: float = 0.92 + 0.08 * sin(TAU * _elapsed / _pulse_seconds)
	var radius: float = (0.45 + strength * _max_scale) * pulse
	_sprite.scale = Vector2(radius, radius)
	_sprite.modulate = Color(GOLD.r * 1.3, GOLD.g * 1.3, GOLD.b * 1.3, 0.10 + strength * 0.32)

func _make_field_texture(size: int) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.52, 0.76, 1.0])
	gradient.colors = PackedColorArray([
		Color(GOLD.r, GOLD.g, GOLD.b, 0.0),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.0),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.7),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = size
	texture.height = size
	return texture
