@tool
extends StaticBody2D

# Egyetlen képből álló pályaelem (épület, fa, pad, lámpa ...). A csomópont a kép alsó
# szélének közepén van, így a YSort_Entities a talppontja szerint rendezi a karakterekkel.
# Az ütközés egy, a kép aljához igazított téglalap; a navigációs háló ebből sül ki.

## A kép (a csomópont skálája nagyítja, mint a csempéket)
@export var texture: Texture2D:
	set(value):
		texture = value
		_update()
## Az ütköző talp mérete a kép pixeleiben, a kép aljának közepéhez igazítva.
## (0, 0): az egész kép ütközik.
@export var footprint: Vector2 = Vector2.ZERO:
	set(value):
		footprint = value
		_update()

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_update()

func _update() -> void:
	if not is_node_ready():
		return
	sprite.texture = texture
	if texture == null:
		collision_shape.shape = null
		return
	var tex_size := texture.get_size()
	sprite.offset = Vector2(0, -tex_size.y / 2.0)
	var shape := RectangleShape2D.new()
	shape.size = footprint if footprint != Vector2.ZERO else tex_size
	collision_shape.shape = shape
	collision_shape.position = Vector2(0, -shape.size.y / 2.0)
