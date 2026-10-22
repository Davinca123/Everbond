@tool
extends Area2D

# Pályaszéli kijárat: amint a hős belelép a sávba, gombnyomás nélkül átvált a célpályára.
# Az érkezési pontot a célpályán a saját kijáratától kicsit beljebb tedd, különben a hős
# rögtön visszapattan.

## A pálya, ahová a kijárat vezet (pl. res://scenes/maps/world/town.tscn)
@export_file("*.tscn") var target_map: String = ""
## Az érkezési pont neve a célpálya Spawns csomópontja alatt (pl. &"from_world")
@export var target_spawn: StringName = &"default"
## A sáv mérete pixelben; a csomópont a sáv közepe
@export var size: Vector2 = Vector2(80, 640):
	set(value):
		size = value
		_update_shape()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_update_shape()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)

func _update_shape() -> void:
	if not is_node_ready():
		return
	# Saját alakzat példányonként, hogy a kijáratok mérete ne írja felül egymást
	var shape := RectangleShape2D.new()
	shape.size = size
	collision_shape.shape = shape

func _on_body_entered(body: Node2D) -> void:
	if body != SceneManager.main.player or target_map == "":
		return
	SceneManager.change_map(target_map, target_spawn)
