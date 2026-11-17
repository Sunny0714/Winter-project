
extends Button

@export var slot_index: int = 0

var dragging := false

func _ready():
	pressed.connect(_on_pressed)
	update_outline()

func _on_pressed():
	get_parent().get_parent().select_slot(slot_index)

func update_outline():
	remove_theme_stylebox_override("normal")
	remove_theme_stylebox_override("hover")
	remove_theme_stylebox_override("pressed")
	remove_theme_stylebox_override("focus")

	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_focus_color", Color.WHITE)

	var hotbar_ui = get_parent().get_parent()

	if hotbar_ui.selected_slot != slot_index:
		return

	var style = create_outline()
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)

func create_outline():
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#292C38")
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	return style

func _get_drag_data(_at_position):
	if slot_index == 0:
		return null

	var item = Manager.hotbar[slot_index]
	if item["id"] == "":
		return null

	dragging = true

	var preview = Button.new()
	preview.text = text
	preview.custom_minimum_size = size
	set_drag_preview(preview)

	return {"from_slot": slot_index}

func _notification(what):
	if what == NOTIFICATION_DRAG_END and dragging:
		dragging = false
		if not get_viewport().gui_is_drag_successful():
			var hotbar_ui = get_parent().get_parent()
			hotbar_ui.drop_item_from_slot(slot_index)

func _can_drop_data(_at_position, data):
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var from_slot = data.get("from_slot", -1)

	if from_slot < 1 or from_slot > 5:
		return false
	if slot_index < 1 or slot_index > 5:
		return false

	return from_slot != slot_index

func _drop_data(_at_position, data):
	Manager.swap_items(data["from_slot"], slot_index)
	get_parent().get_parent().update_hotbar()
