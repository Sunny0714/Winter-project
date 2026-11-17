extends CharacterBody2D

@onready var sprite = $Sprite2D
@onready var health_bar = $CanvasLayer/HealthBar
@onready var damage_bar = $CanvasLayer/DamageBar
@onready var death_menu = get_tree().current_scene.get_node_or_null("DeathMenu")

@export var damage_numbers_scene: PackedScene
@export var speed: float = 520
@export var dash_speed: float = 4000.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 1.5
@export var max_health: float = 100.0
@export var ak47_held_scene: PackedScene

var held_ak = null
var dead := false
var is_stunned := false
var dash_ready := true
var is_dashing := false
var shake_strength := 0.0
var dash_velocity := Vector2.ZERO
var health: float

var knockback_velocity := Vector2.ZERO
var knockback_timer := 0.0
var pending_heal := 0.0

func _ready():
	health = max_health
	health_bar.max_value = max_health
	damage_bar.max_value = max_health
	health_bar.value = health
	damage_bar.value = health

func _physics_process(delta):
	if is_stunned or dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if Input.is_action_just_pressed("interact"):
		interact()
	if pending_heal > 0:
		heal(pending_heal)
		pending_heal = 0

	health_bar.set_health(health)
	update_damage_bar()

	var dir = Vector2(Input.get_action_strength("right") - Input.get_action_strength("left"), Input.get_action_strength("down") - Input.get_action_strength("up")).normalized()

	if is_dashing:
		velocity = dash_velocity
	elif knockback_timer > 0:
		velocity = knockback_velocity
		knockback_timer -= delta
	else:
		velocity = dir * speed

	move_and_slide()
	look_at(get_global_mouse_position())
	rotation += deg_to_rad(90)

func _process(delta):
	if is_stunned or dead:
		return

	if Input.is_action_just_pressed("dash") and dash_ready:
		dash()

	if shake_strength > 0:
		$Camera2D.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		shake_strength = lerp(shake_strength, 0.0, 0.15)

		if shake_strength < 0.1:
			shake_strength = 0

func take_damage(amount: float):
	if dead:
		return

	var actual_damage = min(amount, health)
	health = clamp(health - amount, 0, max_health)

	if actual_damage > 0:
		spawn_damage_number(actual_damage, false)

	health_bar.set_health(health)
	screen_shake(4.0)
	flash_red()

	if health <= 0:
		dead = true
		death_menu.show_death_menu()

func heal(amount: float):
	if dead:
		return

	var actual_heal = min(amount, max_health - health)
	health = clamp(health + amount, 0, max_health)

	if actual_heal > 0:
		spawn_damage_number(actual_heal, true)

	health_bar.set_health(health)
	update_damage_bar()

func spawn_damage_number(amount: float, is_healing: bool = false):
	if damage_numbers_scene == null:
		return

	var number = damage_numbers_scene.instantiate()
	get_tree().current_scene.add_child(number)
	number.global_position = global_position
	number.setup(amount, is_healing)

func flash_red():
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout

	if is_instance_valid(sprite):
		sprite.modulate = Color.WHITE

func screen_shake(amount: float = 18.0):
	shake_strength = amount

func apply_knockback(direction: Vector2, force: float, duration: float = 0.25):
	if dead or is_stunned:
		return

	knockback_velocity = direction * force
	knockback_timer = duration

func update_damage_bar():
	var tween = create_tween()
	tween.tween_property(damage_bar, "value", health, 0.35)

func dash():
	if dead or is_stunned or not dash_ready:
		return

	dash_ready = false
	is_dashing = true

	var dash_dir = Vector2.ZERO

	if Input.is_action_pressed("right"):
		dash_dir.x += 1
	if Input.is_action_pressed("left"):
		dash_dir.x -= 1
	if Input.is_action_pressed("down"):
		dash_dir.y += 1
	if Input.is_action_pressed("up"):
		dash_dir.y -= 1

	if dash_dir == Vector2.ZERO:
		dash_dir = (get_global_mouse_position() - global_position).normalized()

	dash_velocity = dash_dir.normalized() * dash_speed

	await get_tree().create_timer(dash_duration).timeout

	is_dashing = false
	dash_velocity = Vector2.ZERO

	await get_tree().create_timer(dash_cooldown).timeout
	dash_ready = true

func stun(duration: float = 1.5):
	if is_stunned or dead:
		return

	is_stunned = true
	velocity = Vector2.ZERO

	var tween = create_tween()
	tween.set_loops(int(duration / 0.2))
	tween.tween_property(sprite, "modulate", Color(0.4, 0.4, 0.4), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	await get_tree().create_timer(duration).timeout

	is_stunned = false
	sprite.modulate = Color.WHITE

func interact():
	pass

func equip_hotbar_item(item_id: String):
	if is_instance_valid(held_ak):
		held_ak.visible = false
		held_ak.set_process(false)

	if item_id != "ak47":
		speed = 520.0
		return

	if held_ak == null:
		if ak47_held_scene == null:
			return

		held_ak = ak47_held_scene.instantiate()
		add_child(held_ak)

	held_ak.visible = true
	held_ak.set_process(true)
