# Quiet, anonymous facade memory for plausible departures.
#
# This manager deliberately contains no drawing code: each grouped departure
# owns a full-viewport shader field. The shader's virtual origin travels out
# beyond the exit edge, so the visible part is a returning light resonance,
# not a line representing a person.
class_name AftereffectWaves
extends Node2D

const VALID_EDGES := ["left", "right", "top", "bottom"]
const AftereffectWaveFieldScript := preload("res://scripts/aftereffect_wave_field.gd")

var _pending: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _group_window_seconds: float = 0.22
var _group_distance: float = 0.18
var _duration_seconds: float = 4.8
var _field_config: Dictionary = {}


func configure(config: Dictionary) -> void:
	_group_window_seconds = maxf(_number(config, "group_window_seconds", 0.22), 0.0)
	_group_distance = clampf(_number(config, "group_distance", 0.18), 0.0, 1.0)
	_duration_seconds = maxf(_number(config, "duration_seconds", 4.8), 0.1)
	var fade_start_progress: float = clampf(_number(config, "fade_start_progress", 0.15), 0.0, 0.95)
	var fade_end_progress: float = clampf(_number(config, "fade_end_progress", 0.92), fade_start_progress + 0.01, 1.0)
	# A normalized, finite-only block lets the shader field remain safe if a
	# hand-edited config is incomplete or malformed.
	_field_config = {
		"duration_seconds": _duration_seconds,
		"group_width_per_departure": clampf(_number(config, "group_width_per_departure", 0.10), 0.0, 0.5),
		"initial_origin_outset": clampf(_number(config, "initial_origin_outset", 0.03), 0.0, 0.5),
		"origin_escape_distance": clampf(_number(config, "origin_escape_distance", 0.16), 0.0, 1.0),
		"start_radius": clampf(_number(config, "start_radius", 0.03), 0.001, 1.0),
		"propagation_speed": clampf(_number(config, "propagation_speed", 0.20), 0.001, 2.0),
		"band_width": clampf(_number(config, "band_width", 0.09), 0.01, 0.5),
		"source_glow_radius": clampf(_number(config, "source_glow_radius", 0.16), 0.01, 0.6),
		"echo_spacing": clampf(_number(config, "echo_spacing", 0.15), 0.0, 1.0),
		"echo_strength": clampf(_number(config, "echo_strength", 0.28), 0.0, 1.0),
		"max_alpha": clampf(_number(config, "max_alpha", 0.26), 0.01, 0.5),
		"fade_start_progress": fade_start_progress,
		"fade_end_progress": fade_end_progress,
		"glow_strength": clampf(_number(config, "glow_strength", 1.55), 0.1, 4.0),
		"warm_color": _color_string(config, "warm_color", "#fff0bd"),
		"blue_color": _color_string(config, "blue_color", "#5caeff"),
	}


func _number(config: Dictionary, key: String, default_value: float) -> float:
	var value = config.get(key, default_value)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var number: float = float(value)
		if not is_nan(number) and not is_inf(number):
			return number
	return default_value


func _color_string(config: Dictionary, key: String, default_value: String) -> String:
	var value = config.get(key, default_value)
	if typeof(value) == TYPE_STRING and Color.from_string(str(value), Color.TRANSPARENT) != Color.TRANSPARENT:
		return str(value)
	return default_value


func queue_departure(edge: String, x: float, y: float) -> void:
	if not (edge in VALID_EDGES):
		return
	var axis: float = y if edge == "left" or edge == "right" else x
	for pending in _pending:
		if pending["edge"] == edge and absf(float(pending["axis"]) - axis) <= _group_distance:
			var count: int = int(pending["count"])
			pending["axis"] = (float(pending["axis"]) * count + axis) / float(count + 1)
			pending["count"] = count + 1
			return
	_pending.append({"edge": edge, "axis": axis, "count": 1, "age": 0.0})


func clear() -> void:
	_pending.clear()
	for wave in _waves:
		var field = wave.get("field")
		if is_instance_valid(field):
			field.queue_free()
	_waves.clear()


func _process(delta: float) -> void:
	for index in range(_pending.size() - 1, -1, -1):
		var pending: Dictionary = _pending[index]
		pending["age"] = float(pending["age"]) + delta
		if float(pending["age"]) >= _group_window_seconds:
			_create_wave(str(pending["edge"]), float(pending["axis"]), int(pending["count"]))
			_pending.remove_at(index)

	for index in range(_waves.size() - 1, -1, -1):
		var wave: Dictionary = _waves[index]
		wave["age"] = float(wave["age"]) + delta
		var field = wave.get("field")
		if is_instance_valid(field):
			field.update_wave(str(wave["edge"]), float(wave["axis"]), float(wave["age"]), int(wave["count"]), _field_config)
		if float(wave["age"]) >= _duration_seconds:
			if is_instance_valid(field):
				field.queue_free()
			_waves.remove_at(index)


func _create_wave(edge: String, axis: float, count: int) -> void:
	var field = AftereffectWaveFieldScript.new()
	field.z_index = 0
	add_child(field)
	field.update_wave(edge, axis, 0.0, count, _field_config)
	# Intentionally anonymous: only edge, shared axis and group size survive.
	_waves.append({"edge": edge, "axis": axis, "count": count, "age": 0.0, "field": field})
