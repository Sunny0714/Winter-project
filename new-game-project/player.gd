extends CharacterBody2D

@onready var sprite = $Sprite2D
@onready var health_bar = $CanvasLayer/HealthBar
@onready var damage_bar = $CanvasLayer/DamageBar
@onready var damage_number_marker = $DamageNumber
@onready var held_grenade = null
@onready var held_shield = null
@onready var death_menu = get_tree().root.find_child("DeathMenu", true, false)

@export var blue_potion_held_scene: PackedScene
@export var purple_potion_held_scene: PackedScene
@export var potion_use_time: float = 2.0
@export var shield_visual_scene: PackedScene
@export var grenade_visual_scene: PackedScene
@export var damage_numbers_scene: PackedScene
@export var speed: float = 520
@export var dash_speed: float = 3500.0
@export var dash_duration: float = 0.1
@export var dash_cooldown: float = 3.5
@export var max_health: float = 100.0
@export var ak47_held_scene: PackedScene
@export var pistol_held_scene: PackedScene
@export var sniper_held_scene: PackedScene
@export var rpg_held_scene: PackedScene
@export var shotgun_held_scene: PackedScene
@export var melee_scene: PackedScene
@export var melee_cooldown: float = 0.4
@export var grenade_scene: PackedScene
@export var shield_scene: PackedScene
@export var grenade_throw_cooldown: float = 0.5
@export var medkit_held_scene: PackedScene
@export var medkit_use_time: float = 5.0
@export var max_shield_health: float = 100.0
@export var max_purple_health: float = 100.0

var held_blue_potion = null
var held_purple_potion = null
var damage_bar_suppressed := false
var held_potion_id := ""
var held_potion = null
var using_potion := false
var potion_timer := 0.0
var potion_slot := -1
var potion_id := ""
var shield_throw_cooldown: float = 0.5
var held_medkit = null
var using_medkit := false
var medkit_timer := 0.0
var medkit_slot := -1
var grenade_ready := true
var shield_ready := true
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
var shield_health: float = 0.0
var purple_health: float = 0.0
var knockback_velocity := Vector2.ZERO
var knockback_timer := 0.0
var pending_heal := 0.0

func _ready():
	add_to_group("player")
	health = max_health
	shield_health = 0
	purple_health = 0
	health_bar.max_value = max_health
	damage_bar.max_value = max_health
	update_health_display()
	damage_bar.value = health_bar.value

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
	var dir = Vector2(Input.get_action_strength("right") - Input.get_action_strength("left"), Input.get_action_strength("down") - Input.get_action_strength("up")).normalized()

	if dir != Vector2.ZERO:
		if using_medkit:
			cancel_medkit_use()
		if using_potion:
			cancel_potion_use()
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

	if using_medkit:
		medkit_timer -= delta
		if medkit_timer <= 0:
			finish_medkit_use()

	if using_potion:
		potion_timer -= delta

		if not is_instance_valid(hotbar) or hotbar.selected_slot != potion_slot:
			cancel_potion_use()
		elif potion_timer <= 0:
			finish_potion_use()

	var mouse_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mouse_just_pressed = mouse_pressed

	if mouse_just_pressed and is_instance_valid(hotbar) and get_viewport().gui_get_hovered_control() == null:
		if not hotbar.inventory_dragging and not Input.is_action_pressed("ui_cancel"):
			var selected_slot = hotbar.selected_slot

			if selected_slot >= 1 and selected_slot <= 5:
				var item_id = Manager.hotbar[selected_slot]["id"]

				if item_id == "medkit":
					use_medkit()
				elif item_id == "grenade":
					if get_viewport().gui_get_hovered_control() == null:
						throw_grenade()
				elif item_id == "shield":
					if get_viewport().gui_get_hovered_control() == null:
						throw_shield()
				elif item_id == "blue_potion" and mouse_pressed:
					use_shield_potion("blue_potion")
				elif item_id == "purple_potion" and mouse_pressed:
					use_shield_potion("purple_potion")

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
		if using_medkit:
			cancel_medkit_use()
		if using_potion:
			cancel_potion_use()

		if not is_weapon_reloading():
			dash()

	if shake_strength > 0:
		$Camera2D.offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
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
	if dead or amount <= 0:
		return

	var previous_purple = purple_health
	var previous_blue = shield_health
	var remaining_damage = amount

	var purple_damage = min(remaining_damage, purple_health)
	purple_health -= purple_damage
	remaining_damage -= purple_damage

	var blue_damage = min(remaining_damage, shield_health)
	shield_health -= blue_damage
	remaining_damage -= blue_damage

	var green_damage = min(remaining_damage, health)
	health -= green_damage

	var actual_damage = purple_damage + blue_damage + green_damage

	if actual_damage > 0:
		spawn_damage_number(actual_damage, false)

	if previous_purple > 0 and purple_health <= 0:
		damage_bar.value = get_display_health()
	elif previous_blue > 0 and shield_health <= 0:
		damage_bar.value = get_display_health()

	update_health_display()
	screen_shake(4.0)
	flash_red()

	if health <= 0:
		dead = true
		cancel_medkit_use()
		cancel_potion_use()
		if is_instance_valid(death_menu):
			death_menu.show_death_menu()

func heal(amount: float):
	if dead:
		return

	var actual_heal = min(amount, max_health - health)
	health = clamp(health + amount, 0, max_health)

	if actual_heal > 0:
		spawn_damage_number(actual_heal, true)

	update_health_display()

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
	var display_health = get_display_health()
	if damage_bar_suppressed:
		damage_bar.value = get_display_health()
		return
	if display_health < damage_bar.value:
		var tween = create_tween()
		tween.tween_interval(0.6)
		tween.tween_property(damage_bar, "value", display_health, 0.8)

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

	if using_medkit:
		cancel_medkit_use()
	if using_potion:
		cancel_potion_use()
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
	update_grenade_visual(item_id)
	update_shield_visual(item_id)
	var held_items = [held_ak, held_pistol, held_rpg, held_sniper, held_shotgun, held_medkit, held_blue_potion, held_purple_potion]

	for item in held_items:
		if is_instance_valid(item):
			item.visible = false
			item.set_process(true)

	speed = 520.0

	match item_id:
		"ak47":
			if not is_instance_valid(held_ak):
				if ak47_held_scene == null:
					return
				held_ak = ak47_held_scene.instantiate()
				add_child(held_ak)
			held_ak.visible = true

		"pistol":
			if not is_instance_valid(held_pistol):
				if pistol_held_scene == null:
					return
				held_pistol = pistol_held_scene.instantiate()
				add_child(held_pistol)
			held_pistol.visible = true

		"rpg":
			if not is_instance_valid(held_rpg):
				if rpg_held_scene == null:
					return
				held_rpg = rpg_held_scene.instantiate()
				add_child(held_rpg)
			held_rpg.visible = true

		"shotgun":
			if not is_instance_valid(held_shotgun):
				if shotgun_held_scene == null:
					return
				held_shotgun = shotgun_held_scene.instantiate()
				add_child(held_shotgun)
			held_shotgun.visible = true

		"sniper":
			if not is_instance_valid(held_sniper):
				if sniper_held_scene == null:
					return
				held_sniper = sniper_held_scene.instantiate()
				add_child(held_sniper)
			held_sniper.visible = true

		"medkit":
			if not is_instance_valid(held_medkit):
				if medkit_held_scene == null:
					return
				held_medkit = medkit_held_scene.instantiate()
				add_child(held_medkit)
			held_medkit.visible = true
		
		"blue_potion":
			if not is_instance_valid(held_blue_potion):
				if blue_potion_held_scene == null:
					return
				held_blue_potion = blue_potion_held_scene.instantiate()
				add_child(held_blue_potion)
			held_blue_potion.visible = true

		"purple_potion":
			if not is_instance_valid(held_purple_potion):
				if purple_potion_held_scene == null:
					return
				held_purple_potion = purple_potion_held_scene.instantiate()
				add_child(held_purple_potion)
			held_purple_potion.visible = true

func melee_attack():
	if melee_scene == null or not melee_ready:
		return

	melee_ready = false
	var swipe = melee_scene.instantiate()
	add_child(swipe)
	swipe.position = Vector2(0, -45)
	swipe.activate()
	await get_tree().create_timer(melee_cooldown).timeout
	melee_ready = true


func throw_grenade():
	if grenade_scene == null or not grenade_ready:
		return
	var hotbar = get_tree().root.find_child("HotbarUI", true, false)
	if not is_instance_valid(hotbar):
		return
	var selected_slot = hotbar.selected_slot
	if selected_slot < 1 or selected_slot > 5:
		return
	var slot = Manager.hotbar[selected_slot]
	if slot["id"] != "grenade" or slot["amount"] <= 0:
		return
	var direction = (get_global_mouse_position() - global_position).normalized()
	var grenade = grenade_scene.instantiate()
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = global_position + direction * 60.0
	grenade.launch(direction, get_global_mouse_position())
	grenade_ready = false
	slot["amount"] -= 1
	if slot["amount"] <= 0:
		Manager.hotbar[selected_slot] = {
			"id": "",
			"amount": 0,
			"max_stack": 0
		}

	Manager.hotbar_changed.emit()

	await get_tree().create_timer(grenade_throw_cooldown).timeout
	grenade_ready = true


func update_grenade_visual(item_id: String):
	if item_id != "grenade":
		if is_instance_valid(held_grenade):
			held_grenade.hide()
		return

	if grenade_visual_scene == null:
		return

	if not is_instance_valid(held_grenade):
		held_grenade = grenade_visual_scene.instantiate()
		add_child(held_grenade)

	held_grenade.position = Vector2(52, -48)
	held_grenade.rotation_degrees = 135
	held_grenade.show()

func update_shield_visual(item_id: String):
	if item_id != "shield":
		if is_instance_valid(held_shield):
			held_shield.hide()
		return

	if shield_visual_scene == null:
		return

	if not is_instance_valid(held_shield):
		held_shield = shield_visual_scene.instantiate()
		add_child(held_shield)

	held_shield.position = Vector2(52, -48)
	held_shield.rotation_degrees = 135
	held_shield.show()

func use_medkit():
	if using_medkit or dead or is_stunned or health >= max_health:
		return

	var hotbar = get_tree().root.find_child("HotbarUI", true, false)

	if not is_instance_valid(hotbar):
		return

	var selected_slot = hotbar.selected_slot

	if selected_slot < 0 or selected_slot >= Manager.hotbar.size():
		return

	var slot = Manager.hotbar[selected_slot]

	if slot["id"] != "medkit" or slot["amount"] <= 0:
		return

	if not is_instance_valid(held_medkit):
		if medkit_held_scene == null:
			return

		held_medkit = medkit_held_scene.instantiate()
		add_child(held_medkit)

	held_medkit.visible = true
	held_medkit.set_process(true)
	held_medkit.using_medkit = true

	using_medkit = true
	medkit_timer = medkit_use_time
	medkit_slot = selected_slot

func finish_medkit_use():
	if not using_medkit:
		return

	if medkit_slot < 0 or medkit_slot >= Manager.hotbar.size():
		cancel_medkit_use()
		return

	var slot = Manager.hotbar[medkit_slot]

	if slot["id"] != "medkit" or slot["amount"] <= 0:
		cancel_medkit_use()
		return

	var completed_slot = medkit_slot

	using_medkit = false
	medkit_timer = 0.0
	medkit_slot = -1

	if is_instance_valid(held_medkit):
		held_medkit.stop_indicator(true)
		held_medkit.using_medkit = false
	slot["amount"] -= 1

	if slot["amount"] <= 0:
		Manager.hotbar[completed_slot] = {
			"id": "",
			"amount": 0,
			"max_stack": 0
		}

	heal(max_health)
	Manager.hotbar_changed.emit()

func cancel_medkit_use():
	if not using_medkit:
		return
	using_medkit = false
	medkit_timer = 0.0
	medkit_slot = -1

	if is_instance_valid(held_medkit):
		held_medkit.stop_indicator()
		held_medkit.using_medkit = false

func throw_shield():
	if shield_scene == null or not shield_ready:
		return

	var hotbar = get_tree().root.find_child("HotbarUI", true, false)
	if not is_instance_valid(hotbar):
		return

	var selected_slot = hotbar.selected_slot
	if selected_slot < 1 or selected_slot > 5:
		return

	var slot = Manager.hotbar[selected_slot]
	if slot["id"] != "shield" or slot["amount"] <= 0:
		return

	var direction = (get_global_mouse_position() - global_position).normalized()
	var shield = shield_scene.instantiate()
	get_tree().current_scene.add_child(shield)
	shield.global_position = global_position + direction * 60.0
	shield.launch(direction, get_global_mouse_position())

	shield_ready = false
	slot["amount"] -= 1

	if slot["amount"] <= 0:
		Manager.hotbar[selected_slot] = {
			"id": "",
			"amount": 0,
			"max_stack": 0
		}

	Manager.hotbar_changed.emit()

	await get_tree().create_timer(shield_throw_cooldown).timeout
	shield_ready = true


func use_shield_potion(potion_id: String):
	if dead or is_stunned or using_medkit or using_potion:
		return

	if health < max_health:
		return

	var hotbar = get_tree().root.find_child("HotbarUI", true, false)
	if not is_instance_valid(hotbar):
		return

	var selected_slot = hotbar.selected_slot
	if selected_slot < 1 or selected_slot > 5:
		return

	var slot = Manager.hotbar[selected_slot]

	if slot["id"] != potion_id or slot["amount"] <= 0:
		return

	var potion_scene: PackedScene

	if potion_id == "blue_potion":
		if shield_health >= max_shield_health:
			return
		potion_scene = blue_potion_held_scene

	elif potion_id == "purple_potion":
		if shield_health >= max_shield_health and purple_health >= max_purple_health:
			return
		potion_scene = purple_potion_held_scene
	else:
		return

	if potion_scene == null:
		return

	if not is_instance_valid(held_potion) or held_potion_id != potion_id:
		if is_instance_valid(held_potion):
			held_potion.queue_free()

	if potion_id == "blue_potion":
		held_potion = held_blue_potion
	else:
		held_potion = held_purple_potion

	if not is_instance_valid(held_potion):
		return

	held_potion_id = potion_id

	held_potion.visible = true
	held_potion.set_process(true)
	held_potion.start_use()

	using_potion = true
	potion_timer = potion_use_time
	potion_slot = selected_slot
	self.potion_id = potion_id


func finish_potion_use():
	if not using_potion:
		return

	if potion_slot < 1 or potion_slot > 5:
		cancel_potion_use()
		return

	var slot = Manager.hotbar[potion_slot]

	if slot["id"] != potion_id or slot["amount"] <= 0:
		cancel_potion_use()
		return

	var completed_slot = potion_slot
	var completed_potion_id = potion_id

	using_potion = false
	potion_timer = 0.0
	potion_slot = -1
	potion_id = ""

	if is_instance_valid(held_potion):
		held_potion.stop_indicator(true)
		held_potion.is_using = false
		held_potion.hide()

	if completed_potion_id == "blue_potion":
		shield_health = min(shield_health + 25, max_shield_health)
	elif completed_potion_id == "purple_potion":
		if shield_health < max_shield_health:
			shield_health = min(shield_health + 25, max_shield_health)
		else:
			purple_health = min(purple_health + 25, max_purple_health)

	slot["amount"] -= 1

	if slot["amount"] <= 0:
		Manager.hotbar[completed_slot] = {
			"id": "",
			"amount": 0,
			"max_stack": 0
		}

	Manager.hotbar_changed.emit()
	suppress_damage_bar()
	update_health_display()


func cancel_potion_use():
	if not using_potion:
		return

	var cancelled_id = potion_id
	using_potion = false
	potion_timer = 0.0
	potion_slot = -1
	potion_id = ""

	if is_instance_valid(held_potion):
		held_potion.stop_indicator()
		held_potion.is_using = false

		var hotbar = get_tree().root.find_child("HotbarUI", true, false)
		held_potion.visible = is_instance_valid(hotbar) and hotbar.selected_slot >= 1 and hotbar.selected_slot <= 5 and Manager.hotbar[hotbar.selected_slot]["id"] == cancelled_id


func get_display_health() -> float:
	if purple_health > 0:
		return purple_health
	if shield_health > 0:
		return shield_health
	return health

func update_health_display():
	var damage_style = StyleBoxFlat.new()
	damage_style.bg_color = Color("#5c0513")
	damage_style.corner_radius_top_left = 6
	damage_style.corner_radius_top_right = 6
	damage_style.corner_radius_bottom_left = 6
	damage_style.corner_radius_bottom_right = 6
	damage_bar.add_theme_stylebox_override("fill", damage_style)
	var display_health = get_display_health()
	health_bar.max_value = max_health
	health_bar.set_health(display_health)
	health_bar.set_layer_health(health, shield_health, purple_health)
	var transparent_bg = StyleBoxFlat.new()
	transparent_bg.bg_color = Color(0, 0, 0, 0)
	health_bar.add_theme_stylebox_override("background", transparent_bg)
	health_bar.set_flashing_health(health)

	var fill_style = StyleBoxFlat.new()

	if purple_health > 0:
		fill_style.bg_color = Color("#A855F7")
	elif shield_health > 0:
		fill_style.bg_color = Color("#38BDF8")
	else:
		fill_style.bg_color = Color("#10a01c")

	health_bar.set_health_color(fill_style.bg_color)
	update_damage_bar()

func suppress_damage_bar():
	damage_bar_suppressed = true
	damage_bar.value = get_display_health()

	await get_tree().create_timer(1.0).timeout

	damage_bar.value = get_display_health()
	damage_bar_suppressed = false
