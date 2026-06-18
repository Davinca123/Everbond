extends CharacterBody2D

@export var speed: float = 200.0

@onready var sprite: Sprite2D = $Sprite2D

var input_direction: Vector2 = Vector2.ZERO
var control_enabled: bool = true

func _ready() -> void:
	# Feliratkozunk a joystick mozgására
	SignalBus.connect("joystick_moved", _on_joystick_moved)
	
	# Dialógus esetén teljesen megállítjuk a hős irányítását
	SignalBus.connect("dialogue_started", _on_dialogue_started)
	SignalBus.connect("dialogue_finished", _on_dialogue_finished)

func _physics_process(_delta: float) -> void:
	if not control_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Ha a mobil joystick nem ad jelet, figyeljük a billentyűzetet (PC teszteléshez)
	var current_input = input_direction
	if current_input == Vector2.ZERO:
		current_input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if current_input != Vector2.ZERO:
		velocity = current_input * speed
		# Sprite forgatása irány szerint
		if current_input.x > 0:
			sprite.scale.x = abs(sprite.scale.x)
		elif current_input.x < 0:
			sprite.scale.x = -abs(sprite.scale.x)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)

	move_and_slide()

# --- SZIGNÁL KEZELŐK ---

func _on_joystick_moved(direction: Vector2) -> void:
	input_direction = direction

func _on_dialogue_started(_speaker: String, _lines: Array) -> void:
	control_enabled = false
	input_direction = Vector2.ZERO  # Azonnali megállás duma kezdetekor

func _on_dialogue_finished() -> void:
	control_enabled = true
