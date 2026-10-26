extends Node2D

# A kapus karám az első játszható szeletben (docs/gameplay-plan.md, 10. rész): a kapu
# eseményeiből a lény mondatai és a CompanionState eseményei lesznek, így a kapu, a
# nyomólap és a láda általános maradhat.
# - Ha a lény kivárta a teljes időt a lapon, de a kapu bezárult, mielőtt a hős átjutott
#   (a hős még a kapu előtt van): "Ennyi ideig még nem bírom…" (stay_too_short).
# - Ha a hős átjutott, és a retesz nyitva tartja a kaput: gate_opened, puzzle_solved.

## Ha a hős lába ennyire van a kapunyílás közepétől, amikor a kapu bezárul, "előtte" volt (px)
const NEAR_GATE_DISTANCE: float = 300.0
## Ennyi idővel a várakozás vége után nézzük meg, hogy bezárult-e előtte a kapu (mp)
const CLOSE_CHECK_DELAY: float = 0.3

@onready var gate: StaticBody2D = $Gate
@onready var plate: Area2D = $PressurePlate

func _ready() -> void:
	gate.latched_by_pass.connect(_on_latched_by_pass)
	SignalBus.companion_stay_finished.connect(_on_stay_finished)

func _on_latched_by_pass() -> void:
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
