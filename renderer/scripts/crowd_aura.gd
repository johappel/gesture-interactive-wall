# Shared atmospheric light field for a group of people.
#
# crowd_aura is not an effect for one person. It belongs to the group as a
# whole and makes visible that several people share the same resonance space
# for a moment. It is deliberately not a bigger glow, not a cloud of individual
# auras and not a reward that switches on at a fixed head count.
#
# The field is derived only from already available anonymous data: the current
# body positions, the crowd count and crowd.energy. No new capture signal and
# no protocol change are required. The manager owns a single full-viewport
# shader surface; it never creates one node per person.
class_name CrowdAura
extends Node2D

const CrowdAuraShader := preload("res://shaders/crowd_aura.gdshader")

# Time constant for the slow reshaping of centre and extent. People move inside
# a shared field; the field must not chase every small pose deviation.
const SHAPE_SMOOTHING_SECONDS := 1.6
# A compact group still needs a readable field, so the hull never collapses to
# a point.
const MIN_HALF_EXTENT := Vector2(0.16, 0.14)
# Must match MAX_BODIES in the shader. The array is fixed so no allocation is
# needed per frame.
const MAX_BODIES := 16

var _material := ShaderMaterial.new()
# Preallocated, fixed-size: positions never allocate per frame.
var _body_positions: PackedVector2Array = PackedVector2Array()

var _min_people := 3
var _full_strength_people := 10
var _fade_in_seconds := 2.5
var _fade_out_seconds := 4.0
var _pulse_seconds := 9.0
var _padding := 0.12
var _softness := 0.18
var _min_alpha := 0.04
var _max_alpha := 0.20
var _energy_influence := 0.30
var _individual_dimming_max := 0.45
var _body_clearance := 0.13
var _gap_emphasis := 0.75
var _warm_color := "#ffe3a1"
var _cool_color := "#5caeff"

var _strength := 0.0
var _centre := Vector2(0.5, 0.5)
var _half_extent := Vector2(0.35, 0.30)
var _energy := 0.0
var _elapsed := 0.0
var _has_shape := false


func _init() -> void:
	_material.shader = CrowdAuraShader
	material = _material
	z_index = -2
	_body_positions.resize(MAX_BODIES)
	_body_positions.fill(Vector2(-1.0, -1.0))


func configure(config: Dictionary) -> void:
	_min_people = max(_int_value(config, "min_people", 3), 1)
	_full_strength_people = max(_int_value(config, "full_strength_people", 10), _min_people)
	_fade_in_seconds = max(_number(config, "fade_in_seconds", 2.5), 0.05)
	_fade_out_seconds = max(_number(config, "fade_out_seconds", 4.0), 0.05)
	_pulse_seconds = max(_number(config, "pulse_seconds", 9.0), 0.5)
	_padding = clampf(_number(config, "padding", 0.12), 0.0, 0.6)
	_softness = clampf(_number(config, "softness", 0.18), 0.01, 0.9)
	_min_alpha = clampf(_number(config, "min_alpha", 0.04), 0.0, 0.5)
	_max_alpha = clampf(_number(config, "max_alpha", 0.20), _min_alpha, 0.6)
	_energy_influence = clampf(_number(config, "energy_influence", 0.30), 0.0, 1.0)
	_individual_dimming_max = clampf(_number(config, "individual_dimming_max", 0.45), 0.0, 1.0)
	_body_clearance = clampf(_number(config, "body_clearance", 0.13), 0.02, 0.5)
	_gap_emphasis = clampf(_number(config, "gap_emphasis", 0.75), 0.0, 1.0)
	_warm_color = _color_string(config, "warm_color", "#ffe3a1")
	_cool_color = _color_string(config, "cool_color", "#5caeff")
	_push_parameters()


# Called every frame with the current collective state. `positions` are the
# normalised (0..1) body positions of the current frame. An empty array means
# no one is present; the field then fades out smoothly instead of vanishing.
func update_crowd(positions: Array, count: int, energy: float, delta: float) -> void:
	_elapsed += delta
	var target_strength := _target_strength(count)
	var smoothing := _fade_in_seconds if target_strength > _strength else _fade_out_seconds
	_strength = _approach(_strength, target_strength, smoothing, delta)

	if not positions.is_empty():
		var target_centre := Vector2.ZERO
		var min_point := Vector2(1.0, 1.0)
		var max_point := Vector2.ZERO
		for position in positions:
			target_centre += position
			min_point = min_point.min(position)
			max_point = max_point.max(position)
		target_centre /= float(positions.size())
		var target_extent := (max_point - min_point) * 0.5 + Vector2(_padding, _padding)
		target_extent = target_extent.max(MIN_HALF_EXTENT)
		if not _has_shape:
			_centre = target_centre
			_half_extent = target_extent
			_has_shape = true
		else:
			_centre = _approach_vector(_centre, target_centre, SHAPE_SMOOTHING_SECONDS, delta)
			_half_extent = _approach_vector(_half_extent, target_extent, SHAPE_SMOOTHING_SECONDS, delta)

	# The per-body clearances are intentionally NOT smoothed: the field must
	# stay clear exactly where a body actually is right now, otherwise a moving
	# person would briefly sit inside the atmosphere and blur into it.
	_update_body_positions(positions)

	_energy = _approach(_energy, clampf(energy, 0.0, 1.0), SHAPE_SMOOTHING_SECONDS, delta)
	_push_parameters()
	queue_redraw()


func _update_body_positions(positions: Array) -> void:
	for index in range(MAX_BODIES):
		if index < positions.size():
			_body_positions[index] = positions[index]
		else:
			# Park unused slots far outside the field so they never subtract.
			_body_positions[index] = Vector2(-1.0, -1.0)


# 0..1 weight of the collective representation. main.gd derives the individual
# weight from it so that person-bound effects gently recede as the group grows.
func collective_weight() -> float:
	return _strength


# 0..1 multiplier for person-bound effects. Never zero: people stay visible.
func individual_weight() -> float:
	return 1.0 - _strength * _individual_dimming_max


func _target_strength(count: int) -> float:
	if count < _min_people:
		return 0.0
	var span := float(_full_strength_people - (_min_people - 1))
	if span <= 0.0:
		return 1.0
	return clampf(float(count - (_min_people - 1)) / span, 0.0, 1.0)


func _push_parameters() -> void:
	var size := _viewport_size()
	_material.set_shader_parameter("centre_uv", _centre)
	_material.set_shader_parameter("half_extent", _half_extent)
	_material.set_shader_parameter("aspect_ratio", size.x / max(size.y, 1.0))
	_material.set_shader_parameter("softness", _softness)
	_material.set_shader_parameter("padding", _padding)
	_material.set_shader_parameter("strength", _strength)
	_material.set_shader_parameter("min_alpha", _min_alpha)
	_material.set_shader_parameter("max_alpha", _max_alpha)
	_material.set_shader_parameter("energy", _energy)
	_material.set_shader_parameter("energy_influence", _energy_influence)
	_material.set_shader_parameter("pulse_phase", TAU * _elapsed / _pulse_seconds)
	_material.set_shader_parameter("glow_strength", 1.25)
	_material.set_shader_parameter("body_count", _active_body_count())
	_material.set_shader_parameter("body_positions", _body_positions)
	_material.set_shader_parameter("body_clearance", _body_clearance)
	_material.set_shader_parameter("gap_emphasis", _gap_emphasis)
	_material.set_shader_parameter("warm_color", Color.from_string(_warm_color, Color(1.0, 0.89, 0.63)))
	_material.set_shader_parameter("cool_color", Color.from_string(_cool_color, Color(0.36, 0.68, 1.0)))


# Only slots inside the viewport hold a real body; parked slots use negative
# coordinates and must not count.
func _active_body_count() -> int:
	var count := 0
	for index in range(MAX_BODIES):
		var point := _body_positions[index]
		if point.x >= 0.0 and point.x <= 1.0 and point.y >= 0.0 and point.y <= 1.0:
			count += 1
	return count


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _viewport_size()), Color.WHITE)


# get_viewport_rect() is only valid inside the scene tree. configure() may run
# before the node is added, so a safe fallback keeps the shader parameters
# finite until the first real frame.
func _viewport_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2(1920.0, 1080.0)


func _approach(current: float, target: float, seconds: float, delta: float) -> float:
	if seconds <= 0.0:
		return target
	var factor := 1.0 - exp(-delta / seconds)
	return current + (target - current) * factor


func _approach_vector(current: Vector2, target: Vector2, seconds: float, delta: float) -> Vector2:
	if seconds <= 0.0:
		return target
	var factor := 1.0 - exp(-delta / seconds)
	return current + (target - current) * factor


func _number(config: Dictionary, key: String, default_value: float) -> float:
	var value = config.get(key, default_value)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var number := float(value)
		if not is_nan(number) and not is_inf(number):
			return number
	return default_value


func _int_value(config: Dictionary, key: String, default_value: int) -> int:
	var value = config.get(key, default_value)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var number := float(value)
		if not is_nan(number) and not is_inf(number):
			return int(number)
	return default_value


func _color_string(config: Dictionary, key: String, default_value: String) -> String:
	var value = config.get(key, default_value)
	if typeof(value) == TYPE_STRING and Color.from_string(str(value), Color.TRANSPARENT) != Color.TRANSPARENT:
		return str(value)
	return default_value