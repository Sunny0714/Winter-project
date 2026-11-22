extends Node2D

@export var bullet_scene: PackedScene
@export var reload_indicator_scene: PackedScene
@export var fire_rate: float = 0.12
@export var magazine_size: int = 30
@export var reserve_ammo: int = 120
@export var reload_time: float = 1.5

@onready var muzzle = $Muzzle

var was_visible := false
var wait_for_mouse_release := false
var reload_indicator
var ammo := 30
var fire_cooldown := 0.0
var is_reloading := false
var is_firing := false
var player
var mouse_press_blocked := false


func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	player = get_parent()

	if reload_indicator_scene:
		reload_indicator = reload_indicator_scene.instantiate()
		player.get_node("CanvasLayer").add_child(reload_indicator)

	for i in range(1, Manager.hotbar.size()):
		if Manager.hotbar[i]["id"] == "ak47":
			load_ammo(Manager.hotbar[i])
			break

	update_ammo_label()


func is_mouse_over_ui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	var hovered = get_viewport().gui_get_hovered_control()

	if hovered != null:
		return true

	var controls = get_tree().get_nodes_in_group("inventory_ui")

	for control in controls:
		if control is Control and control.visible and control.get_global_rect().has_point(mouse_pos):
			return true

	var hotbar = get_tree().root.find_child("HotbarUI", true, false)

	if is_instance_valid(hotbar) and hotbar.visible:
		var slots = hotbar.get_node_or_null("Slots")

		if slots:
			for slot in slots.get_children():
				if slot is Control and slot.visible and slot.get_global_rect().has_point(mouse_pos):
					return true

	return false


func _process(delta):
	if wait_for_mouse_release:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_firing = false
			return

		wait_for_mouse_release = false

	if get_tree().paused:
		is_firing = false
		mouse_press_blocked = false
		return

	# Detect when the AK becomes active.
	if visible and not was_visible:
		fire_cooldown = 0.05
		was_visible = true
	elif not visible:
		was_visible = false

	if not is_instance_valid(player) or not visible:
		return

	look_at(get_global_mouse_position())
	rotation += PI / 2

	fire_cooldown = maxf(fire_cooldown - delta, 0.0)

	if Input.is_action_just_pressed("reload"):
		reload_weapon()

	var hotbar = get_tree().root.find_child("HotbarUI", true, false)
	var inventory_dragging = is_instance_valid(hotbar) and hotbar.inventory_dragging

	is_firing = (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and not inventory_dragging
		and not mouse_press_blocked
		and not is_mouse_over_ui()
		and not Input.is_action_pressed("ui_cancel")
	)

	if inventory_dragging:
		is_firing = false
		player.speed = 500.0
		return

	player.speed = 490.0 if is_firing else 500.0

	if is_firing and fire_cooldown <= 0.0 and not is_reloading:
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

	if not is_instance_valid(reload_indicator):
		if reload_indicator_scene != null:
			reload_indicator = reload_indicator_scene.instantiate()
			get_parent().get_node("CanvasLayer").add_child(reload_indicator)

	if is_instance_valid(reload_indicator):
		reload_indicator.visible = true
		reload_indicator.start_reload(reload_time)

	var elapsed := 0.0

	while elapsed < reload_time:
		await get_tree().process_frame

		if not is_inside_tree():
			is_reloading = false
			return

		if not visible:
			is_reloading = false

			if is_instance_valid(reload_indicator):
				reload_indicator.queue_free()
				reload_indicator = null

			update_ammo_label()
			return

		elapsed = minf(elapsed + get_process_delta_time(), reload_time)

		if is_instance_valid(reload_indicator):
			reload_indicator.update_progress(reload_time - elapsed)

	var needed = magazine_size - ammo
	var loaded = mini(needed, reserve_ammo)

	ammo += loaded
	reserve_ammo -= loaded
	is_reloading = false

	if is_instance_valid(reload_indicator):
		reload_indicator.update_progress(0.0)
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
	reserve_ammo = int(data.get("reserve", 120))
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
