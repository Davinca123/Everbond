extends Node2D

# Lapos kőtető: kőlapokkal kitöltött téglalap, körben a falak kőkeretével (mint a pálya
# épületeinek teteje). A bal felső sarka a csomópont helye; a méret pixelben (a pálya léptékében).
# A RoofZone (opacity_zones/roof_zone.gd) halványítja el, amíg a hős bent van.

## A tető mérete (px)
@export var size: Vector2 = Vector2(742, 432)
## A textúrák nagyítása (mint a falaké)
@export var pixel_scale: float = 4.5

const FILL_TEXTURE: Texture2D = preload("res://assets/Pixel Art Top Down - Basic v1.2.3/Texture/TX Tileset Stone Ground.png")
const FILL_REGION: Rect2 = Rect2(0, 0, 96, 96)
const FRAME_TEXTURE: Texture2D = preload("res://assets/Pixel Art Top Down - Basic v1.2.3/Texture/TX Tileset Wall.png")
# A kőkeret a fal-tileset bal felső elemén: vékony perem, alul vastagabb párkány
const FRAME_REGION: Rect2 = Rect2(32, 32, 96, 83)
const FRAME_MARGINS: Array[float] = [8.0, 8.0, 8.0, 19.0] # bal, fent, jobb, lent

var frame: StyleBoxTexture

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame = StyleBoxTexture.new()
	frame.texture = FRAME_TEXTURE
	frame.region_rect = FRAME_REGION
	frame.texture_margin_left = FRAME_MARGINS[0]
	frame.texture_margin_top = FRAME_MARGINS[1]
	frame.texture_margin_right = FRAME_MARGINS[2]
	frame.texture_margin_bottom = FRAME_MARGINS[3]
	frame.draw_center = false
	queue_redraw()

func _draw() -> void:
	# A textúra pixeleiben rajzolunk, nagyítva
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * pixel_scale)
	var inner := size / pixel_scale
	var tile: Vector2 = FILL_REGION.size
	var y := 0.0
	while y < inner.y:
		var x := 0.0
		while x < inner.x:
			var part := Vector2(minf(tile.x, inner.x - x), minf(tile.y, inner.y - y))
			draw_texture_rect_region(FILL_TEXTURE, Rect2(Vector2(x, y), part), Rect2(FILL_REGION.position, part))
			x += tile.x
		y += tile.y
	draw_style_box(frame, Rect2(Vector2.ZERO, inner))
