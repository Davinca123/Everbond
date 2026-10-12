extends Node2D

@onready var player = $YSort_Entities/Player
@onready var companion = $YSort_Entities/Companion

func _ready() -> void:
	# Koppintásra a lény odamegy, ahová koppintottunk
	SignalBus.screen_tapped.connect(_on_screen_tapped)

	# Megnézzük, hogy egy házból jöttünk-e épp vissza
	if GameManager.coming_back_from_interior:
		# Ha igen, a Player-t pontosan a megmentett ajtó-pozícióra rakjuk!
		player.global_position = GameManager.world_spawn_position
		# Reseteljük a kapcsolót a következő házig
		GameManager.coming_back_from_interior = false

# A képernyő pontot a kamera alapján világ koordinátává alakítjuk
func _on_screen_tapped(screen_position: Vector2) -> void:
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	companion.send_to_position(world_position)
