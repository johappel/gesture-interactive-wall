# WIRKLICHT renderer root.
# Receives local UDP frames and interprets resonance signals as independently
# configurable visual effects (see config/config.json and docs/plan.md).
extends Node2D

const DEFAULT_PORT := 4242
const FADE_AFTER := 0.4  # seconds without packets before bodies fade
const BodyLightScript := preload("res://scripts/body_light.gd")
const AftereffectWavesScript := preload("res://scripts/aftereffect_waves.gd")
const CrowdAuraScript := preload("res://scripts/crowd_aura.gd")
const ProximityBridgesScript := preload("res://scripts/proximity_bridges.gd")
const PromptCueScript := preload("res://scripts/prompt_cue.gd")
const DebugOverlayScript := preload("res://scripts/debug_overlay.gd")
const CONFIG_POLL_INTERVAL := 0.5  # seconds between config.json change checks

var _udp := PacketPeerUDP.new()
var _bodies := {}          # id -> BodyLight
var _positions := {}       # id -> Vector2 (screen space)
var _pairs: Array = []
var _time_since_packet := 0.0
var _effects: Dictionary = {}
var _station: Dictionary = {}
var _prompts: Dictionary = {}
var _prompt_keys: Array[String] = []
var _prompt_index := -1
var _current_prompt_text := ""
var _port := DEFAULT_PORT
var _facade_screen := 0
var _monitor_window: Window
var _monitor_prompt: Control
var _monitor_prompt_label: Label
var _monitor_prompt_cue
var _monitor_prompt_tween: Tween
var _monitor_cue_tween: Tween
var _prompt_target_visible := false
var _prompt_idle_elapsed := 0.0
var _prompt_rotation_pending := false
var _monitor_closed := false
var _aftereffect_waves
var _crowd_aura
var _proximity_bridges
var _last_frame_time := -INF
var _seen_departure_ids := {}
var _effects_raw: Dictionary = {}
var _config_path := ""
var _config_mtime := 0
var _config_poll_elapsed := 0.0
var _debug_overlay

func _ready() -> void:
	_load_config()
	_setup_facade_output()
	_setup_background()
	_setup_glow()
	_refresh_crowd_aura()
	_refresh_proximity_bridges()
	_refresh_aftereffect_waves()
	_setup_station_monitor()
	_setup_debug_overlay()
	var err := _udp.bind(_port, "127.0.0.1")
	if err != OK:
		push_error("UDP-Bind auf Port %d fehlgeschlagen: %s" % [_port, err])
	else:
		print("WIRKLICHT lauscht auf udp://127.0.0.1:%d" % _port)
	_print_effect_state()
	_print_station_state()

func _process(delta: float) -> void:
	var frames: Array[Dictionary] = []
	while _udp.get_available_packet_count() > 0:
		var packet := _udp.get_packet().get_string_from_utf8()
		var json := JSON.new()
		if json.parse(packet) == OK and json.get_data() is Dictionary:
			var frame: Dictionary = json.get_data()
			frames.append(frame)

	if not frames.is_empty():
		_time_since_packet = 0.0
		# Bodies use only the newest state, but every queued frame is inspected.
		# A departure is intentionally one-shot, so silently discarding an older
		# UDP frame here could otherwise erase the only visible aftereffect.
		for index in range(frames.size()):
			_apply(frames[index], delta if index == frames.size() - 1 else 0.0)
	else:
		_time_since_packet += delta
		if _time_since_packet > FADE_AFTER:
			_fade_all(delta)

	_update_monitor_prompt(delta)

	_config_poll_elapsed += delta
	if _config_poll_elapsed >= CONFIG_POLL_INTERVAL:
		_config_poll_elapsed = 0.0
		_poll_config_reload()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.alt_pressed and event.keycode == KEY_ENTER:
		_toggle_facade_fullscreen()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		if _debug_overlay != null:
			_debug_overlay.toggle()
			get_viewport().set_input_as_handled()
	queue_redraw()

func _apply(data: Dictionary, delta: float) -> void:
	var frame_time = data.get("t", null)
	if _is_finite_number(frame_time):
		if float(frame_time) < _last_frame_time:
			# A large backward jump means capture restarted its clock (a fresh
			# simulator process). Accept the new timeline instead of freezing
			# forever; small backward steps stay reordered-duplicate rejects.
			if _last_frame_time - float(frame_time) > 1.0:
				_last_frame_time = float(frame_time)
				_seen_departure_ids.clear()
			else:
				return
		else:
			_last_frame_time = float(frame_time)
		_consume_departures(data, _last_frame_time)
	var vp := get_viewport_rect().size
	var seen := {}
	var temporarily_missing := {}
	var normalized_positions: Array = []
	_positions.clear()
	var tracking = data.get("tracking", {})
	if tracking is Dictionary:
		var missing_ids = tracking.get("temporarily_missing", [])
		if missing_ids is Array:
			for missing_id in missing_ids:
				if typeof(missing_id) == TYPE_INT or typeof(missing_id) == TYPE_FLOAT:
					temporarily_missing[int(missing_id)] = true

	var raw_bodies = data.get("bodies", [])
	if not raw_bodies is Array:
		raw_bodies = []
	for b in raw_bodies:
		if not (b is Dictionary) or not b.has("id") or not _is_finite_number(b.get("x")) or not _is_finite_number(b.get("y")):
			continue
		var id := int(b["id"])
		seen[id] = true
		var pos := Vector2(float(b["x"]) * vp.x, float(b["y"]) * vp.y)
		_positions[id] = pos
		normalized_positions.append(Vector2(float(b["x"]), float(b["y"])))

		var node
		if _bodies.has(id):
			node = _bodies[id]
		else:
			node = BodyLightScript.new()
			node.configure_effects(_effects)
			add_child(node)
			_bodies[id] = node
		node.modulate.a = 1.0
		node.update_state(
			pos,
			float(b.get("intensity", 0.0)),
			float(b.get("openness", 0.0)),
			float(b.get("presence_time", 0.0)),
			float(b.get("stillness", 0.0)),
		)

	for id in _bodies.keys():
		if not seen.has(id):
			# Preserve an already-rendered light only inside Capture's bounded
			# grace period, so a brief pose loss is not visibly interpreted as
			# immediate departure.
			if temporarily_missing.has(id):
				continue
			if _bodies[id].fade(delta):
				_bodies[id].queue_free()
				_bodies.erase(id)

	var raw_pairs = data.get("pairs", [])
	_pairs = raw_pairs if raw_pairs is Array and _effect_enabled("proximity_bridges", true) else []
	if _proximity_bridges != null:
		_proximity_bridges.update_pairs(_pairs, vp, delta)

	_update_crowd_aura(data, normalized_positions, delta)

func _update_crowd_aura(data: Dictionary, normalized_positions: Array, delta: float) -> void:
	if _crowd_aura == null:
		return
	var crowd = data.get("crowd", {})
	var count := normalized_positions.size()
	var energy := 0.0
	if crowd is Dictionary:
		if _is_finite_number(crowd.get("count")):
			count = max(int(crowd["count"]), 0)
		if _is_finite_number(crowd.get("energy")):
			energy = float(crowd["energy"])
	_crowd_aura.update_crowd(normalized_positions, count, energy, delta)
	_apply_collective_weight()

func _apply_collective_weight() -> void:
	if _crowd_aura == null:
		return
	var weight: float = _crowd_aura.individual_weight()
	for id in _bodies.keys():
		_bodies[id].set_individual_weight(weight)

# Effect nodes are created on demand and torn down when disabled, so an
# enabled=false really means "not created and not simulated". The same refresh
# path is used at startup and on every live config reload.
func _refresh_aftereffect_waves() -> void:
	if _effect_enabled("aftereffect_waves", false):
		if _aftereffect_waves == null:
			_aftereffect_waves = AftereffectWavesScript.new()
			_aftereffect_waves.z_index = -1
			add_child(_aftereffect_waves)
		_aftereffect_waves.configure(_effect_block("aftereffect_waves"))
	elif _aftereffect_waves != null:
		_aftereffect_waves.queue_free()
		_aftereffect_waves = null
		_seen_departure_ids.clear()

func _refresh_crowd_aura() -> void:
	if _effect_enabled("crowd_aura", false):
		if _crowd_aura == null:
			_crowd_aura = CrowdAuraScript.new()
			add_child(_crowd_aura)
		_crowd_aura.configure(_effect_block("crowd_aura"))
	elif _crowd_aura != null:
		_crowd_aura.queue_free()
		_crowd_aura = null
		# Without the shared field, individuals return to full weight instead of
		# staying stuck at their last dimmed value.
		for id in _bodies.keys():
			_bodies[id].set_individual_weight(1.0)

func _refresh_proximity_bridges() -> void:
	if _effect_enabled("proximity_bridges", true):
		if _proximity_bridges == null:
			_proximity_bridges = ProximityBridgesScript.new()
			add_child(_proximity_bridges)
		_proximity_bridges.configure(_effect_block("proximity_bridges"))
	elif _proximity_bridges != null:
		_proximity_bridges.queue_free()
		_proximity_bridges = null

func _setup_debug_overlay() -> void:
	_debug_overlay = DebugOverlayScript.new()
	_debug_overlay.bind_main(self)
	add_child(_debug_overlay)

# --- Live config reload -----------------------------------------------------

# Debug-only channel to the simulator process. The renderer never sends
# production data; this only asks the simulator to switch its synthetic
# scenario. The simulator listens on the production port + 1.
func _sim_control_packet(scenario: String) -> PackedByteArray:
	var payload := {"type": "sim_control", "scenario": scenario}
	return JSON.stringify(payload).to_utf8_buffer()

func request_sim_scenario(scenario: String) -> void:
	var target_port := _port + 1
	var peer := PacketPeerUDP.new()
	var err := peer.set_dest_address("127.0.0.1", target_port)
	if err == OK:
		err = peer.put_packet(_sim_control_packet(scenario))
	if err != OK:
		push_warning("Simulations-Steuerbefehl konnte nicht gesendet werden (Port %d)." % target_port)
	else:
		print("WIRKLICHT Debug: Simulations-Szenario angefordert: %s" % scenario)

func _poll_config_reload() -> void:
	if _config_path == "" or not FileAccess.file_exists(_config_path):
		return
	var mtime := FileAccess.get_modified_time(_config_path)
	if mtime == _config_mtime:
		return
	_config_mtime = mtime
	_reload_from_config()

func _reload_from_config() -> void:
	var file := FileAccess.open(_config_path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.get_data() is Dictionary):
		push_warning("WIRKLICHT Live-Reload: Config ungültig; behalte aktuelle Werte.")
		return
	var config: Dictionary = json.get_data()
	var configured_effects = config.get("effects", {})
	var new_effects: Dictionary = configured_effects.duplicate(true) if configured_effects is Dictionary else _default_effects()
	_apply_live_effects(new_effects)
	if _debug_overlay != null:
		_debug_overlay.sync_from_config()
	print("WIRKLICHT Live-Reload übernommen.")

# Re-applies a raw effects block to the running scene: nodes are created or
# freed on enabled transitions, existing nodes are reconfigured and every body
# light receives the fresh parameters.
func _apply_live_effects(raw_effects: Dictionary) -> void:
	_effects_raw = raw_effects.duplicate(true)
	_effects = _resolve_effect_modes(_effects_raw.duplicate(true))
	_refresh_crowd_aura()
	_refresh_proximity_bridges()
	_refresh_aftereffect_waves()
	for id in _bodies.keys():
		_bodies[id].configure_effects(_effects)
	_print_effect_state()

# Called by the debug overlay: the raw (pre-mode-resolution) effects block.
func live_effects_raw() -> Dictionary:
	return _effects_raw.duplicate(true)

# Called by the debug overlay on every slider change: apply in memory only.
func set_live_effects(new_effects: Dictionary) -> void:
	_apply_live_effects(new_effects)

# Called by the debug overlay's "Speichern": persist the current raw effects
# block back into config.json without disturbing the other sections. Written
# atomically (temp + rename) and with LF newlines to match the repo.
#
# Only the effects VALUE is spliced in by brace depth. The file must not be
# round-tripped through Godot's JSON parser: that would demote every integer in
# camera/pose/features/station to a float and rewrite the whole file.
func save_live_effects_to_config() -> bool:
	if _config_path == "" or not FileAccess.file_exists(_config_path):
		return false
	var reader := FileAccess.open(_config_path, FileAccess.READ)
	if reader == null:
		return false
	var text := reader.get_as_text()
	var bounds := _effects_span(text)
	if bounds.x < 0:
		push_warning("WIRKLICHT: 'effects'-Block in config.json nicht gefunden; Speichern übersprungen.")
		return false
	var start: int = bounds.x
	var end: int = bounds.y
	# Keep the effects key's own indentation for the spliced block.
	var line_start := text.rfind("\n", start) + 1
	var indent := ""
	for index in range(line_start, start):
		var character := text[index]
		if character == " " or character == "\t":
			indent += character
		else:
			break
	var block := JSON.stringify(_effects_raw, "    ", false)
	var block_lines := block.split("\n")
	var rebuilt := ""
	for index in range(block_lines.size()):
		if index > 0:
			rebuilt += "\n" + indent
		rebuilt += block_lines[index]
	var new_text := text.substr(0, start) + rebuilt + text.substr(end + 1)
	var tmp_path := _config_path + ".tmp"
	var writer := FileAccess.open(tmp_path, FileAccess.WRITE)
	if writer == null:
		push_warning("WIRKLICHT: Config konnte nicht geschrieben werden: %s" % tmp_path)
		return false
	writer.store_string(new_text)
	writer.close()
	var err := DirAccess.rename_absolute(tmp_path, _config_path)
	if err != OK:
		push_warning("WIRKLICHT: Config-Rename fehlgeschlagen (%s)." % err)
		return false
	# Skip the poller's self-trigger for this write.
	_config_mtime = FileAccess.get_modified_time(_config_path)
	print("WIRKLICHT: Effekte in config.json gespeichert.")
	return true

# Locates the "effects" value object and returns (open_brace, close_brace) or
# (-1, -1). Brace matching is string-aware so braces inside string values (for
# instance a device path) cannot end the block early.
func _effects_span(text: String) -> Vector2i:
	var key_at := text.find("\"effects\"")
	if key_at < 0:
		return Vector2i(-1, -1)
	var open := text.find("{", key_at)
	if open < 0:
		return Vector2i(-1, -1)
	var depth := 0
	var in_string := false
	var escaped := false
	for index in range(open, text.length()):
		var character := text[index]
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == "\"":
				in_string = false
			continue
		if character == "\"":
			in_string = true
		elif character == "{":
			depth += 1
		elif character == "}":
			depth -= 1
			if depth == 0:
				return Vector2i(open, index)
	return Vector2i(-1, -1)

func _consume_departures(data: Dictionary, frame_time: float) -> void:
	if _aftereffect_waves == null:
		return
	_prune_seen_departure_ids(frame_time)
	var events = data.get("events", {})
	if not events is Dictionary:
		return
	var departures = events.get("departures", [])
	if not departures is Array:
		return
	for departure in departures:
		if not _valid_departure(departure):
			continue
		var departure_id: int = int(departure["id"])
		if _seen_departure_ids.has(departure_id):
			continue
		# IDs are only transient UDP duplicate guards. The wave receives no ID.
		_seen_departure_ids[departure_id] = frame_time + _aftereffect_dedupe_seconds()
		_aftereffect_waves.queue_departure(str(departure["edge"]), float(departure["x"]), float(departure["y"]))

func _valid_departure(departure) -> bool:
	if not departure is Dictionary:
		return false
	var raw_id = departure.get("id")
	# Godot's JSON parser may expose an integral JSON id as TYPE_FLOAT.
	# Accept only finite, non-negative whole numbers; never coerce 1.5 to 1.
	if not _is_finite_number(raw_id) or float(raw_id) < 0.0 or float(int(raw_id)) != float(raw_id):
		return false
	if not departure.has("edge") or not (str(departure["edge"]) in ["left", "right", "top", "bottom"]):
		return false
	for name in ["x", "y", "vx", "vy"]:
		if not _is_finite_number(departure.get(name)):
			return false
	return float(departure["x"]) >= 0.0 and float(departure["x"]) <= 1.0 and float(departure["y"]) >= 0.0 and float(departure["y"]) <= 1.0

func _is_finite_number(value) -> bool:
	if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT):
		return false
	return not is_nan(float(value)) and not is_inf(float(value))

func _prune_seen_departure_ids(frame_time: float) -> void:
	for departure_id in _seen_departure_ids.keys():
		if float(_seen_departure_ids[departure_id]) < frame_time:
			_seen_departure_ids.erase(departure_id)

func _aftereffect_dedupe_seconds() -> float:
	return max(float(_effect_block("aftereffect_waves").get("dedupe_seconds", 5.0)), 0.1)

func _fade_all(delta: float) -> void:
	for id in _bodies.keys():
		if _bodies[id].fade(delta):
			_bodies[id].queue_free()
			_bodies.erase(id)
	_pairs = []
	_positions.clear()
	# No packets means no observed crowd: the shared field fades out on its own
	# time constant instead of being switched off.
	if _crowd_aura != null:
		_crowd_aura.update_crowd([], 0, 0.0, delta)
	if _proximity_bridges != null:
		_proximity_bridges.update_pairs([], get_viewport_rect().size, delta)

func _load_config() -> void:
	var config_path := ProjectSettings.globalize_path("res://../config/config.json")
	_config_path = config_path
	if not FileAccess.file_exists(config_path):
		push_warning("WIRKLICHT config nicht gefunden: %s; Renderer nutzt Defaults." % config_path)
		_effects_raw = _default_effects()
		_effects = _default_effects()
		_station = _normalize_station(_default_station())
		return
	_config_mtime = FileAccess.get_modified_time(config_path)

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_warning("WIRKLICHT config konnte nicht geöffnet werden; Renderer nutzt Defaults.")
		_effects_raw = _default_effects()
		_effects = _default_effects()
		_station = _normalize_station(_default_station())
		return

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK or not (json.get_data() is Dictionary):
		push_warning("WIRKLICHT config ist ungültig; Renderer nutzt Defaults.")
		_effects_raw = _default_effects()
		_effects = _default_effects()
		_station = _normalize_station(_default_station())
		return

	var config: Dictionary = json.get_data()
	var network = config.get("network", {})
	if network is Dictionary:
		_port = int(network.get("port", DEFAULT_PORT))

	var configured_effects = config.get("effects", {})
	_effects_raw = configured_effects.duplicate(true) if configured_effects is Dictionary else _default_effects()
	_effects = _resolve_effect_modes(_effects_raw.duplicate(true))

	var configured_station = config.get("station", {})
	_station = _normalize_station(configured_station)
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
	if not entries is Dictionary:
		push_warning("Prompt-Datei enthält kein gültiges 'prompts'-Objekt: %s" % prompts_path)
		return
	for key in entries.keys():
		var value = entries[key]
		if typeof(value) != TYPE_STRING or value.strip_edges() == "":
			push_warning("Prompt-Eintrag '%s' ist kein nichtleerer Text; Eintrag wird ignoriert." % key)
			continue
		_prompts[str(key)] = value
	_resolve_prompt_keys()

func _resolve_prompt_keys() -> void:
	_prompt_keys.clear()
	var prompt_cfg = _station.get("prompt", {})
	if not (prompt_cfg is Dictionary) or not bool(prompt_cfg.get("enabled", false)):
		return
	var configured_keys = prompt_cfg.get("prompt_keys", [])
	if configured_keys is Array:
		for raw_key in configured_keys:
			if typeof(raw_key) != TYPE_STRING or raw_key.strip_edges() == "":
				push_warning("Ungültiger Prompt-Key in station.prompt.prompt_keys; Eintrag wird ignoriert.")
				continue
			var key: String = str(raw_key).strip_edges()
			if not _prompts.has(key):
				push_warning("Unbekannter Prompt-Key '%s'; Eintrag wird ignoriert." % key)
				continue
			if not _prompt_keys.has(key):
				_prompt_keys.append(key)
	if _prompt_keys.is_empty():
		var fallback_key := str(prompt_cfg.get("prompt_key", ""))
		if fallback_key != "" and _prompts.has(fallback_key):
			_prompt_keys.append(fallback_key)
		else:
			push_warning("Kein gültiger Prompt-Key; es wird kein Ersatztext angezeigt.")

func _select_next_prompt() -> bool:
	if _prompt_keys.is_empty():
		return false
	_prompt_index = (_prompt_index + 1) % _prompt_keys.size()
	_current_prompt_text = str(_prompts.get(_prompt_keys[_prompt_index], ""))
	return _current_prompt_text != ""

func _setup_station_monitor() -> void:
	var monitor_cfg = _station.get("monitor", {})
	if not (monitor_cfg is Dictionary) or not bool(monitor_cfg.get("enabled", false)):
		return
	if str(monitor_cfg.get("mode", "facade_preview")) != "facade_preview":
		push_warning("Unbekannter Monitor-Modus; Monitor bleibt aus.")
		return
	var monitor_screen := _resolve_output_screen(monitor_cfg, "station.monitor.screen")
	if DisplayServer.get_screen_count() < 2 or monitor_screen == _facade_screen:
		push_warning("Nahraum-Monitor bleibt aus: keine von der Fassade getrennte Anzeige verfuegbar.")
		return

	_monitor_window = Window.new()
	_monitor_window.title = str(monitor_cfg.get("title", "WIRKLICHT – Resonanz"))
	_monitor_window.size = Vector2i(int(monitor_cfg.get("width", 960)), int(monitor_cfg.get("height", 540)))
	_monitor_window.unresizable = false
	_monitor_window.close_requested.connect(_on_monitor_close_requested)
	add_child(_monitor_window)
	_monitor_window.current_screen = monitor_screen
	_monitor_window.mode = Window.MODE_FULLSCREEN if bool(monitor_cfg.get("fullscreen", true)) else Window.MODE_WINDOWED

	var preview := TextureRect.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = get_viewport().get_texture()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monitor_window.add_child(preview)

	_monitor_prompt = Control.new()
	_monitor_prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_monitor_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monitor_prompt.visible = false
	_monitor_prompt.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_monitor_prompt_cue = PromptCueScript.new()
	_monitor_prompt_cue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_monitor_prompt_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monitor_prompt.add_child(_monitor_prompt_cue)
	var prompt_center := CenterContainer.new()
	prompt_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monitor_prompt.add_child(prompt_center)
	var prompt_box := VBoxContainer.new()
	prompt_box.custom_minimum_size = Vector2(560.0, 0.0)
	prompt_box.add_theme_constant_override("separation", 16)
	prompt_center.add_child(prompt_box)
	_monitor_prompt_label = Label.new()
	_monitor_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monitor_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_monitor_prompt_label.add_theme_font_size_override("font_size", int(monitor_cfg.get("prompt_font_size", 38)))
	_monitor_prompt_label.add_theme_constant_override("outline_size", 8)
	_monitor_prompt_label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.12, 0.82))
	_monitor_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.add_child(_monitor_prompt_label)
	_monitor_window.add_child(_monitor_prompt)
	_update_monitor_prompt(0.0)
	print("WIRKLICHT Nahraum-Monitor: Bildschirm %d, %s" % [monitor_screen, "Vollbild" if _monitor_window.mode == Window.MODE_FULLSCREEN else "Fenster"])

func _setup_facade_output() -> void:
	var facade_cfg = _station.get("facade", {})
	if not (facade_cfg is Dictionary):
		return
	_print_available_screens()
	_facade_screen = _resolve_facade_screen(facade_cfg)
	var facade_window := get_window()
	facade_window.current_screen = _facade_screen
	facade_window.mode = Window.MODE_FULLSCREEN if bool(facade_cfg.get("fullscreen", true)) else Window.MODE_WINDOWED
	print("WIRKLICHT Fassade: Bildschirm %d, %s" % [_facade_screen, "Vollbild" if facade_window.mode == Window.MODE_FULLSCREEN else "Fenster"])

func _resolve_facade_screen(facade_cfg: Dictionary) -> int:
	return _resolve_output_screen(facade_cfg, "station.facade.screen")

func _resolve_output_screen(output_cfg: Dictionary, label: String) -> int:
	var display_signature = output_cfg.get("display", {})
	if display_signature is Dictionary:
		var required_keys := ["x", "y", "width", "height"]
		var has_signature := true
		for key in required_keys:
			if not display_signature.has(key):
				has_signature = false
				break
		if has_signature:
			for screen_index in range(DisplayServer.get_screen_count()):
				var position := DisplayServer.screen_get_position(screen_index)
				var size := DisplayServer.screen_get_size(screen_index)
				if position.x == int(display_signature["x"]) and position.y == int(display_signature["y"]) and size.x == int(display_signature["width"]) and size.y == int(display_signature["height"]):
					print("WIRKLICHT gespeicherte Ausgabe %s: Bildschirm %d" % [label, screen_index])
					return screen_index
			if display_signature.has("relative_x") and display_signature.has("relative_y"):
				var primary_position := DisplayServer.screen_get_position(_primary_screen())
				for screen_index in range(DisplayServer.get_screen_count()):
					var position := DisplayServer.screen_get_position(screen_index)
					var size := DisplayServer.screen_get_size(screen_index)
					if position.x - primary_position.x == int(display_signature["relative_x"]) and position.y - primary_position.y == int(display_signature["relative_y"]) and size.x == int(display_signature["width"]) and size.y == int(display_signature["height"]):
						print("WIRKLICHT gespeicherte Ausgabe %s über relative Position: Bildschirm %d" % [label, screen_index])
						return screen_index
	var requested_screen := int(output_cfg.get("screen", 0))
	if requested_screen >= 0 and requested_screen < DisplayServer.get_screen_count():
		push_warning("Die gespeicherte Bildschirm-Geometrie für %s passt nicht zur Godot-Koordinate; verwende den gespeicherten Bildschirmindex %d." % [label, requested_screen])
		return requested_screen
	return _resolve_screen(requested_screen, label)

func _resolve_legacy_facade_screen(facade_cfg: Dictionary) -> int:
	var display_signature = facade_cfg.get("display", {})
	if display_signature is Dictionary:
		var required_keys := ["x", "y", "width", "height"]
		var has_signature := true
		for key in required_keys:
			if not display_signature.has(key):
				has_signature = false
				break
		if has_signature:
			for screen_index in range(DisplayServer.get_screen_count()):
				var position := DisplayServer.screen_get_position(screen_index)
				var size := DisplayServer.screen_get_size(screen_index)
				if position.x == int(display_signature["x"]) and position.y == int(display_signature["y"]) and size.x == int(display_signature["width"]) and size.y == int(display_signature["height"]):
					print("WIRKLICHT gespeicherte Fassaden-Ausgabe: Bildschirm %d" % screen_index)
					return screen_index
			push_warning("Die gespeicherte Fassaden-Ausgabe ist nicht verfügbar; verwende Hauptbildschirm.")
			return _primary_screen()
	return _resolve_screen(int(facade_cfg.get("screen", 0)), "station.facade.screen")

func _resolve_screen(requested_screen: int, label: String) -> int:
	var screen_count := DisplayServer.get_screen_count()
	if requested_screen >= 0 and requested_screen < screen_count:
		return requested_screen
	push_warning("%s=%d ist nicht verfügbar; verwende Hauptbildschirm von %d." % [label, requested_screen, screen_count])
	return _primary_screen()

func _primary_screen() -> int:
	if DisplayServer.get_screen_count() <= 0:
		return 0
	return DisplayServer.get_primary_screen()

func _print_available_screens() -> void:
	print("Detected screens: %d" % DisplayServer.get_screen_count())
	var primary_screen := _primary_screen()
	for screen_index in range(DisplayServer.get_screen_count()):
		var size := DisplayServer.screen_get_size(screen_index)
		var position := DisplayServer.screen_get_position(screen_index)
		print("Screen %d: position: %d,%d; size: %dx%d; primary: %s" % [screen_index, position.x, position.y, size.x, size.y, "true" if screen_index == primary_screen else "false"])

func _toggle_facade_fullscreen() -> void:
	var facade_window := get_window()
	if facade_window.mode == Window.MODE_FULLSCREEN:
		facade_window.mode = Window.MODE_WINDOWED
		print("WIRKLICHT Fassade: Vollbild beendet (Alt+Enter).")
		return
	facade_window.current_screen = _facade_screen
	facade_window.mode = Window.MODE_FULLSCREEN
	print("WIRKLICHT Fassade: Vollbild auf Bildschirm %d aktiviert (Alt+Enter)." % _facade_screen)

func _update_monitor_prompt(delta: float) -> void:
	if _monitor_prompt == null or _monitor_closed:
		return
	var prompt_cfg = _station.get("prompt", {})
	if not (prompt_cfg is Dictionary) or not bool(prompt_cfg.get("enabled", false)):
		_prompt_rotation_pending = false
		_prompt_idle_elapsed = 0.0
		_set_monitor_prompt_visible(false)
		return
	if _prompt_rotation_pending and _bodies.is_empty() and not _prompt_target_visible:
		return
	# A long quiet phase may offer the next curated invitation. It never swaps
	# text in place: the old sentence fades away before the next star arrives.
	if _bodies.is_empty() and not _prompt_target_visible:
		if not _select_next_prompt():
			_set_monitor_prompt_visible(false)
			return
		_monitor_prompt_label.text = _current_prompt_text
		_prompt_idle_elapsed = 0.0
		_set_monitor_prompt_visible(true)
		return
	if _bodies.is_empty() and _prompt_target_visible:
		_prompt_idle_elapsed += delta
		var cycle_seconds: float = float(prompt_cfg.get("idle_cycle_seconds", 11.0))
		if _prompt_idle_elapsed >= cycle_seconds and not _prompt_rotation_pending:
			_prompt_rotation_pending = true
			_set_monitor_prompt_visible(false)
		return
	if not _bodies.is_empty():
		_prompt_rotation_pending = false
		_prompt_idle_elapsed = 0.0
		_set_monitor_prompt_visible(false)

func _set_monitor_prompt_visible(should_show: bool) -> void:
	if _prompt_target_visible == should_show:
		return
	_prompt_target_visible = should_show
	if _monitor_prompt_tween != null:
		_monitor_prompt_tween.kill()
	if _monitor_cue_tween != null:
		_monitor_cue_tween.kill()
	var prompt_cfg: Dictionary = _station.get("prompt", {})
	var fade_in: float = float(prompt_cfg.get("fade_in_seconds", 2.3))
	var fade_out: float = float(prompt_cfg.get("fade_out_seconds", 1.4))
	var underline_duration: float = float(prompt_cfg.get("underline_seconds", 2.0))
	var tail_fade: float = float(prompt_cfg.get("star_tail_fade_seconds", 3.0))
	_monitor_prompt_tween = create_tween()
	_monitor_prompt_tween.set_trans(Tween.TRANS_SINE)
	if should_show:
		_monitor_prompt.visible = true
		_monitor_prompt_cue.reveal = 0.0
		_monitor_prompt_cue.intensity = 0.0
		_monitor_prompt_cue.trail_alpha = 1.0
		_monitor_prompt_tween.set_parallel(true)
		_monitor_prompt_tween.tween_property(_monitor_prompt, "modulate:a", 1.0, fade_in).set_ease(Tween.EASE_OUT)
		_monitor_prompt_tween.tween_property(_monitor_prompt_cue, "intensity", 1.0, fade_in * 0.8).set_ease(Tween.EASE_OUT)
		_monitor_cue_tween = create_tween()
		_monitor_cue_tween.tween_interval(fade_in * 0.25)
		_monitor_cue_tween.tween_property(_monitor_prompt_cue, "reveal", 1.0, underline_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_monitor_cue_tween.tween_property(_monitor_prompt_cue, "trail_alpha", 0.0, tail_fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		return
	_monitor_prompt_tween.set_parallel(true)
	_monitor_prompt_tween.tween_property(_monitor_prompt, "modulate:a", 0.0, fade_out).set_ease(Tween.EASE_IN)
	_monitor_prompt_tween.tween_property(_monitor_prompt_cue, "intensity", 0.0, fade_out * 0.7).set_ease(Tween.EASE_IN)
	_monitor_prompt_tween.tween_property(_monitor_prompt_cue, "trail_alpha", 0.0, fade_out * 0.7).set_ease(Tween.EASE_IN)
	_monitor_prompt_tween.set_parallel(false)
	_monitor_prompt_tween.tween_callback(_finish_monitor_prompt_hide)

func _finish_monitor_prompt_hide() -> void:
	if _prompt_target_visible or _monitor_prompt == null:
		return
	_monitor_prompt.visible = false
	if _prompt_rotation_pending and _bodies.is_empty():
		_prompt_rotation_pending = false
		_prompt_idle_elapsed = 0.0
		if _select_next_prompt():
			_monitor_prompt_label.text = _current_prompt_text
			_set_monitor_prompt_visible(true)

func _on_monitor_close_requested() -> void:
	if _monitor_window == null:
		return
	_monitor_closed = true
	_monitor_window.hide()
	print("WIRKLICHT Nahraum-Monitor geschlossen; Hauptausgabe läuft weiter.")

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
		"stillness_resonance",
		"crowd_aura",
		"aftereffect_waves",
	]

func _effect_enabled(name: String, default_value: bool) -> bool:
	var block = _effects.get(name, {})
	if block is Dictionary:
		return bool(block.get("enabled", default_value))
	return default_value

func _effect_block(name: String) -> Dictionary:
	var block = _effects.get(name, {})
	return block if block is Dictionary else {}

func _default_effects() -> Dictionary:
	return {
		"enabled": true,
		"minimal_mode": false,
		"body_glow": {"enabled": true},
		"trails": {"enabled": true},
		"sparks": {"enabled": true, "activation_intensity": 0.09},
		"proximity_bridges": {
			"enabled": true,
			"orbs_min": 2,
			"orbs_max": 6,
			"travel": 0.8,
			"speed": 2.2,
			"orb_size": 26.0,
			"wobble": 0.06,
			"max_alpha": 0.85,
			"field_strength": 0.6,
			"fade_seconds": 0.6,
			"warm_color": "#ffcd79",
			"hot_color": "#ff9a3c",
		},
		"stillness_resonance": {
			"enabled": true,
			"min_presence_seconds": 3.0,
			"pulse_seconds": 6.0,
			"max_scale": 1.3,
		},
		"crowd_aura": {
			"enabled": true,
			"min_people": 3,
			"full_strength_people": 10,
			"fade_in_seconds": 2.5,
			"fade_out_seconds": 4.0,
			"pulse_seconds": 9.0,
			"padding": 0.12,
			"softness": 0.18,
			"min_alpha": 0.05,
			"max_alpha": 0.18,
			"energy_influence": 0.30,
			"individual_dimming_max": 0.45,
			"body_clearance": 0.13,
			"gap_emphasis": 0.75,
			"warm_color": "#ffe3a1",
			"cool_color": "#5caeff",
		},
		"aftereffect_waves": {
			"enabled": true,
			"group_window_seconds": 0.22,
			"group_distance": 0.18,
			"group_width_per_departure": 0.10,
			"duration_seconds": 4.8,
			"initial_origin_outset": 0.03,
			"origin_escape_distance": 0.16,
			"start_radius": 0.03,
			"propagation_speed": 0.20,
			"band_width": 0.09,
			"source_glow_radius": 0.16,
			"echo_spacing": 0.15,
			"echo_strength": 0.28,
			"max_alpha": 0.26,
			"fade_start_progress": 0.15,
			"fade_end_progress": 0.92,
			"glow_strength": 1.55,
			"warm_color": "#fff0bd",
			"blue_color": "#5caeff",
			"dedupe_seconds": 5.0,
		},
	}

func _default_station() -> Dictionary:
	return {
		"facade": {
			"screen": 0,
			"fullscreen": true,
		},
		"monitor": {
			"enabled": false,
			"mode": "facade_preview",
			"show_camera_image": false,
			"title": "WIRKLICHT – Resonanz",
			"screen": 1,
			"fullscreen": true,
			"width": 960,
			"height": 540,
			"prompt_font_size": 38,
		},
		"prompt": {
			"enabled": false,
			"source": "config/prompts.json",
			"prompt_key": "stay_question",
			"prompt_keys": [],
			"fade_in_seconds": 2.3,
			"fade_out_seconds": 1.4,
			"underline_seconds": 2.0,
			"star_tail_fade_seconds": 3.0,
			"idle_cycle_seconds": 11.0,
		},
	}

func _normalize_station(configured_station) -> Dictionary:
	var resolved := _default_station()
	if not configured_station is Dictionary:
		if configured_station != null:
			push_warning("station-Konfiguration ist kein Objekt; Renderer nutzt sichere Defaults.")
		return resolved

	for section in ["facade", "monitor", "prompt"]:
		var configured_section = configured_station.get(section, {})
		if configured_section == null:
			continue
		if not configured_section is Dictionary:
			push_warning("station.%s ist kein Objekt; Renderer nutzt sichere Defaults." % section)
			continue
		for key in configured_section.keys():
			resolved[section][key] = configured_section[key]

	var facade: Dictionary = resolved["facade"]
	facade["screen"] = _safe_nonnegative_int(facade.get("screen"), 0, "station.facade.screen")
	facade["fullscreen"] = _safe_bool(facade.get("fullscreen"), true, "station.facade.fullscreen")

	var monitor: Dictionary = resolved["monitor"]
	monitor["enabled"] = _safe_bool(monitor.get("enabled"), false, "station.monitor.enabled")
	monitor["show_camera_image"] = _safe_bool(monitor.get("show_camera_image"), false, "station.monitor.show_camera_image")
	if monitor["show_camera_image"]:
		push_warning("show_camera_image=true wird im Publikumsrenderer ignoriert; Kamerabild bleibt verborgen.")
	monitor["width"] = _safe_positive_int(monitor.get("width"), 960, "station.monitor.width")
	monitor["height"] = _safe_positive_int(monitor.get("height"), 540, "station.monitor.height")
	monitor["prompt_font_size"] = _safe_positive_int(monitor.get("prompt_font_size"), 38, "station.monitor.prompt_font_size")
	monitor["screen"] = _safe_nonnegative_int(monitor.get("screen"), 1, "station.monitor.screen")
	monitor["fullscreen"] = _safe_bool(monitor.get("fullscreen"), true, "station.monitor.fullscreen")
	if typeof(monitor.get("mode")) != TYPE_STRING or str(monitor.get("mode")) == "":
		push_warning("station.monitor.mode ist ungültig; verwende facade_preview.")
		monitor["mode"] = "facade_preview"
	if typeof(monitor.get("title")) != TYPE_STRING or str(monitor.get("title")) == "":
		monitor["title"] = "WIRKLICHT – Resonanz"

	var prompt: Dictionary = resolved["prompt"]
	prompt["enabled"] = _safe_bool(prompt.get("enabled"), false, "station.prompt.enabled")
	if typeof(prompt.get("source")) != TYPE_STRING or str(prompt.get("source")) == "":
		push_warning("station.prompt.source ist ungültig; verwende config/prompts.json.")
		prompt["source"] = "config/prompts.json"
	if typeof(prompt.get("prompt_key")) != TYPE_STRING:
		push_warning("station.prompt.prompt_key ist ungültig; es wird kein Ersatztext angezeigt.")
		prompt["prompt_key"] = ""
	if prompt.has("prompt_keys") and not (prompt.get("prompt_keys") is Array):
		push_warning("station.prompt.prompt_keys ist keine Liste; verwende den einzelnen Prompt-Key.")
		prompt["prompt_keys"] = []
	prompt["fade_in_seconds"] = _safe_positive_float(prompt.get("fade_in_seconds"), 2.3, "station.prompt.fade_in_seconds")
	prompt["fade_out_seconds"] = _safe_positive_float(prompt.get("fade_out_seconds"), 1.4, "station.prompt.fade_out_seconds")
	prompt["underline_seconds"] = _safe_positive_float(prompt.get("underline_seconds"), 2.0, "station.prompt.underline_seconds")
	prompt["star_tail_fade_seconds"] = _safe_positive_float(prompt.get("star_tail_fade_seconds"), 3.0, "station.prompt.star_tail_fade_seconds")
	prompt["idle_cycle_seconds"] = _safe_positive_float(prompt.get("idle_cycle_seconds"), 11.0, "station.prompt.idle_cycle_seconds")
	return resolved

func _safe_bool(value, default_value: bool, label: String) -> bool:
	if typeof(value) == TYPE_BOOL:
		return value
	push_warning("%s muss true oder false sein; verwende sicheren Default." % label)
	return default_value

func _safe_positive_int(value, default_value: int, label: String) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var number := int(value)
		if number > 0:
			return number
	push_warning("%s muss eine positive Zahl sein; verwende sicheren Default." % label)
	return default_value

func _safe_nonnegative_int(value, default_value: int, label: String) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var number := int(value)
		if number >= 0:
			return number
	push_warning("%s muss eine nichtnegative Zahl sein; verwende sicheren Default." % label)
	return default_value

func _safe_positive_float(value, default_value: float, label: String) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var number := float(value)
		if number > 0.0 and is_finite(number):
			return number
	push_warning("%s muss eine positive Zahl sein; verwende sicheren Default." % label)
	return default_value

func _print_effect_state() -> void:
	var states: Array[String] = []
	for name in _effect_names():
		states.append("%s=%s" % [name, "on" if _effect_enabled(name, false) else "off"])
	print("WIRKLICHT Effekte: " + ", ".join(states))

func _print_station_state() -> void:
	var facade_cfg = _station.get("facade", {})
	var monitor_cfg = _station.get("monitor", {})
	var prompt_cfg = _station.get("prompt", {})
	var monitor_on := monitor_cfg is Dictionary and bool(monitor_cfg.get("enabled", false))
	var prompt_on := prompt_cfg is Dictionary and bool(prompt_cfg.get("enabled", false))
	var facade_screen := int(facade_cfg.get("screen", 0)) if facade_cfg is Dictionary else 0
	var monitor_screen := int(monitor_cfg.get("screen", 1)) if monitor_cfg is Dictionary else 1
	print("WIRKLICHT Stand: fassade=screen-%d, monitor=%s (screen-%d), prompt=%s" % [facade_screen, "on" if monitor_on else "off", monitor_screen, "on" if prompt_on else "off"])

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
	# Only the narrow bloom passes are used. The widest pass (level 6) smears
	# bright cores far beyond their own size, which in a full group turns many
	# individual lights into one blurred wash. A high HDR threshold makes only
	# genuinely bright cores bloom at all, so presence stays definite.
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.0)
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	we.environment = env
	add_child(we)
