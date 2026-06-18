extends Control

# A bázis és a pötty elérése egyedi névvel (% ikon)
@onready var joystick_base: Sprite2D = %JoystickBase
@onready var joystick_tip: Sprite2D = %JoystickTip

var joystick_active: bool = false
var joystick_start_pos: Vector2 = Vector2.ZERO
const JOYSTICK_MAX_LENGTH: float = 50.0

func _ready() -> void:
	# Maga a fő vezérlő (self) MINDIG legyen látható és aktív, hogy érzékelje az érintést!
	visible = true 
	
	# Csak a két grafikus elemet rejtjük el a játék elején
	joystick_base.visible = false
	joystick_tip.visible = false
	
	# Globális tiltások dialógus esetén
	SignalBus.connect("dialogue_started", func(_s, _l): visible = false; SignalBus.joystick_moved.emit(Vector2.ZERO))
	SignalBus.connect("dialogue_finished", func(): visible = true)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		if event.position.x < get_viewport_rect().size.x / 2 and event.pressed:
			joystick_active = true
			joystick_start_pos = event.position
			
			# GRAFIKA MEGJELENÍTÉSE
			joystick_base.visible = true
			joystick_tip.visible = true
			
			joystick_base.global_position = joystick_start_pos
			joystick_tip.global_position = joystick_start_pos
			
		elif !event.pressed and joystick_active:
			joystick_active = false
			
			# GRAFIKA ELREJTÉSE
			joystick_base.visible = false
			joystick_tip.visible = false
			
			SignalBus.joystick_moved.emit(Vector2.ZERO)

	if event is InputEventScreenDrag and joystick_active:
		var drag_vector = event.position - joystick_start_pos
		
		if drag_vector.length() > JOYSTICK_MAX_LENGTH:
			drag_vector = drag_vector.normalized() * JOYSTICK_MAX_LENGTH
		
		joystick_tip.global_position = joystick_start_pos + drag_vector
		
		var final_direction = drag_vector / JOYSTICK_MAX_LENGTH
		SignalBus.joystick_moved.emit(final_direction)
