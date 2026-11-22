extends RigidBody2D

@export var explosion_radius: float = 420.0
@export var max_range: float = 700.0
@export var fuse_time: float = 2.0
@export var throw_speed: float = 700.0
@export var rotation_speed: float = 9.0
@export var grenade_mass: float = 0.05
@export var bounce_strength: float = 1.0
@export var bounce_boost: float = 1.5
@export var max_bounce_speed: float = 3000.0
@export var shield_duration: float = 5.0
@export var enemy_collision_mask: int = 2
@export var hex_size: float = 32.0
@export var wave_speed: float = 650.0
@export var push_speed: float = 220.0
@export var push_acceleration: float = 700.0

var exploded := false
var shield_active := false
var throw_origin := Vector2.ZERO
var fuse_timer := 0.0
var shield_body: StaticBody2D
var push_area: Area2D
var hex_lines: Array[Line2D] = []
var hex_positions: Array[float] = []
var shield_elapsed := 0.0
var pushed_enemies: Array[CharacterBody2D] = []

func _ready():
	gravity_scale = 0.0
	mass = grenade_mass
	linear_damp = 0.0
	angular_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	collision_mask |= enemy_collision_mask

	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = bounce_strength
	physics_material_override.friction = 0.0
	physics_material_override.rough = true

	angular_velocity = rotation_speed
	fuse_timer = fuse_time
	throw_origin = global_position

	$Explosion/CollisionShape2D.shape = $Explosion/CollisionShape2D.shape.duplicate()
	$Explosion/CollisionShape2D.shape.radius = explosion_radius
	$Explosion/Ripple.hide()

func _physics_process(delta):
	if shield_active:
		push_enemies(delta)
		return

	if exploded:
		return

	fuse_timer -= delta

	if global_position.distance_to(throw_origin) >= max_range or fuse_timer <= 0.0:
		activate_shield()

func _process(delta):
	if not shield_active:
		return

	shield_elapsed += delta
	var wave_position = explosion_radius - fposmod(shield_elapsed * wave_speed, explosion_radius * 2.0)

	for i in range(hex_lines.size()):
		var distance = abs(hex_positions[i] - wave_position)
		var glow = exp(-pow(distance / 65.0, 2.0))
		var alpha = 0.12 + glow * 0.88
		hex_lines[i].modulate = Color(0.1, 0.55, 1.0, alpha)

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
		linear_velocity = direction.normalized() * throw_speed * throw_strength
	else:
		linear_velocity = direction.normalized() * throw_speed

	angular_velocity = rotation_speed

func activate_shield():
	if exploded:
		return

	exploded = true
	shield_active = true

	collision_layer = 0
	collision_mask = 0
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	$Sprite2D.hide()
	$Explosion.monitoring = false
	$Explosion.monitorable = false
	$Explosion/CollisionShape2D.set_deferred("disabled", true)

	create_barrier()
	create_hexagon_sphere()
	create_activation_effect()

	await get_tree().create_timer(shield_duration).timeout

	shield_active = false

	if is_instance_valid(shield_body):
		shield_body.queue_free()

	queue_free()

func create_barrier():
	shield_body = StaticBody2D.new()
	shield_body.name = "ShieldBarrier"
	shield_body.collision_layer = 4
	shield_body.collision_mask = 0

	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 0.0
	collision.shape = circle

	shield_body.add_child(collision)
	get_tree().current_scene.add_child(shield_body)
	shield_body.global_position = global_position

	var tween = create_tween()
	tween.tween_property(circle, "radius", explosion_radius, 0.4)

func create_push_area():
	push_area = Area2D.new()
	push_area.name = "EnemyPushArea"
	push_area.collision_layer = 0
	push_area.collision_mask = enemy_collision_mask
	push_area.monitoring = true
	push_area.monitorable = false

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius

	collision.shape = circle
	push_area.add_child(collision)
	add_child(push_area)

func push_enemies(delta):
	if not is_instance_valid(push_area):
		return

	var current_enemies: Array[CharacterBody2D] = []

	for body in push_area.get_overlapping_bodies():
		if not body is CharacterBody2D:
			continue

		current_enemies.append(body)

		var direction = body.global_position - global_position

		if direction.length_squared() < 1.0:
			direction = Vector2.RIGHT
		else:
			direction = direction.normalized()

		var distance = body.global_position.distance_to(global_position)
		var required_distance = explosion_radius + 8.0

		if distance < required_distance:
			var outward_speed = body.velocity.dot(direction)
			var amount = minf(
				push_acceleration * delta,
				push_speed - outward_speed
			)

			if amount > 0.0:
				body.velocity += direction * amount

			# Gradually increase the outward movement until outside.
			if distance < required_distance:
				var remaining = required_distance - distance
				body.velocity += direction * minf(remaining * 2.0, push_speed * delta)

	for enemy in pushed_enemies:
		if is_instance_valid(enemy) and not current_enemies.has(enemy):
			enemy.velocity = enemy.velocity.limit_length(300.0)

	pushed_enemies = current_enemies

func create_hexagon_sphere():
	var container = Node2D.new()
	container.name = "HexagonSphere"
	add_child(container)

	var spacing_x = hex_size * 1.5
	var spacing_y = hex_size * sqrt(3.0)
	var columns = int(explosion_radius / spacing_x) + 2
	var rows = int(explosion_radius / spacing_y) + 2

	for x in range(-columns, columns + 1):
		for y in range(-rows, rows + 1):
			var center = Vector2(x * spacing_x, y * spacing_y + (x % 2) * spacing_y * 0.5)

			if center.length() > explosion_radius - hex_size:
				continue

			var line = Line2D.new()
			line.name = "EnergyHexagon"
			line.width = 2.5
			line.default_color = Color(0.1, 0.55, 1.0, 0.15)
			line.antialiased = true
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND

			for i in range(7):
				var angle = TAU * i / 6.0
				var point = center + Vector2(cos(angle), sin(angle)) * hex_size
				line.add_point(point)

			container.add_child(line)
			hex_lines.append(line)
			hex_positions.append(center.x)

	var outline = Line2D.new()
	outline.name = "EnergyOutline"
	outline.width = 4.0
	outline.default_color = Color(0.1, 0.55, 1.0, 0.75)
	outline.closed = true
	outline.antialiased = true

	for i in range(65):
		var angle = TAU * i / 64.0
		outline.add_point(Vector2(cos(angle), sin(angle)) * explosion_radius)

	container.add_child(outline)

func create_activation_effect():
	var ripple = $Explosion/Ripple
	ripple.clear_points()
	ripple.show()
	ripple.width = 8.0
	ripple.default_color = Color(0.15, 0.65, 1.0, 1.0)
	ripple.antialiased = true

	for i in range(65):
		var angle = TAU * i / 64.0
		ripple.add_point(Vector2(cos(angle), sin(angle)) * explosion_radius)

	ripple.scale = Vector2.ZERO
	ripple.modulate = Color.WHITE

	var tween = create_tween()
	tween.tween_property(ripple, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ripple, "modulate:a", 0.0, 0.45)

	for line in hex_lines:
		line.modulate = Color(0.2, 0.8, 1.0, 1.0)

	await tween.finished
	ripple.hide()
