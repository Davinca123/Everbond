# companion_state.gd
extends Node

# A lény belső állapota (docs/companion-nature.md, 10. rész). Egyelőre csak a hangulat és
# a kötődés (az első játszható szelethez); a természet, a szükségletek, az érzések és az
# emlékek később jönnek.
#
# mood: -1 (nagyon rosszkedvű) … +1 (nagyon boldog); idővel visszatér a nyugalmi pontjához.
# bond: a kötődés a hőshöz, 0-tól felfelé.
# Az események (apply_event) a EVENTS táblából változtatják őket.

## A hangulat nyugalmi pontja (később a természet és a szükségletek állítják)
const MOOD_REST: float = 0.3
## Ennyivel közelít a hangulat másodpercenként a nyugalmi pontjához
const MOOD_DRIFT_PER_SECOND: float = 0.01
## A hangulat ennyi változásonként jelez a lassú visszatérés alatt (hogy ne minden képkockán)
const MOOD_SIGNAL_STEP: float = 0.01

# Esemény -> { "mood": változás, "bond": változás } (ideiglenes számok, játékteszttel hangolandók)
const EVENTS: Dictionary = {
	&"treat": { "mood": 0.15, "bond": 1.0 },
	&"training_success": { "mood": 0.1, "bond": 2.0 },
	&"skill_level_up": { "mood": 0.4, "bond": 5.0 },
	&"puzzle_solved": { "mood": 0.3, "bond": 3.0 },
	&"recalled": { "mood": -0.02, "bond": 0.0 },
	&"stay_too_short": { "mood": -0.1, "bond": 0.0 },
}

var mood: float = MOOD_REST
var bond: float = 0.0
var last_signalled_mood: float = MOOD_REST

func _ready() -> void:
	SignalBus.treat_given.connect(apply_event.bind(&"treat"))
	SignalBus.companion_recalled.connect(apply_event.bind(&"recalled"))

func apply_event(event: StringName) -> void:
	if not EVENTS.has(event):
		push_warning("CompanionState: ismeretlen esemény: %s" % event)
		return
	var effect: Dictionary = EVENTS[event]
	set_mood(mood + effect.get("mood", 0.0))
	var bond_change: float = effect.get("bond", 0.0)
	if bond_change != 0.0:
		bond = maxf(bond + bond_change, 0.0)
		SignalBus.companion_bond_changed.emit(bond)

func set_mood(value: float) -> void:
	mood = clampf(value, -1.0, 1.0)
	last_signalled_mood = mood
	SignalBus.companion_mood_changed.emit(mood)

func _process(delta: float) -> void:
	if mood == MOOD_REST:
		return
	mood = move_toward(mood, MOOD_REST, MOOD_DRIFT_PER_SECOND * delta)
	if absf(mood - last_signalled_mood) >= MOOD_SIGNAL_STEP or mood == MOOD_REST:
		last_signalled_mood = mood
		SignalBus.companion_mood_changed.emit(mood)
