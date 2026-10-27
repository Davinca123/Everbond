extends Node2D

# A kapus karám az első játszható szeletben (docs/gameplay-plan.md, 10. rész): a kapu
# eseményeiből a lény mondatai és a CompanionState eseményei lesznek, így a kapu, a
# nyomólap és a láda általános maradhat.
# - Ha a lény kivárta a teljes időt a lapon, de a kapu bezárult, mielőtt a hős átjutott
#   (a hős még a kapu előtt van): "Ennyi ideig még nem bírom…" (stay_too_short).
# - Ha a hős átjutott, és a retesz nyitva tartja a kaput: gate_opened, puzzle_solved.
# A küldetésnek (scripts/quests/gate_quest.gd) SignalBus.puzzle_event jeleket küld: "found",
# amikor a hős a kapu közelébe ér, "too_short" és "passed".

const PUZZLE: StringName = &"old_gate"
## Ennyire közel a kapunyíláshoz (px) "találta meg" a hős a kaput
const FOUND_DISTANCE: float = 450.0

## Ha a hős lába ennyire van a kapunyílás közepétől, amikor a kapu bezárul, "előtte" volt (px)
const NEAR_GATE_DISTANCE: float = 300.0
## Ennyi idővel a várakozás vége után nézzük meg, hogy bezárult-e előtte a kapu (mp)
const CLOSE_CHECK_DELAY: float = 0.3

@onready var gate: StaticBody2D = $Gate
@onready var plate: Area2D = $PressurePlate

# A hős most a kapu közelében van (a "found" csak a belépéskor megy)
var player_near: bool = false

func _ready() -> void:
	gate.latched_by_pass.connect(_on_latched_by_pass)
	SignalBus.companion_stay_finished.connect(_on_stay_finished)

func _physics_process(_delta: float) -> void:
	var companion: Node2D = get_tree().get_first_node_in_group(&"companion")
	if companion == null or not companion.is_inside_tree():
		return
	var feet: Node2D = companion.player.get_node("CollisionShape2D")
	var near: bool = feet.global_position.distance_to(gate.doorway_rect().get_center()) <= FOUND_DISTANCE
	if near and not player_near:
		SignalBus.puzzle_event.emit(PUZZLE, &"found")
	player_near = near

func _on_latched_by_pass() -> void:
	SignalBus.puzzle_event.emit(PUZZLE, &"passed")
	CompanionState.apply_event(&"puzzle_solved")
	SignalBus.companion_say.emit(&"gate_opened")

func _on_stay_finished(full: bool) -> void:
	var companion: Node2D = get_tree().get_first_node_in_group(&"companion")
	if not full or gate.latched or companion == null or not plate.is_on_plate(companion):
		return
	await get_tree().create_timer(CLOSE_CHECK_DELAY).timeout
	if not is_inside_tree() or gate.latched or gate.is_open:
		return
	var feet: Node2D = companion.player.get_node("CollisionShape2D")
	if feet.global_position.distance_to(gate.doorway_rect().get_center()) <= NEAR_GATE_DISTANCE:
		CompanionState.apply_event(&"stay_too_short")
		SignalBus.companion_say.emit(&"stay_too_short")
		SignalBus.puzzle_event.emit(PUZZLE, &"too_short")
