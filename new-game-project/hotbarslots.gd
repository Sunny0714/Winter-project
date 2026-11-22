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
	get_parent().get_parent().inventory_dragging = true

	var original_image = get_node("WeaponImage")

	var preview = Control.new()
	preview.custom_minimum_size = Vector2(48, 48)
	preview.size = Vector2(48, 48)

	var preview_image = TextureRect.new()
	preview_image.texture = original_image.texture
	preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	preview_image.size = original_image.size
	preview_image.position = Vector2(-24, -24)
	preview_image.rotation = original_image.rotation
	preview_image.scale = original_image.scale * 1.0
	preview_image.pivot_offset = original_image.size / 2

	preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	preview.add_child(preview_image)
	set_drag_preview(preview)

	return {"from_slot": slot_index}

func _notification(what):
	if what != NOTIFICATION_DRAG_END or not dragging:
		return

	dragging = false

	var hotbar_ui = get_parent().get_parent()
	var should_drop = false

	if not get_viewport().gui_is_drag_successful():
		var mouse_pos = get_global_mouse_position()
		should_drop = not get_global_rect().has_point(mouse_pos)

	hotbar_ui.inventory_dragging = false

	if should_drop:
		hotbar_ui.call_deferred("drop_item_from_slot", slot_index)

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
