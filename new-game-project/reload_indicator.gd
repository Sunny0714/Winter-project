
extends Control

@export var vertical_offset: float = 20.0

@onready var ring = $CenterContainer/Ring
@onready var countdown = $CenterContainer/Countdown

var progress := 0.0
var reload_duration := 1.0
var remaining_time := 0.0

func _ready():
	visible = false
	position.y += vertical_offset
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ring.draw.connect(_draw_ring)

func start_reload(duration: float):
	reload_duration = maxf(duration, 0.001)
	remaining_time = reload_duration
	progress = 0.0
	visible = true
	_update_display()

func update_progress(remaining: float):
	remaining_time = clampf(remaining, 0.0, reload_duration)
	progress = 1.0 - remaining_time / reload_duration
	_update_display()

func _update_display():
	countdown.text = "%.2f" % remaining_time
	ring.queue_redraw()

func finish_reload():
	remaining_time = 0.0
	progress = 1.0
	_update_display()
	await get_tree().create_timer(0.15).timeout
	visible = false

func _draw_ring():
	var center = ring.size / 2.0
	var radius = 17.0
	var start_angle = -PI / 2.0
	var end_angle = start_angle + TAU * progress
	ring.draw_arc(center, radius, start_angle, end_angle, 64, Color.WHITE, 3.0, true)
