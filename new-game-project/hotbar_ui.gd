extends Control

@export var ak47_drop_scene: PackedScene
@export var pistol_drop_scene: PackedScene
@export var grenade_drop_scene: PackedScene

@onready var slots = $Slots

var selected_slot := 0
var inventory_dragging := false

func _ready():
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

		if item["id"] == "":
			button.text = ""
		elif item["id"] == "ak47":
			var player = get_tree().root.find_child("Player", true, false)
			if is_instance_valid(player) and is_instance_valid(player.held_ak):
				button.text = "ak47\n" + str(player.held_ak.ammo) + "/" + str(player.held_ak.reserve_ammo)
			else:
				button.text = "ak47\n" + str(item["amount"]) + "/" + str(item.get("reserve", 120))
		elif item["id"] == "pistol":
			var player = get_tree().root.find_child("Player", true, false)
			if is_instance_valid(player) and is_instance_valid(player.held_pistol):
				button.text = "pistol\n" + str(player.held_pistol.ammo) + "/" + str(player.held_pistol.reserve_ammo)
			else:
				button.text = "pistol\n" + str(item["amount"]) + "/" + str(item.get("reserve", 120))
		elif item["id"] == "rpg":
			var player = get_tree().root.find_child("Player", true, false)
			if is_instance_valid(player) and is_instance_valid(player.held_rpg):
				button.text = "rgp\n" + str(player.held_rpg.ammo) + "/" + str(player.held_rpg.reserve_ammo)
			else:
				button.text = "rpg\n" + str(item["amount"]) + "/" + str(item.get("reserve", 3))
		elif item["id"] == "sniper":
			var player = get_tree().root.find_child("Player", true, false)
			if is_instance_valid(player) and is_instance_valid(player.held_sniper):
				button.text = "sniper\n" + str(player.held_sniper.ammo) + "/" + str(player.held_sniper.reserve_ammo)
			else:
				button.text = "sniper\n" + str(item["amount"]) + "/" + str(item.get("reserve", 15))
		elif item["id"] == "shotgun":
			var player = get_tree().root.find_child("Player", true, false)
			if is_instance_valid(player) and is_instance_valid(player.held_shotgun):
				button.text = "shotgun\n" + str(player.held_shotgun.ammo) + "/" + str(player.held_shotgun.reserve_ammo)
			else:
				button.text = "shotgun\n" + str(item["amount"]) + "/" + str(item.get("reserve", 12))
		elif item["id"] == "medkit":
			button.text = "med\n" + str(item["amount"])
		elif item["id"] == "grenade":
			button.text = "nade\n" + str(item["amount"])

		else:
			button.text = item["id"]

	select_slot(selected_slot)

func drop_item_from_slot(slot_index: int):
	if slot_index < 1 or slot_index > 5:
		return
	var item_id = Manager.hotbar[slot_index]["id"]
	var drop_scene: PackedScene
	if item_id == "ak47":
		drop_scene = ak47_drop_scene
	elif item_id == "pistol":
		drop_scene = pistol_drop_scene
	elif item_id == "grenade":
		drop_scene = grenade_drop_scene
	else:
		return
	if drop_scene == null:
		return
	var player = get_tree().root.find_child("Player", true, false)
	if not is_instance_valid(player):
		return
	var item = Manager.remove_item(slot_index)
	var drop = drop_scene.instantiate()
	get_tree().current_scene.add_child(drop)
	drop.global_position = player.global_position + Vector2(40, 0)
	if item_id == "ak47" or item_id == "pistol":
		drop.set("weapon_data", item)
	elif item_id == "grenade":
		drop.set("grenade_amount", item["amount"])

func set_inventory_dragging(state: bool):
	inventory_dragging = state

func is_mouse_over_hotbar():
	return get_global_rect().has_point(get_global_mouse_position())
