extends CharacterBody2D

@export var min_health: float = 150.0
@export var max_health: float = 200.0
@export var vision_range: float = 750.0
@export var move_speed: float = 700.0
@export var contact_damage: float = 20.0
@export var knockback_force: float = 3200.0
@export var hit_cooldown: float = 0.4
@export var damage_number_scene: PackedScene
@export var knockback_decay: float = 1800.0
@export var knockback_factor: float = 1.0

@onready var sprite = $Sprite2D
@onready var health_bar = $HealthBar

var shotgun_damage_generation := {}
var shotgun_pellet_counts := {}
var shotgun_damage_totals := {}
var shotgun_damage_timers := {}
var health: float
var player: Node2D
var knockback_velocity := Vector2.ZERO
var slow_multiplier := 1.0
var aggroed := false
var dead := false
var can_hit := true
var frozen := false
var zigzag_timer := 0.0
var zigzag_direction := 1.0
var spawned_enemy := false
var flash_id := 0

func _ready():
	add_to_group("enemy")
	add_to_group("enemies")
	collision_mask |= 4
	player = get_tree().root.find_child("Player", true, false)
	health = randf_range(min_health, max_health)
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = false

func take_damage(amount: float, shot_id: int = 0):
	if dead or amount <= 0:
		return
	aggroed = true
	flash_red()
	health_bar.visible = true
	if shot_id == 0:
		health = clampf(health - amount, 0.0, max_health)
		show_damage_number(amount, Color.WHITE, "")
		health_bar.value = health
		if health <= 0:
			die()
		return
	if not shotgun_damage_totals.has(shot_id):
		shotgun_damage_totals[shot_id] = 0.0
		shotgun_pellet_counts[shot_id] = 0
		shotgun_damage_generation[shot_id] = 0
	shotgun_damage_totals[shot_id] += amount
	shotgun_pellet_counts[shot_id] += 1
	shotgun_damage_generation[shot_id] += 1
	var current_generation = shotgun_damage_generation[shot_id]
	var timer = get_tree().create_timer(0.12)
	shotgun_damage_timers[shot_id] = timer
	timer.timeout.connect(func():
		if not is_instance_valid(self) or dead:
			return
		if not shotgun_damage_totals.has(shot_id):
			return
		if shotgun_damage_generation[shot_id] != current_generation:
			return
		var total = shotgun_damage_totals[shot_id]
		var final_hits = shotgun_pellet_counts[shot_id]
		shotgun_damage_totals.erase(shot_id)
		shotgun_pellet_counts.erase(shot_id)
		shotgun_damage_timers.erase(shot_id)
		shotgun_damage_generation.erase(shot_id)
		health = clampf(health - total, 0.0, max_health)
		var intensity = clampf(float(final_hits - 3) / 13.0, 0.0, 1.0)
		var damage_color = Color.WHITE.lerp(Color(1.0, 0.55, 0.05), intensity)
		var suffix = "!" if final_hits >= 16 else ""
		show_damage_number(total, damage_color, suffix)
		health_bar.value = health
		if health <= 0: die())

func show_damage_number(amount: float, number_color: Color = Color.WHITE, suffix: String = ""):
	if damage_number_scene == null:
		return
	var number = damage_number_scene.instantiate()
	get_tree().current_scene.add_child(number)
	number.global_position = global_position + Vector2(0, -40)
	if number.has_method("setup"):
		number.setup(amount, false)
	number.scale = Vector2.ONE * clampf(amount / 5.0, 1.0, 2.0)
	if number is Label:
		number.text = str(roundi(amount)) + suffix
		number.add_theme_color_override("font_color", number_color)
	elif number is RichTextLabel:
		number.text = "[color=#%s]%d%s[/color]" % [number_color.to_html(false), roundi(amount), suffix]

func _physics_process(delta):
	if dead:
		return
	if frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)
		if not is_instance_valid(player):
			return
	var dist = global_position.distance_to(player.global_position)
	if not aggroed and dist > vision_range:
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
		return
	aggroed = true
	var dir = (player.global_position - global_position).normalized()
	sprite.rotation = dir.angle() - deg_to_rad(90)
	zigzag_timer -= delta
	if zigzag_timer <= 0:
		zigzag_timer = randf_range(0.3, 0.8)
		zigzag_direction = [-1.0, 1.0].pick_random()
	var side = Vector2(-dir.y, dir.x)
	velocity = (dir * move_speed * 0.8 + side * move_speed * 0.8 * zigzag_direction) * slow_multiplier
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	move_and_slide()
	if can_hit:
		for i in range(get_slide_collision_count()):
			var body = get_slide_collision(i).get_collider()
			if body and body.is_in_group("player"):
				_do_hit(body)
				break

func set_frozen(state: bool):
	frozen = state
	velocity = Vector2.ZERO

func _do_hit(body):
	if frozen or dead or not can_hit:
		return
	can_hit = false
	if body.has_method("take_damage"):
		body.take_damage(contact_damage)
	if body.has_method("apply_knockback"):
		var direction = (body.global_position - global_position).normalized()
		body.apply_knockback(direction, knockback_force)
	await get_tree().create_timer(hit_cooldown).timeout
	if is_instance_valid(self):
		can_hit = true

func die():
	if dead:
		return
	dead = true
	queue_free()

func flash_red():
	flash_id += 1
	var current_id = flash_id
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(sprite) and current_id == flash_id:
		sprite.modulate = Color.WHITE

func apply_knockback(direction: Vector2, force: float):
	if dead:
		return
	knockback_velocity = direction.normalized() * force * knockback_factor
	aggroed = true
func apply_slow(amount):
	slow_multiplier = amount
func remove_slow():
	slow_multiplier = 1.0
	sprite.modulate = Color.WHITE
