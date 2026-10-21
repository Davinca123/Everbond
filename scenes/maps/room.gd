extends Node2D

@onready var player = $YSort_Entities/Player
@onready var companion = $YSort_Entities/Companion
@onready var spawn_point = $YSort_Entities/SpawnPoint

func _ready() -> void:
	# Amikor belépünk a szobába, a Player-t a kézzel lerakott SpawnPoint-ra tesszük,
	# a lényt pedig mellé, hogy ne a pálya másik végéről induljon
	player.global_position = spawn_point.global_position
	companion.global_position = spawn_point.global_position + Vector2(-60, 0)

	# Koppintásra a lény odamegy, ahová koppintottunk
	SignalBus.screen_tapped.connect(_on_screen_tapped)

# A képernyő pontot a kamera alapján világ koordinátává alakítjuk
func _on_screen_tapped(screen_position: Vector2) -> void:
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	companion.send_to_position(world_position)
