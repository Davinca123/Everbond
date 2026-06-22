extends Node2D

@onready var player = $YSort_Entities/Player

func _ready() -> void:
	# Megnézzük, hogy egy házból jöttünk-e épp vissza
	if GameManager.coming_back_from_interior:
		# Ha igen, a Player-t pontosan a megmentett ajtó-pozícióra rakjuk!
		player.global_position = GameManager.world_spawn_position
		# Reseteljük a kapcsolót a következő házig
		GameManager.coming_back_from_interior = false
