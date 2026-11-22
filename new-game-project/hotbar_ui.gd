extends Control

@export var blue_potion_drop_scene: PackedScene
@export var purple_potion_drop_scene: PackedScene
@export var ak47_drop_scene: PackedScene
@export var pistol_drop_scene: PackedScene
@export var grenade_drop_scene: PackedScene
@export var shield_drop_scene: PackedScene
@export var medkit_drop_scene: PackedScene
@export var shotgun_drop_scene: PackedScene
@export var sniper_drop_scene: PackedScene
@export var rpg_drop_scene: PackedScene

@export var blue_potion_icon: Texture2D
@export var purple_potion_icon: Texture2D
@export var ak47_icon: Texture2D
@export var pistol_icon: Texture2D
@export var rpg_icon: Texture2D
@export var sniper_icon: Texture2D
@export var shotgun_icon: Texture2D
@export var medkit_icon: Texture2D
@export var grenade_icon: Texture2D
@export var shield_icon: Texture2D

@onready var slots = $Slots

var selected_slot := 0
var inventory_dragging := false

func _ready():
	setup_slot_ui()

	for i in range(slots.get_child_count()):
		var button = slots.get_child(i)
		button.slot_index = i

	Manager.hotbar_changed.connect(update_hotbar)

	update_hotbar()
	select_slot(0)

func _process(_delta):
	if get_tree().paused:
		return

	for i in range(slots.get_child_count()):
		if Input.is_action_just_pressed("slot_" + str(i + 1)):
			select_slot(i)

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_slot((selected_slot - 1 + slots.get_child_count()) % slots.get_child_count())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_slot((selected_slot + 1) % slots.get_child_count())

func select_slot(index: int):
	if index < 0 or index >= slots.get_child_count():
		return

	if index != selected_slot:
		var player = get_tree().root.find_child("Player", true, false)
		if is_instance_valid(player) and player.using_medkit:
			player.cancel_medkit_use()

	selected_slot = index

	for button in slots.get_children():
		button.update_outline()

	var player = get_tree().root.find_child("Player", true, false)
	if is_instance_valid(player):
		player.equip_hotbar_item(Manager.hotbar[index]["id"])

func update_hotbar():
	for i in range(min(6, slots.get_child_count())):
		var button = slots.get_child(i)
		var item = Manager.hotbar[i]

		var image = button.get_node("WeaponImage")
		var ammo_label = button.get_node("AmmoLabel")

		var icon: Texture2D = null
		var ammo_text = ""

		match item["id"]:
			"ak47":
				icon = ak47_icon
				image.position = Vector2(7, 4)
				image.rotation_degrees = -35
				image.scale = Vector2(1.45, 1.45)
				ammo_text = str(item["amount"]) + "/" + str(item.get("reserve", 120))

			"pistol":
				icon = pistol_icon
				image.position = Vector2(7, 5.5)
				image.rotation_degrees = -20
				image.scale = Vector2(1, 1)
				ammo_text = str(item["amount"]) + "/" + str(item.get("reserve", 120))

			"rpg":
				icon = rpg_icon
				image.position = Vector2(0, 0)
				image.rotation_degrees = 0
				image.scale = Vector2(1, 1)
				ammo_text = str(item["amount"]) + "/" + str(item.get("reserve", 3))

			"sniper":
				icon = sniper_icon
				image.position = Vector2(0, 0)
				image.rotation_degrees = 0
				image.scale = Vector2(1, 1)
				ammo_text = str(item["amount"]) + "/" + str(item.get("reserve", 15))

			"shotgun":
				icon = shotgun_icon
				image.position = Vector2(7, 5)
				image.rotation_degrees = -33.1
				image.scale = Vector2(1.4, 1.4)
				ammo_text = str(item["amount"]) + "/" + str(item.get("reserve", 12))

			"medkit":
				icon = medkit_icon
				image.position = Vector2(6, 5)
				image.rotation_degrees = 0
				image.scale = Vector2(1.1, 0.9)
				ammo_text = str(item["amount"])

			"grenade":
				icon = grenade_icon
				image.position = Vector2(7.5, 5)
				image.rotation_degrees = 35
				image.scale = Vector2(0.7, 0.7)
				ammo_text = str(item["amount"])

			"shield":
				icon = shield_icon
				image.position = Vector2(7.5, 5)
				image.rotation_degrees = 35
				image.scale = Vector2(0.7, 0.7)
				ammo_text = str(item["amount"])

			"blue_potion":
				icon = blue_potion_icon
				image.position = Vector2(7.5, 5)
				image.rotation_degrees = 0
				image.scale = Vector2(0.1, 0.35)
				ammo_text = str(item["amount"])

			"purple_potion":
				icon = purple_potion_icon
				image.position = Vector2(0.2, 0.35)
				image.rotation_degrees = 0
				image.scale = Vector2(0.2, 0.35)
				ammo_text = str(item["amount"])

		image.texture = icon
		image.visible = icon != null

		ammo_label.text = ammo_text
		ammo_label.visible = item["id"] != ""

	select_slot(selected_slot)

func drop_item_from_slot(slot_index: int):
	if slot_index < 1 or slot_index > 5:
		return

	var item = Manager.hotbar[slot_index]
	var item_id = item["id"]

	if item_id == "":
		return

	var drop_scene: PackedScene

	match item_id:
		"ak47":
			drop_scene = ak47_drop_scene
		"pistol":
			drop_scene = pistol_drop_scene
		"grenade":
			drop_scene = grenade_drop_scene
		"shield":
			drop_scene = shield_drop_scene
		"medkit":
			drop_scene = medkit_drop_scene
		"shotgun":
			drop_scene = shotgun_drop_scene
		"sniper":
			drop_scene = sniper_drop_scene
		"rpg":
			drop_scene = rpg_drop_scene
		"blue_potion":
			drop_scene = blue_potion_drop_scene
		"purple_potion":
			drop_scene = purple_potion_drop_scene
		_:
			return

	if drop_scene == null:
		return

	var player = get_tree().root.find_child("Player", true, false)

	if not is_instance_valid(player):
		return

	var drop = drop_scene.instantiate()
	var removed_item = Manager.remove_item(slot_index)

	if removed_item.is_empty():
		drop.free()
		return

	get_tree().current_scene.add_child(drop)
	drop.global_position = player.global_position + Vector2(40, 0)

	match item_id:
		"ak47", "pistol":
			drop.set("weapon_data", removed_item)
		"grenade":
			drop.set("grenade_amount", removed_item["amount"])
		"shield":
			drop.set("shield_amount", removed_item["amount"])
		"medkit":
			drop.set("medkit_amount", removed_item["amount"])
		"blue_potion":
			drop.set("item_amount", removed_item["amount"])
		"purple_potion":
			drop.set("item_amount", removed_item["amount"])

func consume_medkit(slot_index: int) -> bool:
	if slot_index < 1 or slot_index > 5:
		return false

	var slot = Manager.hotbar[slot_index]

	if slot["id"] != "medkit" or slot["amount"] <= 0:
		return false

	slot["amount"] -= 1

	if slot["amount"] <= 0:
		Manager.hotbar[slot_index] = {
			"id": "",
			"amount": 0,
			"max_stack": 0
		}

	Manager.hotbar_changed.emit()
	return true

func setup_slot_ui():
	for button in slots.get_children():
		var image = TextureRect.new()
		image.name = "WeaponImage"
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		image.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		image.size = Vector2(48, 48)
		image.pivot_offset = image.size / 2

		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)

		var ammo_label = Label.new()
		ammo_label.name = "AmmoLabel"

		ammo_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

		ammo_label.add_theme_font_size_override("font_size", 10)

		ammo_label.offset_left = 2
		ammo_label.offset_right = -4
		ammo_label.offset_top = 2
		ammo_label.offset_bottom = -2

		ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(ammo_label)
