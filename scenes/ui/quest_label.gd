extends PanelContainer

# A küldetés felirata a képernyő tetején: a címe és a teendő (SignalBus.quest_changed).
# Teljesítéskor egy ideig még látszik, utána elhalványul.

## Ennyi ideig látszik a "teljesítve" felirat (mp)
const DONE_SHOW_TIME: float = 4.0
const FADE_TIME: float = 0.5

var quest: Node
var title_label: Label
var text_label: Label
var tween: Tween

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build()
	SignalBus.quest_changed.connect(_on_quest_changed)
	SignalBus.language_changed.connect(func(_language): update_text())

func build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.1, 0.07, 0.75)
	style.border_color = Color(0.95, 0.85, 0.6)
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.content_margin_left = 28; style.content_margin_right = 28
	style.content_margin_top = 12; style.content_margin_bottom = 14
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	title_label = Label.new()
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title_label.add_theme_font_size_override("font_size", 30)
	text_label = Label.new()
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.add_theme_font_size_override("font_size", 36)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [title_label, text_label]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)

func _on_quest_changed(changed: Node) -> void:
	quest = changed
	update_text()
	if tween:
		tween.kill()
	modulate.a = 1.0
	if quest.stage == quest.Stage.DONE:
		tween = create_tween()
		tween.tween_interval(DONE_SHOW_TIME)
		tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
		tween.tween_callback(hide)

func update_text() -> void:
	if quest == null:
		return
	title_label.text = quest.title()
	text_label.text = quest.text()
	visible = quest.is_active() or quest.stage == quest.Stage.DONE
	# A magasság a szöveghez igazodik (a tördelés után)
	reset_size.call_deferred()
