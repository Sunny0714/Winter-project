extends Control

@onready var ring = $CenterContainer/Ring

var progress := 0.0

func _ready():
	visible = false
	ring.draw.connect(_draw_ring)

func start_reload():
	progress = 0.0
	visible = true
	ring.queue_redraw()

func update_progress(value: float):
	progress = clampf(value, 0.0, 1.0)
	ring.queue_redraw()

func finish_reload():
	progress = 0.0
	visible = false

func _draw_ring():
	var center = ring.size / 2.0
	var radius = 25.0
	var start_angle = -PI / 2.0
	var end_angle = start_angle + TAU * progress

	ring.draw_arc(center, radius, start_angle, end_angle, 64, Color.WHITE, 4.0, true)
