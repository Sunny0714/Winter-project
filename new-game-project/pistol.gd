extends Area2D

@onready var label = $RichTextLabel

var player = null
var picked_up := false

func _ready():
	label.hide()
	label.bbcode_enabled = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body is CharacterBody2D:
		player = body
		update_label()
		label.show()

func _on_body_exited(body):
	if body == player:
		player = null
		label.hide()

func _process(_delta):
	if picked_up or not is_instance_valid(player):
		return
	if Input.is_action_just_pressed("interact") and Manager.claim_pickup_press():
		pick_up()

func update_label():
	label.text = "[center][b]" + get_interact_key() + " TO PICK UP PISTOL[/b][/center]"

func get_interact_key():
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey:
			return "[" + OS.get_keycode_string(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode) + "]"
	return "[Interact]"

func pick_up():
	var remaining = Manager.add_item("pistol", 15, 15)
	if remaining > 0:
		label.text = "[center][b]INVENTORY FULL![/b][/center]"
		return
	picked_up = true
	Manager.hotbar_changed.emit()
	queue_free()
