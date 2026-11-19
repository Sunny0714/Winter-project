extends Node

signal hotbar_changed

var vision: = false
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
	if item_id == "grenade":
		max_stack = 6
	if item_id == "medkit":
		max_stack = 2
	if item_id in ["ak47", "sniper", "rpg", "shotgun", "pistol"]:
		var default_reserve = 120
		match item_id:
			"ak47":
				default_reserve = 120
			"sniper":
				default_reserve = 15
			"rpg":
				default_reserve = 3
			"shotgun":
				default_reserve = 12
			"pistol":
				default_reserve = 120

		for i in range(1, 6):
			if hotbar[i]["id"] == "":
				hotbar[i] = {
					"id": item_id,
					"amount": int(data.get("amount", amount)),
					"reserve": int(data.get("reserve", default_reserve)),
					"max_stack": 1
				}
				hotbar_changed.emit()
				return 0

		return amount

	var original_amount = amount

	for i in range(1, 6):
		if hotbar[i]["id"] == item_id and hotbar[i]["amount"] < max_stack:
			var space = max_stack - hotbar[i]["amount"]
			var added = min(amount, space)
			hotbar[i]["amount"] += added
			amount -= added
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
				if amount <= 0:
					break
	if amount != original_amount:
		hotbar_changed.emit()

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
