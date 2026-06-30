extends CanvasLayer

signal closed

const ACTIONS: Array[String] = ["move_left", "move_right", "jump", "dash", "pause_game"]
const ACTION_LABELS := {
	"move_left": "Mover izquierda",
	"move_right": "Mover derecha",
	"jump": "Saltar",
	"dash": "Dash",
	"pause_game": "Pausa"
}

# QWERTY Layout rows
const KEYBOARD_LAYOUT = [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
	["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
	["A", "S", "D", "F", "G", "H", "J", "K", "L"],
	["Z", "X", "C", "V", "B", "N", "M"],
	["SPACE"]
]

const PHYSICAL_TO_KEYNAME = {
	KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4", KEY_5: "5",
	KEY_6: "6", KEY_7: "7", KEY_8: "8", KEY_9: "9", KEY_0: "0",
	KEY_Q: "Q", KEY_W: "W", KEY_E: "E", KEY_R: "R", KEY_T: "T",
	KEY_Y: "Y", KEY_U: "U", KEY_I: "I", KEY_O: "O", KEY_P: "P",
	KEY_A: "A", KEY_S: "S", KEY_D: "D", KEY_F: "F", KEY_G: "G",
	KEY_H: "H", KEY_J: "J", KEY_K: "K", KEY_L: "L",
	KEY_Z: "Z", KEY_X: "X", KEY_C: "C", KEY_V: "V", KEY_B: "B",
	KEY_N: "N", KEY_M: "M", KEY_SPACE: "SPACE"
}

var _waiting_action: String = ""
var _visual_keys: Dictionary = {} # Key name -> TextureRect/Control

@onready var _panel: PanelContainer = $Panel
@onready var _keyboard_container: VBoxContainer = $Panel/Content/Keyboard
@onready var _status: Label = $Panel/Content/Status
@onready var _back_button: Button = $Panel/Content/Actions/BackButton
@onready var _action_selector: OptionButton = $Panel/Content/ActionSelector

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	_build_keyboard()
	_apply_styles()
	_connect_signals()
	_refresh_highlights()

func _build_keyboard() -> void:
	for row in KEYBOARD_LAYOUT:
		var row_box = HBoxContainer.new()
		row_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_keyboard_container.add_child(row_box)
		for key_name in row:
			var key_ctrl = TextureRect.new()
			key_ctrl.custom_minimum_size = Vector2(32, 32)
			key_ctrl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			key_ctrl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

			var tex_path = "res://UI/Light/Single PNGs/" + key_name + ".png"
			if FileAccess.file_exists(tex_path):
				key_ctrl.texture = load(tex_path)

			row_box.add_child(key_ctrl)
			_visual_keys[key_name] = key_ctrl

func _connect_signals() -> void:
	_back_button.pressed.connect(close_menu)
	_action_selector.item_selected.connect(_on_action_selected)
	for action in ACTIONS:
		_action_selector.add_item(ACTION_LABELS[action])

func open_menu() -> void:
	visible = true
	_waiting_action = ACTIONS[0]
	_action_selector.select(0)
	_status.text = "Presiona una tecla para asignar a: " + ACTION_LABELS[_waiting_action]
	_center_panel()
	_back_button.grab_focus()

func close_menu() -> void:
	AudioManager.play_sfx(&"ui_back")
	visible = false
	closed.emit()

func _on_action_selected(index: int) -> void:
	_waiting_action = ACTIONS[index]
	_status.text = "Presiona una tecla para asignar a: " + ACTION_LABELS[_waiting_action]

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey:
		var key_name = PHYSICAL_TO_KEYNAME.get(event.physical_keycode, "")
		if key_name != "":
			var visual_key = _visual_keys.get(key_name)
			if visual_key:
				if event.pressed:
					visual_key.modulate = Color(1, 0.2, 0.2) # Highlight red when pressed
					if _waiting_action != "":
						if GameManager.is_keyboard_action_allowed(_waiting_action, event.physical_keycode):
							GameManager.set_keyboard_action(_waiting_action, event.physical_keycode)
							GameManager.save_controls()
							_status.text = ACTION_LABELS[_waiting_action] + " guardado en " + key_name
							_refresh_highlights()
						else:
							_status.text = "Tecla no permitida para esta accion."
				else:
					visual_key.modulate = Color(1, 1, 1)

		if event.pressed and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game")):
			if get_viewport().gui_get_focus_owner() == _back_button:
				close_menu()
				get_viewport().set_input_as_handled()
			else:
				_back_button.grab_focus()

func _refresh_highlights() -> void:
	# Reset all colors first
	for k in _visual_keys:
		_visual_keys[k].self_modulate = Color(1, 1, 1)

	# Highlight currently bound keys for all actions
	for action in ACTIONS:
		var keycode = _get_keycode_for_action(action)
		var key_name = PHYSICAL_TO_KEYNAME.get(keycode, "")
		if key_name != "" and _visual_keys.has(key_name):
			_visual_keys[key_name].self_modulate = Color(0.4, 0.8, 1.0) # Light blue for bound keys

func _get_keycode_for_action(action_name: String) -> int:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			return event.physical_keycode
	return 0

func _apply_styles() -> void:
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_back_button.add_theme_stylebox_override("normal", _button_style())

func _panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)
	style.border_color = Color(1, 1, 1, 0.5)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style

func _button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 1)
	style.border_color = Color(0.8, 0.8, 0.8, 1)
	style.border_width_bottom = 2
	return style

func _center_panel() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	_panel.reset_size()
	_panel.position = (viewport_size - _panel.size) * 0.5
