# One luminous body: a glow sprite, a particle burst and a fading motion trail.
class_name BodyLight
extends Node2D

const TRAIL_MAX := 48
const GOLD := Color(1.0, 0.78, 0.38)
const INTENSE := Color(1.0, 0.36, 0.14)

var _sprite: Sprite2D
var _particles: GPUParticles2D
var _trail: Line2D
var _alpha := 1.0

func _ready() -> void:
	var tex := _make_glow_texture(256)

	_trail = Line2D.new()
	_trail.width = 10.0
	_trail.default_color = GOLD
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var grad := Gradient.new()
	grad.set_color(0, Color(GOLD.r, GOLD.g, GOLD.b, 0.0))
	grad.set_color(1, Color(GOLD.r, GOLD.g, GOLD.b, 0.8))
	_trail.gradient = grad
	add_child(_trail)

	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale = Vector2(0.4, 0.4)
	add_child(_sprite)

	_particles = GPUParticles2D.new()
	_particles.texture = tex
	_particles.amount = 48
	_particles.lifetime = 1.4
	_particles.process_material = _make_particle_material()
	add_child(_particles)

func update_state(pos: Vector2, intensity: float, openness: float) -> void:
	_alpha = 1.0
	position = pos

	var color := GOLD.lerp(INTENSE, clamp(intensity, 0.0, 1.0))
	var brightness := 1.2 + intensity * 2.5
	var hdr := Color(color.r * brightness, color.g * brightness, color.b * brightness)

	var size := 0.35 + openness * 0.6 + intensity * 0.3
	_sprite.scale = Vector2(size, size)
	_sprite.modulate = hdr

	var mat := _particles.process_material as ParticleProcessMaterial
	mat.color = hdr
	mat.initial_velocity_max = 40.0 + intensity * 260.0
	mat.emission_sphere_radius = 6.0 + openness * 30.0
	_particles.amount = int(24 + intensity * 88)

	_push_trail(pos)

func fade(delta: float) -> bool:
	# Returns true when fully faded and safe to remove.
	_alpha = max(_alpha - delta * 1.2, 0.0)
	modulate.a = _alpha
	return _alpha <= 0.0

func _push_trail(pos: Vector2) -> void:
	# Trail lives in world space; keep points in the parent's coordinates.
	_trail.global_position = Vector2.ZERO
	_trail.add_point(pos)
	while _trail.get_point_count() > TRAIL_MAX:
		_trail.remove_point(0)

func _make_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 10.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, 0, 0)
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 120.0
	mat.scale_min = 0.1
	mat.scale_max = 0.4
	mat.color = GOLD
	return mat

func _make_glow_texture(size: int) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex
