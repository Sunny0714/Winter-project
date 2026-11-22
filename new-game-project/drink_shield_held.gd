
extends Node2D

@export var reload_indicator_scene: PackedScene
@export var animation_speed: float = 12.0
@export var movement_distance: float = 12.0

var original_position := Vector2.ZERO
var animation_time := 0.0
var is_using := false
var reload_indicator = null
var player = null

func _ready():
	original_position = position
	player = get_parent()

func _process(delta):
	if not is_using:
		animation_time = 0.0
		position = original_position

		if is_instance_valid(reload_indicator):
			reload_indicator.queue_free()
			reload_indicator = null

		return

	animation_time += delta * animation_speed
	position.y = original_position.y + (1.0 - cos(animation_time)) * 0.5 * movement_distance

	if not is_instance_valid(reload_indicator) and reload_indicator_scene != null:
		var canvas_layer = player.get_node_or_null("CanvasLayer")

		if canvas_layer:
			reload_indicator = reload_indicator_scene.instantiate()
			canvas_layer.add_child(reload_indicator)
			reload_indicator.start_reload(player.potion_use_time)

	if is_instance_valid(reload_indicator):
		reload_indicator.update_progress(player.potion_timer)

func start_use():
	is_using = true

func stop_indicator(completed: bool = false):
	if not is_instance_valid(reload_indicator):
		return

	if completed:
		reload_indicator.update_progress(0.0)
		reload_indicator.finish_reload()
	else:
		reload_indicator.queue_free()

	reload_indicator = null
