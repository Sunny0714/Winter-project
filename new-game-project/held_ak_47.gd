
extends Node2D

@export var bullet_scene: PackedScene
@export var reload_indicator_scene: PackedScene
@export var fire_rate: float = 0.12
@export var magazine_size: int = 30
@export var reserve_ammo: int = 90
@export var reload_time: float = 1.5

@onready var muzzle = $Muzzle

var reload_indicator
var ammo := 30
var fire_cooldown := 0.0
var is_reloading := false
var is_firing := false
var player
var mouse_press_blocked := false

func _ready():
	player = get_parent()

	if reload_indicator_scene:
		reload_indicator = reload_indicator_scene.instantiate()
		player.get_node("CanvasLayer").add_child(reload_indicator)

	for i in range(1, Manager.hotbar.size()):
		if Manager.hotbar[i]["id"] == "ak47":
			load_ammo(Manager.hotbar[i])
			break

	update_ammo_label()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_press_blocked = is_mouse_over_ui()
			else:
				mouse_press_blocked = false

func is_mouse_over_ui() -> bool:
	var hotbar = get_tree().root.find_child("HotbarUI", true, false)
	if is_instance_valid(hotbar) and hotbar.visible:
		if hotbar.get_global_rect().has_point(get_global_mouse_position()):
			return true

	var hovered = get_viewport().gui_get_hovered_control()
	return hovered != null

func _process(delta):
	if not is_instance_valid(player) or not visible:
		return

	look_at(get_global_mouse_position())
	rotation += PI / 2
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)

	if Input.is_action_just_pressed("reload"):
		reload_weapon()

	is_firing = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not mouse_press_blocked and not is_mouse_over_ui()
	player.speed = 490.0 if is_firing else 500.0

	if is_firing and fire_cooldown <= 0 and not is_reloading:
		if ammo > 0:
			shoot()
		else:
			reload_weapon()

func shoot():
	if bullet_scene == null or not is_instance_valid(muzzle):
		return

	ammo -= 1
	fire_cooldown = fire_rate

	var direction = (get_global_mouse_position() - player.global_position).normalized()
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = Transform2D(direction.angle() + PI / 2, muzzle.global_position)
	bullet.setup(direction)

	update_inventory_ammo()
	player.screen_shake(2.0)
	update_ammo_label()

	if ammo <= 0:
		reload_weapon()

func reload_weapon():
	if is_reloading or ammo >= magazine_size or reserve_ammo <= 0:
		return

	is_reloading = true
	update_ammo_label()

	if is_instance_valid(reload_indicator):
		reload_indicator.start_reload()

	var elapsed := 0.0

	while elapsed < reload_time:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		elapsed += get_process_delta_time()

		if is_instance_valid(reload_indicator):
			reload_indicator.update_progress(elapsed / reload_time)

	var needed = magazine_size - ammo
	var loaded = mini(needed, reserve_ammo)
	ammo += loaded
	reserve_ammo -= loaded
	is_reloading = false

	if is_instance_valid(reload_indicator):
		reload_indicator.finish_reload()

	update_inventory_ammo()
	update_ammo_label()

func update_ammo_label():
	if not is_instance_valid(player):
		return

	var label = player.get_node_or_null("CanvasLayer/AmmoLabel")
	if label:
		label.text = "RELOADING" if is_reloading else str(ammo) + "/" + str(reserve_ammo)

func save_ammo():
	return {"amount": ammo, "reserve": reserve_ammo}

func load_ammo(data: Dictionary):
	ammo = int(data.get("amount", magazine_size))
	reserve_ammo = int(data.get("reserve", 90))
	update_ammo_label()

func _exit_tree():
	if is_instance_valid(player):
		player.speed = 520.0
	if is_instance_valid(reload_indicator):
		reload_indicator.queue_free()

func update_inventory_ammo():
	for i in range(1, Manager.hotbar.size()):
		if Manager.hotbar[i]["id"] == "ak47":
			Manager.hotbar[i]["amount"] = ammo
			Manager.hotbar[i]["reserve"] = reserve_ammo
			var hotbar = get_tree().root.find_child("HotbarUI", true, false)
			if is_instance_valid(hotbar):
				hotbar.update_hotbar()
			return
