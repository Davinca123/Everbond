extends Node

# A "maradj" tanítása (docs/gameplay-plan.md, 10. rész, 7. lépés; docs/companion-training-plan.md, 8. rész).
# Egy sikeres ismétlés: a lényt elküldjük, kivárja a teljes időt (companion_stay_finished(full)),
# magától visszajön a hős mellé (companion_returned), és a hős TREAT_WINDOW mp-en belül
# falatot ad neki (treat_given). Ha a hős visszahívja, vagy túl messzire megy, nem számít.
# A feladat csak a lény jeleit figyeli, így a companion.gd-ben nincs tanítási kód.

const SKILL: String = "stay"
## A visszaérkezés után ennyi ideig számít a falat (mp)
const TREAT_WINDOW: float = 5.0

# Az aktuális küldésnél kivárta-e a teljes időt
var full_stay: bool = false
# Mikor ért vissza egy teljes várakozás után (mp); -INF, ha most nem jár falat a tanításért
var returned_at: float = -INF

func _ready() -> void:
	SignalBus.companion_sent.connect(func(_target): reset())
	SignalBus.companion_stay_finished.connect(func(full): full_stay = full)
	SignalBus.companion_returned.connect(_on_returned)
	SignalBus.treat_given.connect(_on_treat_given)

func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func reset() -> void:
	full_stay = false
	returned_at = -INF

func _on_returned() -> void:
	if full_stay:
		returned_at = now()
	full_stay = false

func _on_treat_given() -> void:
	if now() - returned_at > TREAT_WINDOW:
		return
	returned_at = -INF
	if PlayerData.get_training_goal(SKILL) == 0:
		return
	CompanionState.apply_event(&"training_success")
	if PlayerData.add_training_progress(SKILL):
		CompanionState.apply_event(&"skill_level_up")
		say.call_deferred(&"skill_level_up")
	else:
		say.call_deferred(&"training_progress")

# Késleltetve, hogy a falatra mondott sor ("Nyamm!") helyett ez látsszon
func say(trigger: StringName) -> void:
	SignalBus.companion_say.emit(trigger)
