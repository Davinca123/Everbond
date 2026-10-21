extends Node2D

@onready var spawn_point = $YSort_Entities/SpawnPoint

# A SceneManager ezt kérdezi meg, hová tegye a Player-t, amikor a World betöltődik
func get_spawn_position() -> Vector2:
	# Megnézzük, hogy egy házból jöttünk-e épp vissza
	if GameManager.coming_back_from_interior:
		# Reseteljük a kapcsolót a következő házig
		GameManager.coming_back_from_interior = false
		# Ha igen, a Player-t pontosan a megmentett ajtó-pozícióra rakjuk!
		return GameManager.world_spawn_position
	return spawn_point.global_position
