extends Node2D

# A lény beszél: buborék a feje fölött (docs/gameplay-plan.md, 10. rész, 6. lépés).
# A helyzeteket (trigger) a SignalBus jeleiből tudja, vagy bárki kérheti a
# SignalBus.companion_say(trigger) jellel. A mondatot a CompanionLineBank választja a
# hangulat és a kötődés (CompanionState) szerint.
# Beszédesség: két mondat között legalább CHATTINESS_GAP telik el, kivéve a fontosakat.
# Dialógus alatt nem beszél bele.

const LINES_PATH: String = "res://localization/companion_lines.csv"
## Ennyi idő legalább két mondat között (mp), kivéve a fontosakat
const CHATTINESS_GAP: float = 4.0
const IMPORTANT_TRIGGERS: Array[StringName] = [&"skill_level_up", &"gate_opened"]
## Ennyi ideig unatkozik egy helyben a hős mellett, mielőtt szól (mp)
const BORED_TIME: float = 20.0
# Ennyi ideig látszik a buborék: alap + karakterenként (mp)
const SHOW_BASE: float = 1.5
const SHOW_PER_CHARACTER: float = 0.05
const SHOW_MAX: float = 6.0
const MAX_WIDTH: float = 460.0

var bank: CompanionLineBank
var current_key: String = ""
var time_left: float = 0.0
var last_line_time: float = -INF
var dialogue_open: bool = false
var bored_said: bool = false

var panel: PanelContainer
var label: Label

@onready var companion: CharacterBody2D = get_parent()

func _ready() -> void:
	bank = CompanionLineBank.load_csv(LINES_PATH)
	build()
	hide()
	SignalBus.companion_say.connect(say)
	SignalBus.companion_sent.connect(func(_target): say(&"sent"))
	SignalBus.companion_arrived.connect(say.bind(&"arrived"))
	SignalBus.companion_recalled.connect(say.bind(&"recalled"))
	SignalBus.companion_tap_ignored.connect(say.bind(&"ignored_tap"))
	SignalBus.treat_given.connect(say.bind(&"treat"))
	SignalBus.dialogue_started.connect(func(_s, _l):
		dialogue_open = true
		hide_line())
	SignalBus.dialogue_finished.connect(func(): dialogue_open = false)

func build() -> void:
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.border_color = Color(0.25, 0.2, 0.15)
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	style.content_margin_left = 18; style.content_margin_right = 18
	style.content_margin_top = 10; style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	label = Label.new()
	label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	label.add_theme_font_size_override("font_size", 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	add_child(panel)

func now() -> float:
	return Time.get_ticks_msec() / 1000.0

# Mond valamit erre a helyzetre, ha van illő mondat, és most beszélhet. Igazat ad, ha mondott.
func say(trigger: StringName) -> bool:
	if dialogue_open:
		return false
	var important: bool = trigger in IMPORTANT_TRIGGERS
	if not important and now() - last_line_time < CHATTINESS_GAP:
		return false
	var key: String = bank.pick(trigger, CompanionState.mood, CompanionState.bond, now())
	if key == "":
		return false
	show_line(key)
	return true

func show_line(key: String) -> void:
	current_key = key
	last_line_time = now()
	label.text = key # a Label magától fordít, nyelvváltáskor is
	var text_length: int = tr(key).length()
	time_left = minf(SHOW_BASE + SHOW_PER_CHARACTER * text_length, SHOW_MAX)
	# Hosszú mondatnál tördelünk, a buborék legfeljebb MAX_WIDTH széles
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2.ZERO
	panel.reset_size()
	if panel.get_combined_minimum_size().x > MAX_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(MAX_WIDTH - 36, 0)
	panel.reset_size()
	show()
	place()

func hide_line() -> void:
	current_key = ""
	time_left = 0.0
	hide()

# A buborék alja középen a lény feje fölött van
func place() -> void:
	panel.position = Vector2(-panel.size.x / 2.0, -panel.size.y)

func _process(delta: float) -> void:
	update_boredom()
	if not visible:
		return
	time_left -= delta
	if time_left <= 0.0:
		hide_line()
	else:
		place()

# Ha sokáig áll egy helyben a hős mellett, egyszer szól; megmozdulva újra unatkozhat
func update_boredom() -> void:
	if companion.idle_time < BORED_TIME:
		bored_said = false
	elif not bored_said and not companion.is_away():
		bored_said = true
		say(&"bored")
