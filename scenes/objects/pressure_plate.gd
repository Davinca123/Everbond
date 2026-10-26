extends Area2D

# Nyomólap: le van nyomva, amíg a hős vagy a lény (később egy láda) rajta áll. A lábnak
# (az ütközési alakzat közepének) a lap közepén kell lennie, nem elég a szélét súrolni,
# így a lap akkor nyomódik le, amikor a lény tényleg odaért.
# A csomópont a lap fölött van (CENTER_OFFSET-tel), hogy a rajta álló karakterek az
# Y-rendezésben fölé kerüljenek (mint a lény céljelölője).

signal pressed_changed(pressed: bool)

## A lap közepe körül ekkora téglalapban kell állnia a lábnak (px)
@export var press_size: Vector2 = Vector2(110, 60)
## Ennyire közel koppintva a lény a lap közepére megy (lásd companion.gd, snap_to_spot)
@export var snap_radius: float = 90.0

const CENTER_OFFSET: Vector2 = Vector2(0, 80)
const PRESSERS: Array[StringName] = [&"Player", &"Companion"]
const PRESSED_COLOR: Color = Color(0.75, 1.15, 1.35)

var pressed: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group(&"companion_spots")

# A lap közepe (globálisan)
func center() -> Vector2:
	return to_global(CENTER_OFFSET)

func _physics_process(_delta: float) -> void:
	var now: bool = false
	for body in get_overlapping_bodies():
		if body.name in PRESSERS and is_on_plate(body):
			now = true
			break
	if now != pressed:
		pressed = now
		sprite.modulate = PRESSED_COLOR if pressed else Color.WHITE
		sprite.position = CENTER_OFFSET + (Vector2(0, 3) if pressed else Vector2.ZERO)
		pressed_changed.emit(pressed)

func is_on_plate(body: Node2D) -> bool:
	var feet: Node2D = body.get_node_or_null("CollisionShape2D")
	var at: Vector2 = feet.global_position if feet else body.global_position
	return Rect2(center() - press_size / 2.0, press_size).has_point(at)
