extends Area2D

# Tető-zóna: amíg a hős a zónában (egy szoba belsejében) van, a tető elhalványul, hogy
# lássa a szobát; kilépve visszaáll. Csak a hőst figyeli: a kamera őt követi.
# (Az opacity_polygon_zone.gd az alagutakhoz való: ott a belépés a karakter ütközési
# rétegét is átállítja, ezért egy szobához ez az egyszerűbb zóna kell.)

## A halványítandó tető (vagy bármilyen CanvasItem)
@export var roof: CanvasItem
## A tető átlátszósága, amíg a hős bent van
@export var inside_opacity: float = 0.15
@export var fade_duration: float = 0.25

var player_inside: bool = false
var tween: Tween

func _ready() -> void:
	add_to_group("roof_zones")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_inside = true
		fade_to(inside_opacity)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_inside = false
		fade_to(1.0)

func fade_to(opacity: float) -> void:
	if roof == null:
		return
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(roof, "modulate:a", opacity, fade_duration)
