extends ProgressBar

var flash_timer: float = 0.0
var flashing: bool = false

func set_health(new_health: float):
	new_health = clamp(new_health, 0, max_value)
	self.value = new_health
	if new_health <= 25:
		flashing = true
	else:
		flashing = false

func set_max_health(new_max_health: float):
	max_value = new_max_health

func _process(delta):
	if flashing:
		flash_timer += delta
		if int(flash_timer * 5) % 2 == 0:
			modulate = Color(1, 0.2, 0.2)
		else:
			modulate = Color(1, 1, 1)
	else:
		modulate = Color(1, 1, 1)
