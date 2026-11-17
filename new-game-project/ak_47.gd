extends Area2D

@onready var label = $Label

var player = null
var picked_up := false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.visible = false

func _on_body_entered(body):
	if body is CharacterBody2D:
		player = body
		label.text = get_interact_key() + " to pick up AK47"
		label.visible = true

func _on_body_exited(body):
	if body == player:
		player = null
		label.visible = false

func _process(_delta):
	if picked_up or not is_instance_valid(player):
		return

	if Input.is_action_just_pressed("interact"):
		pick_up()

func get_interact_key():
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey:
			return "[" + OS.get_keycode_string(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode) + "]"

	return "[Interact]"

func pick_up():
	var remaining = Manager.add_item("ak47", 30, 30)

	if remaining > 0:
		label.text = "Inventory full!"
		return

	picked_up = true
	Manager.hotbar_changed.emit()
	queue_free()

	if remaining > 0:
		label.text = "Inventory full!"
		return

	picked_up = true
	Manager.hotbar_changed.emit()
	queue_free()
