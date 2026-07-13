extends CanvasLayer

const CURSOR_SCALE := 0.09

const CURSOR_TEXTURES := {
	"Cursor": "res://UI/Interfaz/controlesUI/cursor/cursor.png",
	"pointer": "res://UI/Interfaz/controlesUI/cursor/pointer.png",
	"two": "res://UI/Interfaz/controlesUI/cursor/two-fingers.png"
}

var _sprite: AnimatedSprite2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_sprite_frames()
	_sprite.centered = false
	_sprite.scale = Vector2(CURSOR_SCALE, CURSOR_SCALE)
	add_child(_sprite)
	_sprite.play("Cursor")

func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	for anim_name in CURSOR_TEXTURES:
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, false)
		frames.add_frame(anim_name, load(CURSOR_TEXTURES[anim_name]))
	return frames

func _process(_delta: float) -> void:
	_sprite.global_position = get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_sprite.play("two" if event.double_click else "pointer")
		else:
			_sprite.play("Cursor")
