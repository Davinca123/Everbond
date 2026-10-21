extends Node

# A játék egyetlen futó jelenete: a pályák a MapContainer-be töltődnek (SceneManager),
# a Player, a Companion és a ScreenUI végig életben marad.

## Ezzel a pályával indul a játék
@export_file("*.tscn") var start_map: String = "res://scenes/world/world.tscn"
## A kezdő pálya érkezési pontja (a Spawns alatt)
@export var start_spawn: StringName = &"default"

@onready var map_container: Node2D = $MapContainer
@onready var player: CharacterBody2D = $Player
@onready var companion: CharacterBody2D = $Companion
@onready var fade_rect: ColorRect = $Transition/FadeRect

func _ready() -> void:
	# Koppintásra a lény odamegy, ahová koppintottunk
	SignalBus.screen_tapped.connect(_on_screen_tapped)

	SceneManager.register_main(self)
	SceneManager.change_map(start_map, start_spawn, false)

# A képernyő pontot a kamera alapján világ koordinátává alakítjuk
func _on_screen_tapped(screen_position: Vector2) -> void:
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	companion.send_to_position(world_position)
