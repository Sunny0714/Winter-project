extends CanvasLayer

@onready var menu = $Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu.visible = false

func show_death_menu():
	menu.visible = true
	get_tree().paused = true

func _on_respawn_pressed():
	get_tree().paused = false
	menu.visible = false
	Manager.reset_inventory()
	get_tree().change_scene_to_file("res://level_1.tscn")

func _on_quit_pressed():
	get_tree().quit()
