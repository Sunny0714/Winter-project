extends RigidBody2D

@export var max_damage: float = 130.0
@export var knockback_force: float = 1800.0
@export var explosion_radius: float = 420.0
@export var max_range: float = 700.0
@export var fuse_time: float = 2.0
@export var throw_speed: float = 700.0
@export var rotation_speed: float = 9.0
@export var visual_scale: float = 0.7
@export var grenade_mass: float = 0.05
@export var bounce_strength: float = 1.0
@export var bounce_boost: float = 1.5
@export var max_bounce_speed: float = 3000.0

var exploded := false
var throw_origin := Vector2.ZERO
var fuse_timer := 0.0
var flash_timer := 0.0
var flash_on := false
var flash_interval := 0.6

func _ready():
	gravity_scale = 0.0
	mass = grenade_mass
	linear_damp = 0.0
	angular_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = bounce_strength
	physics_material_override.friction = 0.0
	physics_material_override.rough = true
	$Sprite2D.scale = Vector2.ONE * visual_scale
	angular_velocity = rotation_speed
	fuse_timer = fuse_time
	flash_timer = flash_interval
	throw_origin = global_position
	$Explosion/CollisionShape2D.shape = $Explosion/CollisionShape2D.shape.duplicate()
	$Explosion/CollisionShape2D.shape.radius = explosion_radius
	$Explosion/Ripple.hide()

func _physics_process(delta):
	if exploded:
		return

	fuse_timer -= delta
	flash_timer -= delta

	if flash_timer <= 0:
		flash_on = not flash_on
		$Sprite2D.modulate = Color.RED if flash_on else Color.WHITE
		flash_interval = lerpf(0.6, 0.08, 1.0 - clampf(fuse_timer / fuse_time, 0.0, 1.0))
		flash_timer = flash_interval

	if global_position.distance_to(throw_origin) >= max_range or fuse_timer <= 0:
		explode()

func _integrate_forces(state):
	if exploded:
		return

	for i in range(state.get_contact_count()):
		var normal = state.transform.basis_xform(state.get_contact_local_normal(i)).normalized()
		var velocity_before = state.linear_velocity

		if velocity_before.dot(normal) < 0:
			state.linear_velocity = velocity_before.bounce(normal) * bounce_boost
			state.linear_velocity = state.linear_velocity.limit_length(max_bounce_speed)

func launch(direction: Vector2, target_position: Vector2):
	throw_origin = global_position
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		var distance = player.global_position.distance_to(target_position)
		var throw_strength = pow(clampf(distance / 500.0, 0.0, 1.0), 2.0)
		throw_strength = clampf(throw_strength, 0.0, 1.0)
		linear_velocity = direction.normalized() * 800.0 * throw_strength
	else:
		linear_velocity = direction.normalized() * 800.0
	angular_velocity = rotation_speed

func explode():
	if exploded:
		return

	exploded = true
	freeze = true
	$Sprite2D.hide()

	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("screen_shake"):
		player.screen_shake(12.0)

	await get_tree().physics_frame

	var explosion_shape = $Explosion/CollisionShape2D
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = explosion_shape.shape
	query.transform = explosion_shape.global_transform
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [get_rid()]

	var results = get_world_2d().direct_space_state.intersect_shape(query, 64)
	var hit_targets: Array = []
	for result in results:
		var target = result["collider"]

		while target != null and not target.is_in_group("enemy") and not target.is_in_group("player"):
			target = target.get_parent()

		if target == null or target in hit_targets:
			continue

		hit_targets.append(target)

		var distance = global_position.distance_to(target.global_position)
		var damage_factor = 1.0 - clampf(distance / explosion_radius, 0.0, 1.0)

		if damage_factor <= 0.0:
			continue

		var direction = (target.global_position - global_position).normalized()

		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT

		if target.has_method("take_damage"):
			target.take_damage(max_damage * damage_factor)

		if target.has_method("apply_knockback"):
			target.apply_knockback(direction, knockback_force * damage_factor)

	var ripple = $Explosion/Ripple
	ripple.clear_points()

	for i in range(33):
		var angle = TAU * i / 32.0
		ripple.add_point(Vector2(cos(angle), sin(angle)))

	ripple.scale = Vector2.ZERO
	ripple.modulate = Color.GRAY
	ripple.show()

	var tween = create_tween()
	tween.tween_property(ripple, "scale", Vector2.ONE * explosion_radius / 5, 0.3)
	tween.parallel().tween_property(ripple, "modulate:a", 0.0, 0.3)

	await tween.finished
	queue_free()
