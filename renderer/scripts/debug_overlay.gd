# In-Renderer tuning overlay (toggle with F3).
#
# This is a debug tool, not part of the public installation. It exposes the
# effect parameters as bounded sliders so an operator can see the façade react
# while tuning. Every slider is clamped to a range that the effect's own
# configure() already accepts, so no value here can drive the engine into an
# invalid state (e.g. zero particle amounts or non-finite radii).
#
# The overlay never edits capture/tracking parameters: only the renderer-side
# effects block is live-reloadable. Values are applied to the running scene
# immediately and can be written back to config/config.json with "Speichern".
extends CanvasLayer

# Single source of truth lives in capture/sim.py; this list mirrors it for the
# dropdown. A wrong name is harmless: the simulator ignores unknown scenarios.
const SIM_SCENARIOS := [
	"phase44",
	"stable",
	"occlusion",
	"flicker",
	"crossing",
	"center_loss",
	"left_departure",
	"right_departure",
	"group_left_departure",
	"departure_return",
	"long_run",
	"stay_resonance",
	"aftereffect_waves",
	"crowd_aura",
	"proximity",
]

var _main
var _rows: Array = []
var _enabled_checks: Dictionary = {}
var _global_enabled_check: CheckBox
var _minimal_check: CheckBox
var _sim_option: OptionButton
var _status_label: Label
var _working: Dictionary = {}
var _suppress := false


func bind_main(main) -> void:
	_main = main


func _ready() -> void:
	layer = 128
	visible = false
	_build()
	sync_from_config()


func toggle() -> void:
	visible = not visible
	if visible:
		sync_from_config()


func _schema() -> Array:
	# min/max mirror the clamps in each effect's configure(); nothing here can
	# produce a value the effect would reject.
	return [
		{"effect": "body_glow", "label": "Body-Glow", "params": []},
		{"effect": "trails", "label": "Trails", "params": [
			{"key": "width", "min": 1.0, "max": 80.0, "step": 0.5, "type": "float", "default": 20.0},
			{"key": "max_points", "min": 1, "max": 200, "step": 1, "type": "int", "default": 25},
		]},
		{"effect": "sparks", "label": "Funken", "params": [
			{"key": "amount_min", "min": 1, "max": 400, "step": 1, "type": "int", "default": 24},
			{"key": "amount_max", "min": 1, "max": 400, "step": 1, "type": "int", "default": 112},
			{"key": "lifetime", "min": 0.1, "max": 10.0, "step": 0.1, "type": "float", "default": 1.4},
			{"key": "velocity_min", "min": 0.0, "max": 1000.0, "step": 1.0, "type": "float", "default": 20.0},
			{"key": "velocity_max", "min": 0.0, "max": 2000.0, "step": 1.0, "type": "float", "default": 300.0},
			{"key": "activation_intensity", "min": 0.0, "max": 1.0, "step": 0.01, "type": "float", "default": 0.09},
		]},
		{"effect": "proximity_bridges", "label": "Nähe-Brücken", "params": [
			{"key": "orbs_min", "min": 1, "max": 20, "step": 1, "type": "int", "default": 2},
			{"key": "orbs_max", "min": 1, "max": 20, "step": 1, "type": "int", "default": 6},
			{"key": "travel", "min": 0.0, "max": 1.0, "step": 0.01, "type": "float", "default": 0.8},
			{"key": "speed", "min": 0.05, "max": 10.0, "step": 0.05, "type": "float", "default": 2.2},
			{"key": "orb_size", "min": 1.0, "max": 200.0, "step": 1.0, "type": "float", "default": 26.0},
			{"key": "wobble", "min": 0.0, "max": 0.5, "step": 0.01, "type": "float", "default": 0.06},
			{"key": "max_alpha", "min": 0.0, "max": 1.0, "step": 0.01, "type": "float", "default": 0.85},
			{"key": "field_strength", "min": 0.0, "max": 1.0, "step": 0.01, "type": "float", "default": 0.6},
			{"key": "fade_seconds", "min": 0.05, "max": 5.0, "step": 0.05, "type": "float", "default": 0.6},
			{"key": "warm_color", "type": "color", "default": "#ffcd79"},
			{"key": "hot_color", "type": "color", "default": "#ff9a3c"},
		]},
		{"effect": "stillness_resonance", "label": "Verweil-Resonanz", "params": [
			{"key": "min_presence_seconds", "min": 0.1, "max": 20.0, "step": 0.1, "type": "float", "default": 3.0},
			{"key": "pulse_seconds", "min": 0.5, "max": 30.0, "step": 0.1, "type": "float", "default": 6.0},
			{"key": "max_scale", "min": 0.1, "max": 5.0, "step": 0.1, "type": "float", "default": 2.3},
		]},
		{"effect": "crowd_aura", "label": "Crowd-Aura", "params": [
			{"key": "min_people", "min": 1, "max": 20, "step": 1, "type": "int", "default": 3},
			{"key": "full_strength_people", "min": 1, "max": 30, "step": 1, "type": "int", "default": 10},
			{"key": "fade_in_seconds", "min": 0.05, "max": 15.0, "step": 0.05, "type": "float", "default": 2.5},
			{"key": "fade_out_seconds", "min": 0.05, "max": 15.0, "step": 0.05, "type": "float", "default": 4.0},
			{"key": "pulse_seconds", "min": 0.5, "max": 30.0, "step": 0.1, "type": "float", "default": 9.0},
			{"key": "padding", "min": 0.0, "max": 0.6, "step": 0.01, "type": "float", "default": 0.12},
			{"key": "softness", "min": 0.01, "max": 0.9, "step": 0.01, "type": "float", "default": 0.18},
			{"key": "min_alpha", "min": 0.0, "max": 0.5, "step": 0.01, "type": "float", "default": 0.05},
			{"key": "max_alpha", "min": 0.0, "max": 0.6, "step": 0.01, "type": "float", "default": 0.18},
			{"key": "energy_influence", "min": 0.0, "max": 1.0, "step": 0.01, "type": "float", "default": 0.3},
			{"key": "individual_dimming_max", "min": 0.0, "max": 1.0, "step": 0.01, "type": "float", "default": 0.45},
			{"key": "body_clearance", "min": 0.02, "max": 0.5, "step": 0.01, "type": "float", "default": 0.13},
			{"key": "gap_emphasis", "min": 0.0, "max": 1.0, "step": 0.01, "type": "float", "default": 0.75},
			{"key": "warm_color", "type": "color", "default": "#ffe3a1"},
			{"key": "cool_color", "type": "color", "default": "#5caeff"},
		]},
		{"effect": "aftereffect_waves", "label": "Nachwirkungs-Wellen", "params": [
			{"key": "group_window_seconds", "min": 0.0, "max": 2.0, "step": 0.01, "type": "float", "default": 0.22},
			{"key": "group_distance", "min": 0.0, "max": 1.0, "step": 0.01, "type": "float", "default": 0.18},
			{"key": "group_width_per_departure", "min": 0.0, "max": 0.5, "step": 0.01, "type": "float", "default": 0.1},
			{"key": "duration_seconds", "min": 0.1, "max": 15.0, "step": 0.1, "type": "float", "default": 4.8},
			{"key": "initial_origin_outset", "min": 0.0, "max": 0.5, "step": 0.01, "type": "float", "default": 0.03},
			{"key": "origin_escape_distance", "min": 0.0, "max": 1.0, "step": 0.01, "type": "float", "default": 0.5},
			{"key": "start_radius", "min": 0.001, "max": 1.0, "step": 0.001, "type": "float", "default": 0.03},
			{"key": "propagation_speed", "min": 0.001, "max": 2.0, "step": 0.001, "type": "float", "default": 0.35},
			{"key": "band_width", "min": 0.01, "max": 0.5, "step": 0.01, "type": "float", "default": 0.09},
			{"key": "source_glow_radius", "min": 0.01, "max": 0.6, "step": 0.01, "type": "float", "default": 0.26},
			{"key": "echo_spacing", "min": 0.0, "max": 1.0, "step": 0.01, "type": "float", "default": 0.15},
			{"key": "echo_strength", "min": 0.0, "max": 1.0, "step": 0.001, "type": "float", "default": 0.058},
			{"key": "max_alpha", "min": 0.01, "max": 0.5, "step": 0.01, "type": "float", "default": 0.26},
			{"key": "fade_start_progress", "min": 0.0, "max": 0.95, "step": 0.01, "type": "float", "default": 0.15},
			{"key": "fade_end_progress", "min": 0.05, "max": 1.0, "step": 0.01, "type": "float", "default": 0.99},
			{"key": "glow_strength", "min": 0.1, "max": 4.0, "step": 0.05, "type": "float", "default": 1.55},
			{"key": "dedupe_seconds", "min": 0.1, "max": 30.0, "step": 0.1, "type": "float", "default": 5.0},
			{"key": "warm_color", "type": "color", "default": "#ffcd79"},
			{"key": "blue_color", "type": "color", "default": "#164155"},
		]},
	]


func _build() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "WIRKLICHT Debug – Live-Regler (F3)"
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var save_btn := Button.new()
	save_btn.text = "Speichern"
	save_btn.pressed.connect(_on_save)
	header.add_child(save_btn)

	var globals := HBoxContainer.new()
	root.add_child(globals)
	_global_enabled_check = CheckBox.new()
	_global_enabled_check.text = "effects.enabled"
	_global_enabled_check.toggled.connect(_on_global_enabled)
	globals.add_child(_global_enabled_check)
	_minimal_check = CheckBox.new()
	_minimal_check.text = "minimal_mode"
	_minimal_check.toggled.connect(_on_minimal)
	globals.add_child(_minimal_check)

	var sim_row := HBoxContainer.new()
	root.add_child(sim_row)
	var sim_label := Label.new()
	sim_label.text = "Simulations-Szenario"
	sim_label.custom_minimum_size = Vector2(190, 0)
	sim_row.add_child(sim_label)
	_sim_option = OptionButton.new()
	_sim_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(SIM_SCENARIOS.size()):
		_sim_option.add_item(SIM_SCENARIOS[index], index)
	_sim_option.selected = 0
	_sim_option.item_selected.connect(_on_sim_scenario_selected)
	sim_row.add_child(_sim_option)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 680)
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)

	for group in _schema():
		content.add_child(HSeparator.new())
		var group_head := HBoxContainer.new()
		content.add_child(group_head)
		var group_label := Label.new()
		group_label.text = str(group["label"])
		group_head.add_child(group_label)
		var head_spacer := Control.new()
		head_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group_head.add_child(head_spacer)
		var enabled_check := CheckBox.new()
		enabled_check.text = "an"
		enabled_check.toggled.connect(_on_enabled_toggled.bind(str(group["effect"])))
		group_head.add_child(enabled_check)
		_enabled_checks[str(group["effect"])] = enabled_check

		for param in group["params"]:
			_build_param_row(content, str(group["effect"]), param)

	_status_label = Label.new()
	_status_label.modulate = Color(0.7, 0.9, 0.7)
	root.add_child(_status_label)


func _build_param_row(content: VBoxContainer, effect: String, param: Dictionary) -> void:
	var row := HBoxContainer.new()
	content.add_child(row)
	var name_label := Label.new()
	name_label.text = str(param["key"])
	name_label.custom_minimum_size = Vector2(190, 0)
	row.add_child(name_label)

	if str(param["type"]) == "color":
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(180, 0)
		picker.edit_alpha = false
		picker.color_changed.connect(_on_color_changed.bind(effect, str(param["key"])))
		row.add_child(picker)
		_rows.append({
			"effect": effect,
			"key": str(param["key"]),
			"type": "color",
			"control": picker,
			"default": param["default"],
			"value_label": null,
		})
		return

	var is_int := str(param["type"]) == "int"
	var slider := HSlider.new()
	slider.min_value = float(param["min"])
	slider.max_value = float(param["max"])
	slider.step = float(param["step"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(150, 0)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(_on_slider_changed.bind(effect, str(param["key"]), is_int, value_label))
	row.add_child(slider)
	row.add_child(value_label)
	_rows.append({
		"effect": effect,
		"key": str(param["key"]),
		"type": "int" if is_int else "float",
		"control": slider,
		"default": param["default"],
		"value_label": value_label,
	})


# Reads the live effects block from main and pushes it into the controls
# without triggering the change handlers.
func sync_from_config() -> void:
	if _main == null:
		return
	_working = _main.live_effects_raw()
	_suppress = true
	for row in _rows:
		var block = _working.get(row["effect"], {})
		if not (block is Dictionary):
			block = {}
		if row["type"] == "color":
			row["control"].color = _parse_color(block.get(row["key"], row["default"]))
		else:
			var value := float(block.get(row["key"], row["default"]))
			row["control"].value = value
			row["value_label"].text = _format_value(value, row["type"])
	for effect in _enabled_checks.keys():
		var effect_block = _working.get(effect, {})
		var enabled := true
		if effect_block is Dictionary:
			enabled = bool(effect_block.get("enabled", true))
		_enabled_checks[effect].button_pressed = enabled
	_global_enabled_check.button_pressed = bool(_working.get("enabled", true))
	_minimal_check.button_pressed = bool(_working.get("minimal_mode", false))
	_suppress = false


func _on_slider_changed(value: float, effect: String, key: String, is_int: bool, value_label: Label) -> void:
	if _suppress:
		return
	value_label.text = _format_value(value, "int" if is_int else "float")
	var stored = int(round(value)) if is_int else value
	_set_param(effect, key, stored)


func _on_color_changed(color: Color, effect: String, key: String) -> void:
	if _suppress:
		return
	_set_param(effect, key, "#" + color.to_html(false))


func _on_enabled_toggled(pressed: bool, effect: String) -> void:
	if _suppress:
		return
	_set_param(effect, "enabled", pressed)


func _on_global_enabled(pressed: bool) -> void:
	if _suppress:
		return
	_working["enabled"] = pressed
	_apply()


func _on_minimal(pressed: bool) -> void:
	if _suppress:
		return
	_working["minimal_mode"] = pressed
	_apply()


func _on_sim_scenario_selected(index: int) -> void:
	if _suppress or _main == null:
		return
	if index < 0 or index >= SIM_SCENARIOS.size():
		return
	var scenario: String = SIM_SCENARIOS[index]
	_main.request_sim_scenario(scenario)
	_set_status("Szenario angefordert: %s (nur mit laufendem Simulator)." % scenario)


func _on_save() -> void:
	if _main == null:
		return
	if _main.save_live_effects_to_config():
		_set_status("In config.json gespeichert.")
	else:
		_set_status("Speichern fehlgeschlagen (siehe Log).")


func _set_param(effect: String, key: String, value) -> void:
	var block = _working.get(effect, {})
	if not (block is Dictionary):
		block = {}
	block[key] = value
	_working[effect] = block
	_apply()


func _apply() -> void:
	if _main == null:
		return
	_main.set_live_effects(_working)


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _format_value(value: float, type: String) -> String:
	if type == "int":
		return str(int(round(value)))
	return "%.3f" % value


func _parse_color(value) -> Color:
	if typeof(value) == TYPE_STRING:
		return Color.from_string(str(value), Color.WHITE)
	return Color.WHITE
