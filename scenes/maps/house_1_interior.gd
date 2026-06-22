extends Node2D

@onready var player = $YSort_Entities/Player
@onready var spawn_point = $YSort_Entities/SpawnPoint

func _ready() -> void:
	# Amikor belépünk a házba, a Player-t azonnal a kézzel lerakott SpawnPoint-ra tesszük
	player.global_position = spawn_point.global_position
