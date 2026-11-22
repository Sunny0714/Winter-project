extends Label

var velocity := Vector2(randf_range(-40, 40), -120)
var gravity := 300.0
var lifetime := 0.6
var max_lifetime := 0.6
var start_scale := 4.0
var end_scale := 0.5

func setup(amount: float, is_healing: bool = false):
	text = str(roundi(amount))
	modulate = Color.GREEN if is_healing else Color.WHITE
	scale = Vector2.ONE * start_scale

func _process(delta):
	lifetime -= delta
	velocity.y += gravity * delta
	position += velocity * delta
	var progress = 1.0 - lifetime / max_lifetime
	var current_scale = lerpf(start_scale, end_scale, progress)
	scale = Vector2.ONE * current_scale
	modulate.a = clampf(lifetime / max_lifetime, 0.0, 1.0)
	if lifetime <= 0:
		queue_free()
