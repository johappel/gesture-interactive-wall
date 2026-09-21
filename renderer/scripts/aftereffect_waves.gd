# Quiet, short-lived facade memory for plausible anonymous departures.
# The node receives no body IDs: it only keeps a pending edge position, then
# combines nearby exits into a shared, broad inward-moving light front.
class_name AftereffectWaves
extends Node2D

const VALID_EDGES := ["left", "right", "top", "bottom"]
const GOLD := Color(1.0, 0.78, 0.38)

var _pending: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _group_window_seconds := 0.22
var _group_distance := 0.18
var _base_width := 0.22
var _group_width_per_departure := 0.10
var _max_width := 0.65
var _fronts := 3
var _front_interval_seconds := 0.30
var _duration_seconds := 3.4
var _inward_distance := 0.32
var _line_width := 9.0
var _max_alpha := 0.22


func configure(config: Dictionary) -> void:
	_group_window_seconds = max(_number(config, "group_window_seconds", 0.22), 0.0)
	_group_distance = clamp(_number(config, "group_distance", 0.18), 0.0, 1.0)
	_base_width = clamp(_number(config, "base_width", 0.22), 0.02, 1.0)
	_group_width_per_departure = max(_number(config, "group_width_per_departure", 0.10), 0.0)
	_max_width = clamp(_number(config, "max_width", 0.65), _base_width, 1.0)
	_fronts = clampi(int(_number(config, "fronts", 3.0)), 1, 5)
	_front_interval_seconds = max(_number(config, "front_interval_seconds", 0.30), 0.0)
	_duration_seconds = max(_number(config, "duration_seconds", 3.4), 0.1)
	_inward_distance = clamp(_number(config, "inward_distance", 0.32), 0.02, 1.0)
	_line_width = max(_number(config, "line_width", 9.0), 1.0)
	_max_alpha = clamp(_number(config, "max_alpha", 0.22), 0.01, 0.5)


func _number(config: Dictionary, key: String, default_value: float) -> float:
	var value = config.get(key, default_value)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var number := float(value)
		if not is_nan(number) and not is_inf(number):
			return number
	return default_value


func queue_departure(edge: String, x: float, y: float) -> void:
	if not (edge in VALID_EDGES):
		return
	var axis := y if edge == "left" or edge == "right" else x
	for pending in _pending:
		if pending["edge"] == edge and abs(float(pending["axis"]) - axis) <= _group_distance:
			var count: int = int(pending["count"])
			pending["axis"] = (float(pending["axis"]) * count + axis) / float(count + 1)
			pending["count"] = count + 1
			return
	_pending.append({"edge": edge, "axis": axis, "count": 1, "age": 0.0})


func clear() -> void:
	_pending.clear()
	_waves.clear()
	queue_redraw()


func _process(delta: float) -> void:
	for index in range(_pending.size() - 1, -1, -1):
		var pending: Dictionary = _pending[index]
		pending["age"] = float(pending["age"]) + delta
		if float(pending["age"]) >= _group_window_seconds:
			_waves.append({"edge": pending["edge"], "axis": pending["axis"], "count": pending["count"], "age": 0.0})
			_pending.remove_at(index)

	var total_duration: float = _duration_seconds + float(_fronts - 1) * _front_interval_seconds
	for index in range(_waves.size() - 1, -1, -1):
		var wave: Dictionary = _waves[index]
		wave["age"] = float(wave["age"]) + delta
		if float(wave["age"]) >= total_duration:
			_waves.remove_at(index)
	queue_redraw()


func _draw() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return
	for wave in _waves:
		var count: int = int(wave["count"])
		var width_norm: float = minf(_base_width + float(count - 1) * _group_width_per_departure, _max_width)
		for front_index in range(_fronts):
			var age: float = float(wave["age"]) - float(front_index) * _front_interval_seconds
			if age < 0.0 or age > _duration_seconds:
				continue
			var progress: float = clampf(age / _duration_seconds, 0.0, 1.0)
			var alpha: float = _max_alpha * (1.0 - progress) * (1.0 - float(front_index) * 0.16)
			_draw_front(str(wave["edge"]), float(wave["axis"]), width_norm, progress, Color(GOLD.r * 1.35, GOLD.g * 1.25, GOLD.b, alpha), viewport)


func _draw_front(edge: String, axis: float, width_norm: float, progress: float, color: Color, viewport: Vector2) -> void:
	var points := PackedVector2Array()
	var segments: int = 12
	var normal_span: float = minf(viewport.x, viewport.y) * _inward_distance * progress
	var parallel_size: float = viewport.y if edge == "left" or edge == "right" else viewport.x
	var centre: float = axis * parallel_size
	var half_span: float = maxf(parallel_size * width_norm * 0.5, _line_width)
	for index in range(segments + 1):
		var ratio: float = float(index) / float(segments)
		var parallel: float = centre + lerpf(-half_span, half_span, ratio)
		var curve: float = sin(ratio * PI) * minf(22.0, normal_span * 0.22)
		match edge:
			"left": points.append(Vector2(normal_span + curve, parallel))
			"right": points.append(Vector2(viewport.x - normal_span - curve, parallel))
			"top": points.append(Vector2(parallel, normal_span + curve))
			"bottom": points.append(Vector2(parallel, viewport.y - normal_span - curve))
	draw_polyline(points, color, _line_width, true)
