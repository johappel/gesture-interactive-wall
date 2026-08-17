# WIRKLICHT renderer root.
# Receives local UDP frames and interprets resonance signals as independently
# configurable visual effects (see config/config.json and docs/plan.md).
extends Node2D

const DEFAULT_PORT := 4242
const FADE_AFTER := 0.4  # seconds without packets before bodies fade
const BodyLightScript := preload("res://scripts/body_light.gd")

var _udp := PacketPeerUDP.new()
var _bodies := {}          # id -> BodyLight
var _positions := {}       # id -> Vector2 (screen space)
var _pairs: Array = []
var _time_since_packet := 0.0
var _effects: Dictionary = {}
var _station: Dictionary = {}
var _prompts: Dictionary = {}
var _port := DEFAULT_PORT
var _monitor_window: Window
var _monitor_prompt: Label

func _ready() -> void:
	_load_config()
	_setup_background()
	_setup_glow()
	_setup_station_monitor()
	var err := _udp.bind(_port, "127.0.0.1")
	if err != OK:
		push_error("UDP-Bind auf Port %d fehlgeschlagen: %s" % [_port, err])
	else:
		print("WIRKLICHT lauscht auf udp://127.0.0.1:%d" % _port)
	_print_effect_state()
	_print_station_state()

func _process(delta: float) -> void:
	var latest := ""
	while _udp.get_available_packet_count() > 0:
		latest = _udp.get_packet().get_string_from_utf8()

	if latest != "":
		_time_since_packet = 0.0
		var json := JSON.new()
		if json.parse(latest) == OK:
			_apply(json.get_data(), delta)
	else:
		_time_since_packet += delta
		if _time_since_packet > FADE_AFTER:
			_fade_all(delta)

	_update_monitor_prompt()
	queue_redraw()

func _apply(data: Dictionary, delta: float) -> void:
	var vp := get_viewport_rect().size
	var seen := {}
	_positions.clear()

	for b in data.get("bodies", []):
		var id := int(b["id"])
		seen[id] = true
		var pos := Vector2(float(b["x"]) * vp.x, float(b["y"]) * vp.y)
		_positions[id] = pos

		var node
		if _bodies.has(id):
			node = _bodies[id]
		else:
			node = BodyLightScript.new()
			node.configure_effects(_effects)
			add_child(node)
			_bodies[id] = node
		node.modulate.a = 1.0
		node.update_state(pos, float(b.get("intensity", 0.0)), float(b.get("openness", 0.0)))

	for id in _bodies.keys():
		if not seen.has(id):
			if _bodies[id].fade(delta):
				_bodies[id].queue_free()
				_bodies.erase(id)

	_pairs = data.get("pairs", []) if _effect_enabled("proximity_bridges", true) else []

func _fade_all(delta: float) -> void:
	for id in _bodies.keys():
		if _bodies[id].fade(delta):
			_bodies[id].queue_free()
			_bodies.erase(id)
	_pairs = []
	_positions.clear()

func _draw() -> void:
	if not _effect_enabled("proximity_bridges", true):
		return
	for p in _pairs:
		var a := int(p["a"])
		var b := int(p["b"])
		if _positions.has(a) and _positions.has(b):
			var prox := float(p.get("proximity", 0.0))
			var br := 1.0 + prox * 2.5
			var col := Color(0.55 * br, 0.8 * br, 1.0 * br, 0.9)
			draw_line(_positions[a], _positions[b], col, 3.0 + prox * 12.0, true)

func _load_config() -> void:
	var config_path := ProjectSettings.globalize_path("res://../config/config.json")
	if not FileAccess.file_exists(config_path):
		push_warning("WIRKLICHT config nicht gefunden: %s; Renderer nutzt Defaults." % config_path)
		_effects = _default_effects()
		_station = _default_station()
		return

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_warning("WIRKLICHT config konnte nicht geöffnet werden; Renderer nutzt Defaults.")
		_effects = _default_effects()
		_station = _default_station()
		return

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK or not (json.get_data() is Dictionary):
		push_warning("WIRKLICHT config ist ungültig; Renderer nutzt Defaults.")
		_effects = _default_effects()
		_station = _default_station()
		return

	var config: Dictionary = json.get_data()
	var network = config.get("network", {})
	if network is Dictionary:
		_port = int(network.get("port", DEFAULT_PORT))

	var configured_effects = config.get("effects", {})
	_effects = configured_effects.duplicate(true) if configured_effects is Dictionary else _default_effects()
	_effects = _resolve_effect_modes(_effects)

	var configured_station = config.get("station", {})
	_station = configured_station.duplicate(true) if configured_station is Dictionary else _default_station()
	_load_prompts()

func _load_prompts() -> void:
	_prompts = {}
	var prompt_cfg = _station.get("prompt", {})
	if not (prompt_cfg is Dictionary):
		return
	var source := str(prompt_cfg.get("source", "config/prompts.json"))
	if source == "" or source.is_absolute_path() or source.contains(".."):
		push_warning("Ungültiger Prompt-Pfad; verwende keine Sprachimpulse: %s" % source)
		return
	var prompts_path := ProjectSettings.globalize_path("res://../" + source)
	if not FileAccess.file_exists(prompts_path):
		push_warning("Prompt-Datei nicht gefunden: %s" % prompts_path)
		return
	var file := FileAccess.open(prompts_path, FileAccess.READ)
	if file == null:
		push_warning("Prompt-Datei konnte nicht geöffnet werden: %s" % prompts_path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.get_data() is Dictionary):
		push_warning("Prompt-Datei ist ungültig: %s" % prompts_path)
		return
	var data: Dictionary = json.get_data()
	var entries = data.get("prompts", {})
	if entries is Dictionary:
		_prompts = entries.duplicate(true)

func _setup_station_monitor() -> void:
	var monitor_cfg = _station.get("monitor", {})
	if not (monitor_cfg is Dictionary) or not bool(monitor_cfg.get("enabled", false)):
		return
	if str(monitor_cfg.get("mode", "facade_preview")) != "facade_preview":
		push_warning("Unbekannter Monitor-Modus; Monitor bleibt aus.")
		return
	if bool(monitor_cfg.get("show_camera_image", false)):
		push_warning("show_camera_image=true wird im Publikumsrenderer ignoriert; Kamerabild bleibt verborgen.")

	_monitor_window = Window.new()
	_monitor_window.title = str(monitor_cfg.get("title", "WIRKLICHT – Resonanz"))
	_monitor_window.size = Vector2i(int(monitor_cfg.get("width", 960)), int(monitor_cfg.get("height", 540)))
	_monitor_window.unresizable = false
	add_child(_monitor_window)

	var preview := TextureRect.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = get_viewport().get_texture()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monitor_window.add_child(preview)

	_monitor_prompt = Label.new()
	_monitor_prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_monitor_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monitor_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_monitor_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_monitor_prompt.add_theme_font_size_override("font_size", int(monitor_cfg.get("prompt_font_size", 38)))
	_monitor_prompt.add_theme_constant_override("outline_size", 8)
	_monitor_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monitor_window.add_child(_monitor_prompt)
	_update_monitor_prompt()

func _update_monitor_prompt() -> void:
	if _monitor_prompt == null:
		return
	var prompt_cfg = _station.get("prompt", {})
	if not (prompt_cfg is Dictionary) or not bool(prompt_cfg.get("enabled", false)):
		_monitor_prompt.visible = false
		return
	var key := str(prompt_cfg.get("prompt_key", "stay_question"))
	var text := str(_prompts.get(key, ""))
	if text == "":
		_monitor_prompt.visible = false
		return
	_monitor_prompt.text = text
	# The invitation belongs to the idle threshold. As soon as resonance is
	# present, the preview itself takes over instead of competing with the text.
	_monitor_prompt.visible = _bodies.is_empty()

func _resolve_effect_modes(effects: Dictionary) -> Dictionary:
	var resolved := effects.duplicate(true)
	if not bool(resolved.get("enabled", true)):
		for name in _effect_names():
			_set_effect_enabled(resolved, name, false)
		return resolved

	if bool(resolved.get("minimal_mode", false)):
		# Stable fallback for live operation: only presence, traces and proximity.
		for name in _effect_names():
			_set_effect_enabled(resolved, name, name in ["body_glow", "trails", "proximity_bridges"])
	return resolved

func _set_effect_enabled(effects: Dictionary, name: String, enabled: bool) -> void:
	var block = effects.get(name, {})
	if not (block is Dictionary):
		block = {}
	block["enabled"] = enabled
	effects[name] = block

func _effect_names() -> Array[String]:
	return [
		"body_glow",
		"trails",
		"sparks",
		"proximity_bridges",
		"mist",
		"waves",
		"floating_bodies",
		"aftereffect_waves",
		"crowd_field",
	]

func _effect_enabled(name: String, default_value: bool) -> bool:
	var block = _effects.get(name, {})
	if block is Dictionary:
		return bool(block.get("enabled", default_value))
	return default_value

func _default_effects() -> Dictionary:
	return {
		"enabled": true,
		"minimal_mode": false,
		"body_glow": {"enabled": true},
		"trails": {"enabled": true},
		"sparks": {"enabled": true},
		"proximity_bridges": {"enabled": true},
	}

func _default_station() -> Dictionary:
	return {
		"monitor": {
			"enabled": false,
			"mode": "facade_preview",
			"show_camera_image": false,
		},
		"prompt": {
			"enabled": false,
			"source": "config/prompts.json",
			"prompt_key": "stay_question",
		},
	}

func _print_effect_state() -> void:
	var states: Array[String] = []
	for name in _effect_names():
		states.append("%s=%s" % [name, "on" if _effect_enabled(name, false) else "off"])
	print("WIRKLICHT Effekte: " + ", ".join(states))

func _print_station_state() -> void:
	var monitor_cfg = _station.get("monitor", {})
	var prompt_cfg = _station.get("prompt", {})
	var monitor_on := monitor_cfg is Dictionary and bool(monitor_cfg.get("enabled", false))
	var prompt_on := prompt_cfg is Dictionary and bool(prompt_cfg.get("enabled", false))
	print("WIRKLICHT Stand: monitor=%s, prompt=%s" % ["on" if monitor_on else "off", "on" if prompt_on else "off"])

func _setup_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03)
	bg.z_index = -100
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _setup_glow() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	for i in range(7):
		env.set_glow_level(i, 0.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 1.0)
	env.set_glow_level(5, 0.6)
	env.glow_intensity = 1.4
	env.glow_bloom = 0.35
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.7
	we.environment = env
	add_child(we)
