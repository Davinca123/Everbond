extends StaticBody2D

@onready var interaction_area: Area2D = $InteractionArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite_2d: Sprite2D = $Sprite2D

const FRAME_CLOSED: int = 0  # A csukott ajtó csempe indexe
const FRAME_OPEN: int = 1    # A nyitott ajtó csempe indexe

var player_in_range: bool = false
var is_open: bool = false
var interaction_type: String = "chest" # A "chest" típus miatt az UI gomb automatikusan a "Kinyit" feliratot kapja!

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	# Figyeljük, mikor nyomja meg a játékos a jobb alsó gombot
	SignalBus.interaction_pressed.connect(_on_interaction_pressed)
	
	sprite_2d.frame = FRAME_CLOSED

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not is_open:
		player_in_range = true
		SignalBus.show_interaction_button.emit(interaction_type)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false
		SignalBus.hide_interaction_button.emit()

func _on_interaction_pressed() -> void:
	# Csak akkor nyíljon ki, ha a közelben vagyunk, és még csukva van
	if player_in_range and not is_open:
		open_door()

func open_door() -> void:
	is_open = true
	player_in_range = false
	
	# 1. Eltüntetjük az UI gombot
	SignalBus.hide_interaction_button.emit()
	
	# 2. Kikapcsoljuk a fizikai ütközést (Át lehet sétálni rajta!)
	# A set_deferred biztonságosabbá teszi a fizikai motor kikapcsolását futás közben
	collision_shape.set_deferred("disabled", true)
	
	# 3. TEXTÚRA CSERE: Átállítjuk a Sprite-ot a nyitott ajtó képkockájára!
	sprite_2d.frame = FRAME_OPEN
	
	print("Door: Opened successfully using frame texture exchange.")
