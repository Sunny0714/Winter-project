
extends CharacterBody2D

@onready var sprite = $Sprite2D
@onready var health_bar = $CanvasLayer/HealthBar
@onready var damage_bar = $CanvasLayer/DamageBar
@onready var death_menu = get_tree().current_scene.get_node_or_null("DeathMenu")
@onready var damage_number_marker = $DamageNumber
@onready var held_grenade = null

@export var grenade_visual_scene: PackedScene
@export var damage_numbers_scene: PackedScene
@export var speed: float = 520
@export var dash_speed: float = 3500.0
@export var dash_duration: float = 0.1
@export var dash_cooldown: float = 1.5
@export var max_health: float = 100.0
@export var ak47_held_scene: PackedScene
@export var pistol_held_scene: PackedScene
@export var sniper_held_scene: PackedScene
@export var rpg_held_scene: PackedScene
@export var shotgun_held_scene: PackedScene
@export var melee_scene: PackedScene
@export var melee_cooldown: float = 0.4
@export var grenade_scene: PackedScene
@export var grenade_throw_cooldown: float = 0.5

var grenade_mouse_was_pressed := false
var grenade_ready := true
var melee_ready := true
var held_ak = null
var held_pistol = null
var held_rpg = null
var held_sniper = null
var held_shotgun = null
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
	add_to_group("player")
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

	var hotbar = get_tree().root.find_child("HotbarUI", true, false)
	var mouse_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if mouse_pressed and not grenade_mouse_was_pressed and grenade_ready and is_instance_valid(hotbar):
		if not hotbar.inventory_dragging and not Input.is_action_pressed("ui_cancel"):
			var item_id = Manager.hotbar[hotbar.selected_slot]["id"]
			if item_id == "grenade" and not get_viewport().gui_get_hovered_control():
				throw_grenade()

	grenade_mouse_was_pressed = mouse_pressed

	if Input.is_action_just_pressed("melee") and melee_ready and is_instance_valid(hotbar):
		var mouse_over_slot = false
		for slot in hotbar.slots.get_children():
			if slot.get_global_rect().has_point(get_global_mouse_position()):
				mouse_over_slot = true
				break

		if not mouse_over_slot and not hotbar.inventory_dragging:
			var item_id = Manager.hotbar[hotbar.selected_slot]["id"]
			if item_id == "" or item_id == "melee":
				melee_attack()

	if Input.is_action_just_pressed("dash") and dash_ready:
		if not is_weapon_reloading():
			dash()

	if shake_strength > 0:
		$Camera2D.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		shake_strength = lerp(shake_strength, 0.0, 0.15)
		if shake_strength < 0.1:
			shake_strength = 0

func is_weapon_reloading() -> bool:
	if is_instance_valid(held_ak) and held_ak.is_reloading:
		return true
	if is_instance_valid(held_pistol) and held_pistol.is_reloading:
		return true
	if is_instance_valid(held_sniper) and held_sniper.is_reloading:
		return true
	if is_instance_valid(held_shotgun) and held_shotgun.is_reloading:
		return true
	if is_instance_valid(held_rpg) and held_rpg.is_reloading:
		return true
	return false

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
	number.global_position = damage_number_marker.global_position
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
	if dead or is_stunned or not dash_ready or is_weapon_reloading():
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

	if is_instance_valid(held_pistol):
		held_pistol.visible = false
		held_pistol.set_process(false)
	
	if is_instance_valid(held_rpg):
		held_rpg.visible = false
		held_rpg.set_process(false)
	
	if is_instance_valid(held_sniper):
		held_sniper.visible = false
		held_sniper.set_process(false)
	
	if is_instance_valid(held_shotgun):
		held_shotgun.visible = false
		held_shotgun.set_process(false)

	speed = 520.0

	if item_id == "ak47":
		if held_ak == null:
			if ak47_held_scene == null:
				return
			held_ak = ak47_held_scene.instantiate()
			add_child(held_ak)
		held_ak.visible = true
		held_ak.set_process(true)

	elif item_id == "pistol":
		if held_pistol == null:
			if pistol_held_scene == null:
				return
			held_pistol = pistol_held_scene.instantiate()
			add_child(held_pistol)
		held_pistol.visible = true
		held_pistol.set_process(true)

	elif item_id == "rpg":
		if held_rpg == null:
			if rpg_held_scene == null:
				return
			held_rpg = rpg_held_scene.instantiate()
			add_child(held_rpg)
		held_rpg.visible = true
		held_rpg.set_process(true)

	elif item_id == "shotgun":
		if held_shotgun == null:
			if shotgun_held_scene == null:
				return
			held_shotgun = shotgun_held_scene.instantiate()
			add_child(held_shotgun)
		held_shotgun.visible = true
		held_shotgun.set_process(true)
		
	elif item_id == "sniper":
		if held_sniper == null:
			if sniper_held_scene == null:
				return
			held_sniper = sniper_held_scene.instantiate()
			add_child(held_sniper)
		held_sniper.visible = true
		held_sniper.set_process(true)

func melee_attack():
	if melee_scene == null or not melee_ready:
		return
	melee_ready = false
	var swipe = melee_scene.instantiate()
	add_child(swipe)
	swipe.position = Vector2(0, -45)
	swipe.rotation = 3 * PI / 2
	swipe.activate()
	await get_tree().create_timer(melee_cooldown).timeout
	melee_ready = true

func throw_grenade():
	if grenade_scene == null or not grenade_ready:
		return
	var hotbar = get_tree().root.find_child("HotbarUI", true, false)
	if not is_instance_valid(hotbar):
		return
	var slot = Manager.hotbar[hotbar.selected_slot]
	if slot["id"] != "grenade" or slot["amount"] <= 0:
		return
	grenade_ready = false
	var direction = (get_global_mouse_position() - global_position).normalized()
	var grenade = grenade_scene.instantiate()
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = global_position + direction * 60.0
	grenade.add_collision_exception_with(self)
	grenade.launch(direction, get_global_mouse_position())
	slot["amount"] -= 1
	if slot["amount"] <= 0:
		slot["id"] = ""
		slot["amount"] = 0
	Manager.hotbar_changed.emit()
	await get_tree().create_timer(grenade_throw_cooldown).timeout
	grenade_ready = true

func update_grenade_visual(item_id: String):
	if is_instance_valid(held_grenade):
		held_grenade.queue_free()
		held_grenade = null
	if item_id != "grenade" or grenade_visual_scene == null:
		return
	held_grenade = grenade_visual_scene.instantiate()
	add_child(held_grenade)
	held_grenade.position = Vector2(22, -18)
	held_grenade.rotation_degrees = 45
	held_grenade.visible = true
	held_grenade.process_mode = Node.PROCESS_MODE_DISABLED
	if held_grenade is Area2D:
		held_grenade.monitoring = false
		held_grenade.monitorable = false
		held_grenade.collision_layer = 0
		held_grenade.collision_mask = 0
