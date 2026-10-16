extends CharacterBody2D

@export var speed: float = 200.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var input_direction: Vector2 = Vector2.ZERO
var control_enabled: bool = true
# Merre néz a hős: "down", "left", "right" vagy "up" (az animációk nevének vége)
var facing: String = "down"

func _ready() -> void:
	# Feliratkozunk a joystick mozgására
	SignalBus.connect("joystick_moved", _on_joystick_moved)
	
	# Dialógus esetén teljesen megállítjuk a hős irányítását
	SignalBus.connect("dialogue_started", _on_dialogue_started)
	SignalBus.connect("dialogue_finished", _on_dialogue_finished)

func _physics_process(_delta: float) -> void:
	if not control_enabled:
		velocity = Vector2.ZERO
		play_animation("idle")
		move_and_slide()
		return

	# Ha a mobil joystick nem ad jelet, figyeljük a billentyűzetet (PC teszteléshez)
	var current_input = input_direction
	if current_input == Vector2.ZERO:
		current_input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if current_input != Vector2.ZERO:
		velocity = current_input * speed
		# Arra fordul, amerre a mozgás nagyobb része mutat
		if abs(current_input.x) > abs(current_input.y):
			facing = "right" if current_input.x > 0 else "left"
		else:
			facing = "down" if current_input.y > 0 else "up"
		play_animation("walk")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		play_animation("idle")

	move_and_slide()

# A "walk" vagy "idle" animációt játssza le az aktuális irányba (pl. "walk_left")
func play_animation(action: String) -> void:
	var anim_name := action + "_" + facing
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

# --- SZIGNÁL KEZELŐK ---

func _on_joystick_moved(direction: Vector2) -> void:
	input_direction = direction

func _on_dialogue_started(_speaker: String, _lines: Array) -> void:
	control_enabled = false
	input_direction = Vector2.ZERO  # Azonnali megállás duma kezdetekor

func _on_dialogue_finished() -> void:
	control_enabled = true
