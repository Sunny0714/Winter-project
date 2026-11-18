extends Area2D

@export var damage: float = 15.0
@export var knockback_force: float = 450.0
@export var active_time: float = 0.12

var hit_enemies: Array = []

func _ready():
	$AnimationPlayer.play("swipe")
	monitoring = false
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func activate():
	monitoring = true
	monitorable = true
	await get_tree().create_timer(active_time).timeout
	if is_instance_valid(self):
		queue_free()

func _on_body_entered(body):
	_hit_target(body)

func _on_area_entered(area):
	_hit_target(area)

func _hit_target(target):
	var enemy = target
	while enemy != null and not enemy.is_in_group("enemies"):
		enemy = enemy.get_parent()

	if enemy == null or enemy in hit_enemies:
		return

	hit_enemies.append(enemy)

	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)

	if enemy.has_method("apply_knockback"):
		var direction = (enemy.global_position - global_position).normalized()
		enemy.apply_knockback(direction, knockback_force)
