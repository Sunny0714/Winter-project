extends Area2D

@export var speed: float = 2100.0
@export var damage: float = 10.0
@export var max_distance: float = 1200.0

var direction := Vector2.UP
var distance_travelled := 0.0

func _ready():
	show()
	body_entered.connect(_on_body_entered)

func setup(new_direction: Vector2):
	direction = new_direction.normalized()
	rotation = direction.angle() + PI / 2

func _physics_process(delta):
	var movement = direction * speed * delta
	global_position += movement
	distance_travelled += movement.length()

	if distance_travelled >= max_distance:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction, 150.0)
		queue_free()
