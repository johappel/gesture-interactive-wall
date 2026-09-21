# Full-viewport shader surface for one anonymous aftereffect wave.
class_name AftereffectWaveField
extends Node2D

const WaveShader := preload("res://shaders/aftereffect_wave.gdshader")

var _shader_material := ShaderMaterial.new()


func _init() -> void:
	_shader_material.shader = WaveShader
	material = _shader_material


func update_wave(
	edge: String,
	axis: float,
	age: float,
	count: int,
	config: Dictionary,
) -> void:
	var duration: float = max(float(config["duration_seconds"]), 0.1)
	var progress: float = clampf(age / duration, 0.0, 1.0)
	var initial_outset: float = float(config["initial_origin_outset"])
	var escape_distance: float = float(config["origin_escape_distance"]) * progress
	var origin := _origin_for_edge(edge, axis, initial_outset + escape_distance)
	var group_scale: float = 1.0 + float(count - 1) * float(config["group_width_per_departure"])
	var size := get_viewport_rect().size

	_shader_material.set_shader_parameter("origin_uv", origin)
	_shader_material.set_shader_parameter("radius", float(config["start_radius"]) + float(config["propagation_speed"]) * age)
	_shader_material.set_shader_parameter("band_width", float(config["band_width"]) * group_scale)
	_shader_material.set_shader_parameter("source_glow_radius", float(config["source_glow_radius"]) * group_scale)
	_shader_material.set_shader_parameter("echo_spacing", float(config["echo_spacing"]))
	_shader_material.set_shader_parameter("echo_strength", float(config["echo_strength"]))
	_shader_material.set_shader_parameter("aspect_ratio", size.x / max(size.y, 1.0))
	_shader_material.set_shader_parameter("intensity", float(config["max_alpha"]))
	_shader_material.set_shader_parameter("progress", progress)
	_shader_material.set_shader_parameter("fade_start_progress", float(config["fade_start_progress"]))
	_shader_material.set_shader_parameter("fade_end_progress", float(config["fade_end_progress"]))
	_shader_material.set_shader_parameter("glow_strength", float(config["glow_strength"]))
	_shader_material.set_shader_parameter("warm_color", Color.from_string(str(config["warm_color"]), Color(1.0, 0.94, 0.74)))
	_shader_material.set_shader_parameter("blue_color", Color.from_string(str(config["blue_color"]), Color(0.36, 0.68, 1.0)))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color.WHITE)


func _origin_for_edge(edge: String, axis: float, outset: float) -> Vector2:
	match edge:
		"left": return Vector2(-outset, axis)
		"right": return Vector2(1.0 + outset, axis)
		"top": return Vector2(axis, -outset)
		"bottom": return Vector2(axis, 1.0 + outset)
	return Vector2(0.5, 0.5)
