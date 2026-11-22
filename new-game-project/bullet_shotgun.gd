extends Area2D

@export var speed: float = 2600.0
@export var damage: float = 2.0
@export var max_distance: float = 375.0
@export var proximity_range: float = 500.0
@export var max_damage_multiplier: float = 5.4

var direction := Vector2.UP
var distance_travelled := 0.0
var shot_id := 0
var player: Node2D

func _ready():
	show()
	body_entered.connect(_on_body_entered)
	player = get_tree().root.find_child("Player", true, false)

func setup(new_direction: Vector2, new_shot_id: int = 0):
	direction = new_direction.normalized()
	shot_id = new_shot_id
	rotation = direction.angle() + PI / 2

func _physics_process(delta):
	var movement = direction * speed * delta
	global_position += movement
	distance_travelled += movement.length()
	if distance_travelled >= max_distance:
		queue_free()

func _on_body_entered(body):
	if not body.is_in_group("enemies"):
		return
	var final_damage = damage
	if is_instance_valid(player):
		var distance = player.global_position.distance_to(body.global_position)
		var proximity = 1.0 - clampf(distance / proximity_range, 0.0, 1.0)
		var multiplier = lerpf(1.0, max_damage_multiplier, proximity)
		final_damage *= multiplier
	if body.has_method("take_damage"):
		body.take_damage(final_damage, shot_id)
	if body.has_method("apply_knockback"):
		body.apply_knockback(direction, 900.0)
	queue_free()
