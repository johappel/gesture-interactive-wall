# Floating fire-orbs that visualise proximity between two people.
#
# This is not a UI connector line. When two individuals move toward each other,
# a few warm light orbs begin to shuttle back and forth along the space between
# them. The closer they come, the more the orbs slow, cluster and warm — until,
# standing together, they condense into a small shared field at the midpoint.
# That condensed field is the pair's own quiet "we", one step below crowd_aura.
#
# The manager owns its motion time and redraws every frame, so the bridge stays
# live (the old inline line only refreshed on input). Disabled means the node is
# never created, so nothing is drawn or simulated.
#
# The endpoints and the closeness are deliberately smoothed, and a pair only
# condenses into its field once the two are genuinely close (min_distance).
# MediaPipe pose centres jitter by a few percent of the frame from one sample to
# the next; on a real camera that alone made the orbs jump between partners and
# flicker on and off. Smoothed inputs keep a bridge continuous even at a low
# sampling rate, while the threshold gate in capture still decides which pairs
# exist at all.
class_name ProximityBridges
extends Node2D

# Fixed pool of phase seeds so a live orbs_max increase adds distinct orbs to
# existing bridges instead of reusing (overlapping) the seeds of the count the
# bridge was born with. Must be >= the overlay's orbs_max slider maximum.
const SEED_POOL := 24

var _orbs_min := 2
var _orbs_max := 6
var _travel := 0.8
var _speed := 2.2
var _orb_size := 26.0
var _wobble := 0.06
var _max_alpha := 0.85
var _field_strength := 0.6
var _fade_seconds := 0.6
var _occluded_fade_seconds := 0.3
var _smoothing := 0.15
var _min_distance := 0.22
var _warm_color := Color("#ffcd79")
var _hot_color := Color("#ff9a3c")

var _texture: GradientTexture2D
var _time := 0.0
# key "a-b" -> {a:int, b:int, pa:Vector2, pb:Vector2, proximity:float, alpha:float, seeds:PackedFloat32Array}
var _bridges: Dictionary = {}


func _init() -> void:
	z_index = -1
	var mat := CanvasItemMaterial.new()
	# Fire orbs add light rather than paint over it.
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_texture = _make_orb_texture(128)


func configure(config: Dictionary) -> void:
	_orbs_min = maxi(_int_value(config, "orbs_min", 2), 1)
	_orbs_max = maxi(_int_value(config, "orbs_max", 6), _orbs_min)
	_travel = clampf(_number(config, "travel", 0.8), 0.0, 1.0)
	_speed = maxf(_number(config, "speed", 2.2), 0.05)
	_orb_size = maxf(_number(config, "orb_size", 26.0), 1.0)
	_wobble = clampf(_number(config, "wobble", 0.06), 0.0, 0.5)
	_max_alpha = clampf(_number(config, "max_alpha", 0.85), 0.0, 1.0)
	_field_strength = clampf(_number(config, "field_strength", 0.6), 0.0, 1.0)
	_fade_seconds = maxf(_number(config, "fade_seconds", 0.6), 0.05)
	_occluded_fade_seconds = maxf(_number(config, "occluded_fade_seconds", 0.3), 0.05)
	_smoothing = clampf(_number(config, "smoothing", 0.15), 0.01, 1.0)
	_min_distance = clampf(_number(config, "min_distance", 0.22), 0.0, 1.0)
	_warm_color = _color_value(config, "warm_color", Color("#ffcd79"))
	_hot_color = _color_value(config, "hot_color", Color("#ff9a3c"))


# `pairs` carry their own normalised endpoints (ax/ay/bx/by), so a bridge can
# stay drawn while one partner is briefly occluded (only one visible body).
func update_pairs(pairs: Array, viewport: Vector2, delta: float) -> void:
	var seen := {}
	# One blend factor per packet, not per bridge: all pairs move with the same
	# sampling rate, and a shared step keeps the smoothing predictable.
	var blend := clampf(delta / _smoothing, 0.0, 1.0)
	for p in pairs:
		if not (p is Dictionary) or not p.has("a") or not p.has("b"):
			continue
		if not (_finite01(p.get("ax")) and _finite01(p.get("ay")) and _finite01(p.get("bx")) and _finite01(p.get("by"))):
			continue
		var a := int(p["a"])
		var b := int(p["b"])
		var pa := Vector2(float(p["ax"]) * viewport.x, float(p["ay"]) * viewport.y)
		var pb := Vector2(float(p["bx"]) * viewport.x, float(p["by"]) * viewport.y)
		var key := "%d-%d" % [mini(a, b), maxi(a, b)]
		seen[key] = true
		# Recompute closeness from the normalised separation (same metric the
		# capture side uses) instead of trusting the raw per-packet value: a
		# pair merely sitting near the threshold must not make the orbs flicker
		# between loose and condensed.
		var dx := float(p["bx"]) - float(p["ax"])
		var dy := float(p["by"]) - float(p["ay"])
		var proximity := _proximity_for(sqrt(dx * dx + dy * dy))
		var occluded := bool(p.get("occluded", false))
		if _bridges.has(key):
			var bridge: Dictionary = _bridges[key]
			# Typed locals first: assigning a Variant into a typed variable is
			# checked, and it keeps the lerp unambiguous.
			var smoothed_pa: Vector2 = bridge["pa"]
			var smoothed_pb: Vector2 = bridge["pb"]
			bridge["pa"] = smoothed_pa.lerp(pa, blend)
			bridge["pb"] = smoothed_pb.lerp(pb, blend)
			bridge["occluded"] = occluded
			if occluded:
				# One partner is only remembered, not observed: freeze the
				# closeness and quickly damp the bridge instead of inventing
				# motion or spawning orbs for an unseen person.
				bridge["alpha"] = maxf(float(bridge["alpha"]) - delta / _occluded_fade_seconds, 0.0)
			else:
				var smoothed_prox: float = bridge["proximity"]
				bridge["proximity"] = smoothed_prox + (proximity - smoothed_prox) * blend
				bridge["alpha"] = minf(float(bridge["alpha"]) + delta / _fade_seconds, 1.0)
		else:
			# A new pair starts already placed: easing in from the screen origin
			# would read as the orbs flying across the whole façade.
			_bridges[key] = {
				"pa": pa,
				"pb": pb,
				"proximity": proximity,
				"alpha": 0.0,
				"occluded": occluded,
				"motion_time": 0.0,
				"seeds": _make_seeds(),
			}

	for key in _bridges.keys():
		if not seen.has(key):
			var bridge: Dictionary = _bridges[key]
			bridge["alpha"] = float(bridge["alpha"]) - delta / _fade_seconds
			if float(bridge["alpha"]) <= 0.0:
				_bridges.erase(key)
	queue_redraw()


# Closeness 0..1 for a separation in normalised x units. `min_distance` is the
# separation at which two people count as truly standing together, so the pair
# field forms only on real closeness rather than on the bridge threshold.
func _proximity_for(distance: float) -> float:
	if _min_distance <= 0.0:
		return 1.0 if distance <= 0.0 else 0.0
	return clampf(1.0 - distance / _min_distance, 0.0, 1.0)


func _finite01(value) -> bool:
	if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and number >= 0.0 and number <= 1.0


func clear() -> void:
	_bridges.clear()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	for key in _bridges.keys():
		var bridge: Dictionary = _bridges[key]
		# A frozen (occluded) bridge does not advance its motion clock, so its
		# orbs hold still instead of animating an unobserved person.
		if not bool(bridge.get("occluded", false)):
			bridge["motion_time"] = float(bridge.get("motion_time", 0.0)) + delta
	# Fading pairs keep receding even without fresh packets.
	if not _bridges.is_empty():
		queue_redraw()


func _draw() -> void:
	for key in _bridges.keys():
		_draw_bridge(_bridges[key])


func _draw_bridge(bridge: Dictionary) -> void:
	var a: Vector2 = bridge["pa"]
	var b: Vector2 = bridge["pb"]
	var proximity: float = float(bridge["proximity"])
	var alpha: float = clampf(float(bridge["alpha"]), 0.0, 1.0)
	if alpha <= 0.001:
		return
	var seeds: PackedFloat32Array = bridge["seeds"]
	var axis := b - a
	var length := axis.length()
	if length < 1.0:
		return
	var perp := axis.orthogonal().normalized()

	# A barely-there residual spur hints at the connection without a hard line.
	var band := _warm_color
	band.a = 0.06 * alpha
	draw_line(a, b, band, 2.0, true)

	# Approaching: orbs shuttle far along the segment. Standing together: the
	# amplitude collapses so the orbs cluster into a small shared field.
	var amplitude: float = _travel * (1.0 - 0.85 * proximity)
	var orb_count: int = int(round(lerp(float(_orbs_min), float(_orbs_max), proximity)))
	var colour := _warm_color.lerp(_hot_color, proximity)
	var size := _orb_size * (0.7 + 0.6 * proximity)
	var motion_time: float = float(bridge.get("motion_time", 0.0))

	for i in range(orb_count):
		var seed := seeds[i % seeds.size()]
		var phase := motion_time * _speed * (0.6 + 0.4 * proximity) + seed * TAU
		var along := 0.5 + 0.5 * amplitude * sin(phase)
		var sway := _wobble * length * sin(phase * 0.7 + seed * 4.0)
		var centre := a.lerp(b, along) + perp * sway
		var orb_alpha := _max_alpha * alpha * (0.55 + 0.45 * proximity)
		_draw_orb(centre, size, Color(colour.r, colour.g, colour.b, orb_alpha))

	# The condensed pair field: only once they truly stand together.
	var field := smoothstep(0.55, 1.0, proximity) * _field_strength
	if field > 0.001:
		var mid := a.lerp(b, 0.5)
		var field_col := colour
		field_col.a = _max_alpha * alpha * field * 0.6
		_draw_orb(mid, size * 2.6, field_col)


func _draw_orb(centre: Vector2, diameter: float, colour: Color) -> void:
	var half := Vector2(diameter, diameter) * 0.5
	draw_texture_rect(_texture, Rect2(centre - half, Vector2(diameter, diameter)), false, colour)


func _make_seeds() -> PackedFloat32Array:
	var seeds := PackedFloat32Array()
	for i in range(SEED_POOL):
		seeds.append(randf())
	return seeds


func _make_orb_texture(size: int) -> GradientTexture2D:
	# A definite warm core with a short soft rim: a small fire orb, not a smear.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.28, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.9),
		Color(1, 1, 1, 0.28),
		Color(1, 1, 1, 0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex


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


func _color_value(config: Dictionary, key: String, default_value: Color) -> Color:
	var value = config.get(key, default_value)
	if typeof(value) == TYPE_STRING and Color.from_string(str(value), Color.TRANSPARENT) != Color.TRANSPARENT:
		return Color.from_string(str(value), default_value)
	return default_value