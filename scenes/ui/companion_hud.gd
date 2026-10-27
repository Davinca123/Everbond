extends Control

# A lény jelzője a jobb felső sarokban: egy kör, benne a róka (a lény sprite-ját másolja,
# így látszik, mit csinál), és a körből balra induló csíkok: hangulat és kötődés
# (CompanionState). A tanítás haladása a küldetés feliratán és a felugró feliraton látszik.

const RADIUS: float = 75.0
const RING_WIDTH: float = 6.0
const BAR_LENGTH: float = 380.0
const BAR_THICKNESS: float = 30.0
const BAR_SPACING: float = 42.0
const FONT_SIZE: int = 24
## Ennyi kötődésnél tele a kötődés csík (ideiglenes, amíg nincs kötődés szint)
const BOND_FULL: float = 50.0
# A róka mérete és helye a körben (a sprite képkockájában a róka kisebb, és lejjebb van)
const FOX_SCALE: float = 5.0
const FOX_OFFSET: Vector2 = Vector2(0, -9)

const BACKGROUND_COLOR: Color = Color(0.13, 0.1, 0.07, 0.75)
const RING_COLOR: Color = Color(0.95, 0.85, 0.6)
const BAR_BACKGROUND_COLOR: Color = Color(0, 0, 0, 0.45)
const MOOD_LOW_COLOR: Color = Color(0.85, 0.3, 0.25)
const MOOD_MID_COLOR: Color = Color(0.95, 0.8, 0.3)
const MOOD_HIGH_COLOR: Color = Color(0.45, 0.85, 0.35)
const BOND_COLOR: Color = Color(0.95, 0.45, 0.65)

var companion: Node2D
var fox: Sprite2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fox = Sprite2D.new()
	fox.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(fox)
	SignalBus.companion_mood_changed.connect(queue_redraw.unbind(1))
	SignalBus.companion_bond_changed.connect(queue_redraw.unbind(1))
	SignalBus.language_changed.connect(queue_redraw.unbind(1))
	resized.connect(queue_redraw)

func circle_center() -> Vector2:
	return Vector2(size.x - RADIUS, RADIUS)

func _process(_delta: float) -> void:
	if companion == null or not is_instance_valid(companion):
		companion = get_tree().get_first_node_in_group(&"companion")
		if companion == null:
			return
		var source: Sprite2D = companion.get_node("Sprite2D")
		fox.texture = source.texture
		fox.region_enabled = source.region_enabled
		fox.region_rect = source.region_rect
		fox.hframes = source.hframes
		fox.vframes = source.vframes
		fox.scale = Vector2.ONE * FOX_SCALE
	var sprite: Sprite2D = companion.get_node("Sprite2D")
	fox.frame = sprite.frame
	fox.flip_h = sprite.flip_h
	fox.position = circle_center() + FOX_OFFSET * FOX_SCALE

func _draw() -> void:
	var center := circle_center()
	var mood_ratio: float = (CompanionState.mood + 1.0) / 2.0
	var mood_color: Color = MOOD_LOW_COLOR.lerp(MOOD_MID_COLOR, mood_ratio * 2.0) if mood_ratio < 0.5 \
			else MOOD_MID_COLOR.lerp(MOOD_HIGH_COLOR, mood_ratio * 2.0 - 1.0)
	var rows: Array = [
		[tr("HUD_MOOD"), mood_ratio, mood_color],
		["%s %.0f" % [tr("HUD_BOND"), CompanionState.bond], minf(CompanionState.bond / BOND_FULL, 1.0), BOND_COLOR],
	]
	# A csíkok a kör szélétől indulnak balra, a kör alá bújva; a kitöltés is a körtől indul.
	# A bal végük egy vonalban van.
	var font := get_theme_default_font()
	for i in rows.size():
		var dy: float = (i - (rows.size() - 1) / 2.0) * BAR_SPACING
		var start_x: float = center.x - sqrt(RADIUS * RADIUS - dy * dy) + RING_WIDTH
		var top := Vector2(center.x - RADIUS - BAR_LENGTH, center.y + dy - BAR_THICKNESS / 2.0)
		var length: float = start_x - top.x
		draw_rect(Rect2(top, Vector2(length, BAR_THICKNESS)), BAR_BACKGROUND_COLOR)
		var filled: float = length * clampf(rows[i][1], 0.0, 1.0)
		draw_rect(Rect2(Vector2(start_x - filled, top.y), Vector2(filled, BAR_THICKNESS)), rows[i][2])
		var text_at := Vector2(top.x + 10, center.y + dy + FONT_SIZE * 0.35)
		draw_string_outline(font, text_at, rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 6, Color.BLACK)
		draw_string(font, text_at, rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
	draw_circle(center, RADIUS, BACKGROUND_COLOR)
	draw_arc(center, RADIUS - RING_WIDTH / 2.0, 0, TAU, 64, RING_COLOR, RING_WIDTH, true)
