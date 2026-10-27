extends Control

# A hős életereje a bal felső sarokban: piros csík a számmal (PlayerData, SignalBus.player_health_changed).

const BAR_HEIGHT: float = 34.0
const FONT_SIZE: int = 26
const BACKGROUND_COLOR: Color = Color(0, 0, 0, 0.5)
const BORDER_COLOR: Color = Color(0.95, 0.85, 0.6)
const HEALTH_COLOR: Color = Color(0.85, 0.2, 0.2)
const LOW_HEALTH_COLOR: Color = Color(1.0, 0.45, 0.2)
## Ez alatt (arány) narancsos a csík
const LOW_HEALTH: float = 0.25

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SignalBus.player_health_changed.connect(queue_redraw.unbind(2))
	SignalBus.language_changed.connect(queue_redraw.unbind(1))
	resized.connect(queue_redraw)

func _draw() -> void:
	var ratio: float = clampf(float(PlayerData.current_health) / PlayerData.max_health, 0.0, 1.0)
	var rect := Rect2(Vector2.ZERO, Vector2(size.x, BAR_HEIGHT))
	draw_rect(rect, BACKGROUND_COLOR)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), LOW_HEALTH_COLOR if ratio < LOW_HEALTH else HEALTH_COLOR)
	draw_rect(rect, BORDER_COLOR, false, 3.0)
	var text: String = "%s %d/%d" % [tr("HUD_HEALTH"), PlayerData.current_health, PlayerData.max_health]
	var font := get_theme_default_font()
	var at := Vector2(12, BAR_HEIGHT / 2.0 + FONT_SIZE * 0.35)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 6, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
