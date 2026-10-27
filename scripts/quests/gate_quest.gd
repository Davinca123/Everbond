extends Node

# Az első küldetés, "A régi kapu" (docs/gameplay-plan.md, 10. rész). A szakaszait a
# SignalBus jeleiből tudja, a felirata a képernyő tetején van (scenes/ui/quest_label.gd).
#
# 1. Az Öreg Bölcs után: keresd meg a kaput.
# 2. A kapunál: küldd a lényt a nyomólapra, és menj át a kapun, amíg nyitva van.
# 3. Ha a kapu bezárult előtte (0. szinten): tanítsd a lényt maradni, a haladással (x/5).
# 4. Szintlépés után: menj át a kapun.
# 5. Átjutott: teljesítve. (Bármelyik szakaszból, pl. a végtelen várakozás teszt kapcsolóval.)

enum Stage { NOT_STARTED, FIND_GATE, SEND_TO_PLATE, TRAIN, ENTER, DONE }

const QUEST_GIVER: String = "NPC_OLD_SAGE_NAME"
const PUZZLE: StringName = &"old_gate"

var stage: Stage = Stage.NOT_STARTED

func _ready() -> void:
	SignalBus.npc_talked.connect(_on_npc_talked)
	SignalBus.puzzle_event.connect(_on_puzzle_event)
	SignalBus.companion_skill_changed.connect(_on_skill_changed)

func set_stage(value: Stage) -> void:
	stage = value
	SignalBus.quest_changed.emit(self)

func is_active() -> bool:
	return stage != Stage.NOT_STARTED and stage != Stage.DONE

func title() -> String:
	return tr("QUEST_GATE_TITLE")

# A felirat a mostani szakaszra (lefordítva)
func text() -> String:
	match stage:
		Stage.FIND_GATE:
			return tr("QUEST_GATE_FIND")
		Stage.SEND_TO_PLATE:
			return tr("QUEST_GATE_SEND")
		Stage.TRAIN:
			var stay: Dictionary = PlayerData.companion_skills.stay
			return tr("QUEST_GATE_TRAIN") % [stay.progress, PlayerData.get_training_goal("stay")]
		Stage.ENTER:
			return tr("QUEST_GATE_ENTER")
		Stage.DONE:
			return tr("QUEST_COMPLETED")
	return ""

func _on_npc_talked(npc_name: String) -> void:
	if npc_name == QUEST_GIVER and stage == Stage.NOT_STARTED:
		set_stage(Stage.FIND_GATE)

func _on_puzzle_event(puzzle: StringName, event: StringName) -> void:
	if puzzle != PUZZLE:
		return
	match event:
		&"found":
			if stage == Stage.FIND_GATE:
				set_stage(Stage.SEND_TO_PLATE)
		&"too_short":
			# Ha már magasabb szinten van, csak lassú volt a hős: marad a szakasz
			if stage in [Stage.FIND_GATE, Stage.SEND_TO_PLATE] and PlayerData.companion_skills.stay.level == 0:
				set_stage(Stage.TRAIN)
		&"passed":
			if is_active():
				set_stage(Stage.DONE)
			else:
				stage = Stage.DONE

func _on_skill_changed(skill: String, level: int, _progress: int) -> void:
	if stage != Stage.TRAIN or skill != "stay":
		return
	if level >= 1:
		set_stage(Stage.ENTER)
	else:
		SignalBus.quest_changed.emit(self) # a haladás (x/5) frissül
