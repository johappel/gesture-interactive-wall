# A quiet field around an anonymous body that has remained present and calm.
# It is deliberately not a command reward: time and observed low motion blend
# continuously into a slow, related pulse on façade and monitor preview.
class_name StillnessResonance
extends Node2D

const GOLD := Color(1.0, 0.78, 0.38)

var _sprite: Sprite2D
var _presence_time := 0.0
var _stillness := 0.0
var _min_presence_seconds := 3.0
var _pulse_seconds := 6.0
var _max_scale := 1.3
var _elapsed := 0.0

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = _make_field_texture(256)
	add_child(_sprite)
	_refresh()

func configure(config: Dictionary) -> void:
	_min_presence_seconds = max(float(config.get("min_presence_seconds", 3.0)), 0.1)
	_pulse_seconds = max(float(config.get("pulse_seconds", 6.0)), 0.5)
	_max_scale = max(float(config.get("max_scale", 1.3)), 0.1)
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
	_refresh()

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
