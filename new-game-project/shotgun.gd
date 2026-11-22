extends Area2D

@onready var label = $RichTextLabel

@export var separation_radius: float = 100.0
@export var separation_speed: float = 1000.0

var player = null
var picked_up := false

func _ready():
	add_to_group("dropped_items")
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
	label.text = "[center][b]" + get_interact_key() + " TO PICK UP SHOTGUN[/b][/center]"

func get_interact_key():
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey:
			return "[" + OS.get_keycode_string(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode) + "]"
	return "[Interact]"

func pick_up():
	var remaining = Manager.add_item("shotgun", 4, 4)
	if remaining > 0:
		label.text = "[center][b]INVENTORY FULL![/b][/center]"
		return
	picked_up = true
	Manager.hotbar_changed.emit()
	queue_free()

func _physics_process(delta):
	var push_direction = Vector2.ZERO

	for item in get_tree().get_nodes_in_group("dropped_items"):
		if item == self or not is_instance_valid(item):
			continue

		var offset = global_position - item.global_position
		var distance = offset.length()

		if distance >= separation_radius:
			continue

		if distance < 0.01:
			offset = Vector2.RIGHT.rotated(get_instance_id() % 360)
			distance = 1.0

		push_direction += offset.normalized() * (1.0 - distance / separation_radius)

	if push_direction.length() > 0.0:
		global_position += push_direction.normalized() * separation_speed * delta
