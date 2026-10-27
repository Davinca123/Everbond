extends Node2D

# Halvány kör a hős körül: a lény küldési távolsága (PlayerData.get_companion_send_range()).
# Ezen belülre lehet küldeni; ha egy cél kívülre kerül, a lény visszajön.
# A hős lábától mérünk (mint a companion.gd), ezért a kör közepe a láb.
# Végtelen távolságnál (teszt kapcsoló) nem rajzolunk.

const FILL_COLOR: Color = Color(1.0, 0.95, 0.75, 0.05)
const EDGE_COLOR: Color = Color(1.0, 0.95, 0.75, 0.35)
const EDGE_WIDTH: float = 4.0
const SEGMENTS: int = 96

var drawn_range: float = -1.0

@onready var feet: Node2D = get_parent().get_node("CollisionShape2D")

func _process(_delta: float) -> void:
	position = feet.position
	var send_range: float = PlayerData.get_companion_send_range()
	if send_range != drawn_range:
		drawn_range = send_range
		queue_redraw()

func _draw() -> void:
	if is_inf(drawn_range):
		return
	draw_circle(Vector2.ZERO, drawn_range, FILL_COLOR)
	draw_arc(Vector2.ZERO, drawn_range, 0, TAU, SEGMENTS, EDGE_COLOR, EDGE_WIDTH, true)
