extends ProgressBar

var flash_timer: float = 0.0
var flashing: bool = false

var green_health: float = 100.0
var blue_health: float = 0.0
var purple_health: float = 0.0

func _ready():
	add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	add_theme_stylebox_override("background", StyleBoxEmpty.new())

func set_health(new_health: float):
	value = clamp(new_health, 0, max_value)
	queue_redraw()

func set_flashing_health(new_health: float):
	flashing = new_health <= 25

func set_max_health(new_max: float):
	max_value = new_max
	queue_redraw()

func set_health_color(new_color: Color):
	queue_redraw()

func set_layer_health(green: float, blue: float, purple: float):
	green_health = clamp(green, 0, max_value)
	blue_health = clamp(blue, 0, max_value)
	purple_health = clamp(purple, 0, max_value)
	queue_redraw()

func draw_rounded_section(rect: Rect2, color: Color, left_round: bool, right_round: bool):
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var radius = min(6.0, rect.size.y / 2.0, rect.size.x / 2.0)

	var body_left = rect.position.x + (radius if left_round else 0.0)
	var body_right = rect.end.x - (radius if right_round else 0.0)

	if body_right > body_left:
		draw_rect(Rect2(body_left, rect.position.y, body_right - body_left, rect.size.y), color)

	if left_round:
		draw_rect(Rect2(rect.position.x, rect.position.y + radius, radius, rect.size.y - radius * 2.0), color)
		draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
		draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)

	if right_round:
		draw_rect(Rect2(rect.end.x - radius, rect.position.y + radius, radius, rect.size.y - radius * 2.0), color)
		draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
		draw_circle(Vector2(rect.end.x - radius, rect.end.y - radius), radius, color)

func _draw():
	if max_value <= 0:
		return

	var total_width = size.x
	var total_height = size.y

	var purple_width = total_width * clamp(purple_health, 0.0, max_value) / max_value
	var blue_width = total_width * clamp(blue_health, 0.0, max_value) / max_value
	var green_width = total_width * clamp(green_health, 0.0, max_value) / max_value

	var remaining_width = total_width
	var x = 0.0

	purple_width = min(purple_width, remaining_width)
	remaining_width -= purple_width

	blue_width = min(blue_width, remaining_width)
	remaining_width -= blue_width

	green_width = min(green_width, remaining_width)

	if purple_width > 0:
		draw_rounded_section(Rect2(x, 0, purple_width, total_height), Color("7c27c5ff"), true, false)
		x += purple_width

	if blue_width > 0:
		draw_rounded_section(Rect2(x, 0, blue_width, total_height), Color("386bf8ff"), false, false)
		x += blue_width

	if green_width > 0:
		draw_rounded_section(Rect2(x, 0, green_width, total_height), Color("#10a01c"), false, true)

func _process(delta):
	if flashing:
		flash_timer += delta
		if int(flash_timer * 5) % 2 == 0:
			modulate = Color(1, 0.2, 0.2)
		else:
			modulate = Color.WHITE
	else:
		flash_timer = 0.0
		modulate = Color.WHITE
