extends Control

var keybinds = [
	{"label": "Slot 1 (Fist)", "action": "slot_1", "default": KEY_1},
	{"label": "Slot 2", "action": "slot_2", "default": KEY_2},
	{"label": "Slot 3", "action": "slot_3", "default": KEY_3},
	{"label": "Slot 4", "action": "slot_4", "default": KEY_4},
	{"label": "Slot 5", "action": "slot_5", "default": KEY_5},
	{"label": "Slot 6", "action": "slot_6", "default": KEY_6},
	{"label": "Interact", "action": "interact", "default": KEY_E},
	{"label": "Dash", "action": "dash", "default": KEY_SPACE},
	{"label": "Reload", "action": "reload", "default": KEY_R}]

var keycodes := {}
var key_buttons := {}
var waiting_action := ""

var main_panel: PanelContainer
var settings_panel: PanelContainer
var background: ColorRect
var center: CenterContainer

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_keybinds()
	_build_ui()
	visible = false
	_set_hotbar_mouse(false)

func _setup_keybinds():
	var config = ConfigFile.new()
	config.load("user://keybinds.cfg")

	for item in keybinds:
		var action = item["action"]

		if !InputMap.has_action(action):
			InputMap.add_action(action)

		var key = int(config.get_value("keybinds", action, item["default"]))
		keycodes[action] = key
		_apply_key(action, key)

func _apply_key(action: String, key: int):
	InputMap.action_erase_events(action)

	var event = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _save_keybind(action: String, key: int):
	var config = ConfigFile.new()
	config.load("user://keybinds.cfg")
	config.set_value("keybinds", action, key)
	config.save("user://keybinds.cfg")

func _build_ui():
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(420, 0)
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(main_panel)

	var main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 15)
	main_panel.add_child(main_box)

	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_box.add_child(title)

	var continue_button = _make_button("CONTINUE")
	continue_button.pressed.connect(_close_menu)
	main_box.add_child(continue_button)

	var settings_button = _make_button("SETTINGS")
	settings_button.pressed.connect(_show_settings)
	main_box.add_child(settings_button)

	var quit_button = _make_button("QUIT")
	quit_button.pressed.connect(_show_quit_dialog)
	main_box.add_child(quit_button)

	settings_panel = PanelContainer.new()
	settings_panel.custom_minimum_size = Vector2(500, 0)
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(settings_panel)

	var settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 12)
	settings_panel.add_child(settings_box)

	var settings_title = Label.new()
	settings_title.text = "SETTINGS"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 32)
	settings_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_box.add_child(settings_title)

	var keybind_title = Label.new()
	keybind_title.text = "KEYBINDS"
	keybind_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keybind_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_box.add_child(keybind_title)

	for item in keybinds:
		var row = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		settings_box.add_child(row)

		var label = Label.new()
		label.text = item["label"]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)

		var button = _make_button(OS.get_keycode_string(keycodes[item["action"]]))
		button.custom_minimum_size = Vector2(130, 40)
		button.pressed.connect(_start_rebind.bind(item["action"]))
		row.add_child(button)

		key_buttons[item["action"]] = button

	var back_button = _make_button("BACK")
	back_button.pressed.connect(_show_main)
	settings_box.add_child(back_button)

	settings_panel.visible = false

func _make_button(button_text: String) -> Button:
	var button = Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(260, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	return button

func _show_main():
	waiting_action = ""
	main_panel.visible = true
	settings_panel.visible = false

func _show_settings():
	main_panel.visible = false
	settings_panel.visible = true

func _show_quit_dialog():
	get_tree().quit()

func _set_hotbar_mouse(enabled: bool):
	var hotbar = get_tree().current_scene.find_child("HotbarUI", true, false)
	if hotbar:
		hotbar.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func _open_menu():
	_set_game_ui_visible(false)
	visible = true
	_show_main()
	_set_hotbar_mouse(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_menu():
	_set_game_ui_visible(true)
	visible = false
	waiting_action = ""
	get_tree().paused = false

	var player = get_tree().root.find_child("Player", true, false)
	if is_instance_valid(player) and is_instance_valid(player.held_ak):
		player.held_ak.wait_for_mouse_release = true
		player.held_ak.is_firing = false

func _start_rebind(action: String):
	waiting_action = action
	key_buttons[action].text = "Press a key..."


func _input(event):
	if waiting_action == "":
		return

	var key: int = KEY_UNKNOWN

	if event is InputEventKey and event.pressed and not event.echo:
		key = event.keycode
		if key == KEY_UNKNOWN:
			key = event.physical_keycode

	elif event is InputEventMouseButton and event.pressed:
		key = event.button_index

	else:
		return

	var action = waiting_action
	waiting_action = ""

	keycodes[action] = key

	InputMap.action_erase_events(action)

	if event is InputEventKey:
		var key_event = InputEventKey.new()
		key_event.keycode = key
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)
	else:
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = key
		InputMap.action_add_event(action, mouse_event)

	_save_keybind(action, key)

	if event is InputEventKey:
		key_buttons[action].text = OS.get_keycode_string(key)
	else:
		key_buttons[action].text = "Mouse " + str(key)

	get_viewport().set_input_as_handled()


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if waiting_action != "":
			return

		if visible:
			if settings_panel.visible:
				_show_main()
			else:
				_close_menu()
		else:
			_open_menu()

		get_viewport().set_input_as_handled()

func _set_game_ui_visible(enabled: bool):
	var player = get_tree().root.find_child("Player", true, false)
	var hotbar = get_tree().root.find_child("HotbarUI", true, false)

	if player:
		var health_bar = player.find_child("HealthBar", true, false)
		var damage_bar = player.find_child("DamageBar", true, false)

		if health_bar:
			health_bar.visible = enabled

		if damage_bar:
			damage_bar.visible = enabled

	if hotbar:
		hotbar.visible = enabled
