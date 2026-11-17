
extends Label

var velocity := Vector2(randf_range(-40, 40), -120)
var gravity := 300.0
var lifetime := 0.6
var max_lifetime := 0.6

func setup(amount: float, is_healing: bool = false):
	text = "+" + str(amount) if is_healing else "-" + str(amount)
	modulate = Color.GREEN if is_healing else Color.WHITE

func _process(delta):
	lifetime -= delta
	velocity.y += gravity * delta
	position += velocity * delta
	scale -= Vector2.ONE * delta
	modulate.a = clamp(lifetime / max_lifetime, 0.0, 1.0)

	if lifetime <= 0:
		queue_free()
