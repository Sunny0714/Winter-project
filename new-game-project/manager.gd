extends Node

signal hotbar_changed

var vision: bool = false
var inventory: String = "none"
var hotbar: Array[Dictionary] = [
	{"id": "melee", "amount": 1, "max_stack": 1},
	{"id": "", "amount": 0, "max_stack": 0},
	{"id": "", "amount": 0, "max_stack": 0},
	{"id": "", "amount": 0, "max_stack": 0},
	{"id": "", "amount": 0, "max_stack": 0},
	{"id": "", "amount": 0, "max_stack": 0}]
var last_pickup_frame := -1

func claim_pickup_press() -> bool:
	var current_frame = Engine.get_process_frames()
	if last_pickup_frame == current_frame:
		return false
	last_pickup_frame = current_frame
	return true

func add_item(item_id: String, amount: int, max_stack: int = 99, data: Dictionary = {}):
	if item_id == "" or amount <= 0:
		return amount

	var hotbar_ui = get_tree().root.find_child("HotbarUI", true, false)
	var auto_equip = is_instance_valid(hotbar_ui) and hotbar_ui.selected_slot == 0
	var added_slot := -1

	if item_id == "grenade":
		max_stack = 6
	elif item_id == "shield":
		max_stack = 6
	elif item_id == "medkit":
		max_stack = 2
	elif item_id == "blue_potion":
		max_stack = 4
	elif item_id == "purple_potion":
		max_stack = 2

	if item_id in ["ak47", "sniper", "rpg", "shotgun", "pistol"]:
		var default_reserve = 120

		match item_id:
			"sniper":
				default_reserve = 15
			"rpg":
				default_reserve = 3
			"shotgun":
				default_reserve = 12

		for i in range(1, 6):
			if hotbar[i]["id"] == "":
				hotbar[i] = {
					"id": item_id,
					"amount": int(data.get("amount", amount)),
					"reserve": int(data.get("reserve", default_reserve)),
					"max_stack": 1
				}
				added_slot = i
				amount = 0
				break
	else:
		var original_amount = amount

		for i in range(1, 6):
			if hotbar[i]["id"] == item_id and hotbar[i]["amount"] < max_stack:
				var space = max_stack - hotbar[i]["amount"]
				var added = min(amount, space)
				hotbar[i]["amount"] += added
				amount -= added

				if added > 0 and added_slot == -1:
					added_slot = i

				if amount <= 0:
					break

		if amount > 0:
			for i in range(1, 6):
				if hotbar[i]["id"] == "":
					var added = min(amount, max_stack)
					hotbar[i] = {
						"id": item_id,
						"amount": added,
						"max_stack": max_stack
					}
					amount -= added

					if added > 0 and added_slot == -1:
						added_slot = i

					if amount <= 0:
						break

	if amount != (0 if item_id in ["ak47", "sniper", "rpg", "shotgun", "pistol"] and added_slot != -1 else amount) or added_slot != -1:
		hotbar_changed.emit()

		if auto_equip and added_slot != -1:
			hotbar_ui.select_slot(added_slot)

	return amount

func remove_item(slot_index: int):
	if slot_index < 1 or slot_index > 5:
		return {}

	var item = hotbar[slot_index].duplicate(true)
	hotbar[slot_index] = {"id": "", "amount": 0, "max_stack": 0}
	hotbar_changed.emit()
	return item

func swap_items(from_slot: int, to_slot: int):
	if from_slot < 1 or from_slot > 5:
		return
	if to_slot < 1 or to_slot > 5:
		return
	if from_slot == to_slot:
		return

	var temp = hotbar[from_slot]
	hotbar[from_slot] = hotbar[to_slot]
	hotbar[to_slot] = temp
	hotbar_changed.emit()

func reset_inventory():
	hotbar = [
		{"id": "melee", "amount": 1, "max_stack": 1},
		{"id": "", "amount": 0, "max_stack": 0},
		{"id": "", "amount": 0, "max_stack": 0},
		{"id": "", "amount": 0, "max_stack": 0},
		{"id": "", "amount": 0, "max_stack": 0},
		{"id": "", "amount": 0, "max_stack": 0}
	]
	inventory = "none"
	hotbar_changed.emit()
