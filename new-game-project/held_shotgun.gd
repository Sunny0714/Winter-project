extends Node2D

@export var bullet_scene: PackedScene
@export var reload_indicator_scene: PackedScene
@export var fire_rate: float = 0.8
@export var magazine_size: int = 4
@export var reserve_ammo: int = 48
@export var reload_time: float = 0.6
@export var bullet_count: int = 16
@export var spread_angle: float = 35.0

@onready var muzzle = $Muzzle

var was_visible := false
var reload_indicator
var ammo := 4
var fire_cooldown := 0.0
var is_reloading := false
var is_firing := false
var player
var reload_id := 0
var next_shot_id := 0
var shot_fired_after_switch := false


func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	player = get_parent()
	magazine_size = 4

	for i in range(1, Manager.hotbar.size()):
		if Manager.hotbar[i]["id"] == "shotgun":
			load_ammo(Manager.hotbar[i])
			break

	ammo = clampi(ammo, 0, magazine_size)
	update_inventory_ammo()
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
	# Reset the shot lock when the mouse is released.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		shot_fired_after_switch = false

	if get_tree().paused:
		is_firing = false
		return

	# Detect when the shotgun becomes active.
	if visible and not was_visible:
		fire_cooldown = 0.05
		was_visible = true
		shot_fired_after_switch = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	elif not visible:
		was_visible = false

	if not is_instance_valid(player):
		return

	if not visible:
		if is_reloading:
			cancel_reload()
		return

	look_at(get_global_mouse_position())
	rotation += PI / 2

	# Decrease cooldown before checking whether we can shoot.
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)

	var hotbar = get_tree().root.find_child("HotbarUI", true, false)
	var inventory_dragging = is_instance_valid(hotbar) and hotbar.inventory_dragging

	is_firing = (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not inventory_dragging and not is_mouse_over_ui() and not Input.is_action_pressed("ui_cancel") and not shot_fired_after_switch)

	if inventory_dragging:
		is_firing = false
		player.speed = 500.0
		return

	player.speed = 490.0 if is_firing else 500.0

	if is_reloading:
		if is_firing and ammo > 0 and fire_cooldown <= 0.0:
			cancel_reload()
			shoot()
		return

	if Input.is_action_just_pressed("reload"):
		reload_weapon()
		return

	if is_firing and fire_cooldown <= 0.0 and ammo > 0:
		shoot()


func shoot():
	if bullet_scene == null or not is_instance_valid(muzzle) or ammo <= 0 or is_reloading:
		return

	ammo -= 1

	# Normal cooldown applies after every shot.
	fire_cooldown = fire_rate

	next_shot_id += 1
	var current_shot_id = next_shot_id

	var aim_direction = (get_global_mouse_position() - player.global_position).normalized()
	var muzzle_direction = (muzzle.global_position - player.global_position).normalized()

	if aim_direction.dot(muzzle_direction) < 0.0:
		aim_direction = muzzle_direction

	var base_direction = aim_direction
	var total_spread = deg_to_rad(spread_angle)

	for i in range(bullet_count):
		var progress = float(i) / float(bullet_count - 1)
		var angle = lerpf(-total_spread / 2.0, total_spread / 2.0, progress)
		var direction = base_direction.rotated(angle)

		var bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_transform = Transform2D(direction.angle() + PI / 2, muzzle.global_position)
		bullet.setup(direction, current_shot_id)

	update_inventory_ammo()
	player.screen_shake(5.0)
	update_ammo_label()

	if ammo <= 0:
		reload_weapon()


func reload_weapon():
	if is_reloading or ammo >= magazine_size or reserve_ammo <= 0:
		return

	reload_id += 1
	var current_reload_id = reload_id

	is_reloading = true
	update_ammo_label()

	if not is_instance_valid(reload_indicator) and reload_indicator_scene != null:
		reload_indicator = reload_indicator_scene.instantiate()
		get_parent().get_node("CanvasLayer").add_child(reload_indicator)

	while ammo < magazine_size and reserve_ammo > 0:
		if current_reload_id != reload_id or not is_reloading:
			return

		if not visible:
			cancel_reload()
			return

		if is_instance_valid(reload_indicator):
			reload_indicator.visible = true
			reload_indicator.start_reload(reload_time)

		var elapsed := 0.0

		while elapsed < reload_time:
			await get_tree().process_frame

			if current_reload_id != reload_id or not is_reloading:
				return

			if not is_inside_tree():
				return

			if not visible:
				cancel_reload()
				return

			elapsed = minf(elapsed + get_process_delta_time(), reload_time)

			if is_instance_valid(reload_indicator):
				reload_indicator.update_progress(reload_time - elapsed)

		if current_reload_id != reload_id or not is_reloading:
			return

		ammo += 1
		reserve_ammo -= 1
		update_inventory_ammo()
		update_ammo_label()

	is_reloading = false

	if is_instance_valid(reload_indicator):
		reload_indicator.update_progress(0.0)
		reload_indicator.finish_reload()

	update_inventory_ammo()
	update_ammo_label()


func cancel_reload():
	if not is_reloading:
		return

	reload_id += 1
	is_reloading = false

	if is_instance_valid(reload_indicator):
		reload_indicator.queue_free()
		reload_indicator = null

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
	ammo = clampi(int(data.get("amount", 4)), 0, magazine_size)
	reserve_ammo = int(data.get("reserve", 48))
	update_ammo_label()


func _exit_tree():
	if is_reloading:
		cancel_reload()

	if is_instance_valid(player):
		player.speed = 520.0

	if is_instance_valid(reload_indicator):
		reload_indicator.queue_free()
		reload_indicator = null


func update_inventory_ammo():
	for i in range(1, Manager.hotbar.size()):
		if Manager.hotbar[i]["id"] == "shotgun":
			Manager.hotbar[i]["amount"] = ammo
			Manager.hotbar[i]["reserve"] = reserve_ammo

			var hotbar = get_tree().root.find_child("HotbarUI", true, false)

			if is_instance_valid(hotbar):
				hotbar.update_hotbar()

			return
