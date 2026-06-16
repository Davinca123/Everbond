extends CharacterBody2D

@export var speed: float = 200.0

# Vizuális Joystick hivatkozások
@onready var joystick_visual = $"../UI/JoystickVisual" # Pontos elérés a jelenetfádon!
@onready var joystick_base = $"../UI/JoystickVisual/JoystickBase"
@onready var joystick_tip = $"../UI/JoystickVisual/JoystickTip"

# Logikai változók
var joystick_active: bool = false
var joystick_start_pos: Vector2 = Vector2.ZERO
var input_direction: Vector2 = Vector2.ZERO
const JOYSTICK_MAX_LENGTH: float = 50.0 # Hány pixelre mozdulhat ki a pötty

@onready var sprite = $Sprite2D

func _input(event):
	# Amikor az ujjad leér a képernyő bal oldalára
	if event is InputEventScreenTouch:
		if event.position.x < get_viewport_rect().size.x / 2 and event.pressed:
			joystick_active = true
			joystick_start_pos = event.position
			
			# MEGJELENÍTÉS: Odaugratjuk a nagy kört, ahol az ujjad van, és láthatóvá tesszük
			joystick_visual.visible = true
			joystick_base.global_position = joystick_start_pos
			joystick_tip.global_position = joystick_start_pos
			
		elif !event.pressed and joystick_active:
			joystick_active = false
			input_direction = Vector2.ZERO
			
			# ELREJTÉS: Ha felemeled az ujjad, eltüntetjük a joysticket
			joystick_visual.visible = false

	# Amikor húzod az ujjad a képernyőn
	if event is InputEventScreenDrag and joystick_active:
		var drag_vector = event.position - joystick_start_pos
		
		# Ha túl messzire húzod, lekorlátozzuk a kört
		if drag_vector.length() > JOYSTICK_MAX_LENGTH:
			drag_vector = drag_vector.normalized() * JOYSTICK_MAX_LENGTH
		
		# MOZGATÁS: A belső pöttyöt eltoljuk a húzás irányába
		joystick_tip.global_position = joystick_start_pos + drag_vector
		
		# Irány kiszámítása a karakter mozgásához
		input_direction = drag_vector / JOYSTICK_MAX_LENGTH

func _physics_process(delta):
	# Billentyűzet támogatás teszteléshez
	if input_direction == Vector2.ZERO:
		input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_direction != Vector2.ZERO:
		velocity = input_direction * speed
		if input_direction.x > 0:
			sprite.scale.x = abs(sprite.scale.x)
		elif input_direction.x < 0:
			sprite.scale.x = -abs(sprite.scale.x)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)

	move_and_slide()
