extends Node

# Hős statisztikák
var player_name: String = "Hős"
var current_health: int = 100
var max_health: int = 100
var gold: int = 0

# Ideiglenes inventory (egyelőre csak teszteléshez)
var inventory: Array[String] = []

# Jutalomfalatok a lénynek (pl. tanításhoz); a ládákban is találni
var treats: int = 5

func add_treats(amount: int) -> void:
	treats += amount
	SignalBus.treats_changed.emit(treats)

# Egy falatot elhasznál; hamisat ad, ha nincs több
func use_treat() -> bool:
	if treats <= 0:
		return false
	treats -= 1
	SignalBus.treats_changed.emit(treats)
	return true

# Mágikus lény (Companion) alapvető adatai
var companion_name: String = "Lélektárs"
var companion_obedience: int = 1
var companion_unlocked_skills: Array[String] = []

# A lény tudása (docs/companion-training-plan.md, 8. rész): képességenként szint és
# haladás (a sikeres ismétlések száma a következő szintig). Az első játszható szeletben
# csak a "maradj"-nak van feladata (scripts/training/stay_training.gd).
var companion_skills: Dictionary = {
	"range": { "level": 0, "progress": 0 },
	"stay": { "level": 0, "progress": 0 },
}

# Szintenkénti értékek (a számok ideiglenesek, játékteszttel hangolandók)
# A küldési távolság (px): a lény célja legfeljebb ennyire lehet a hős lábától (1. rész)
const COMPANION_SEND_RANGES: Array[float] = [500.0, 650.0, 800.0, 1000.0, 1200.0]
# A várakozás ideje (mp) egy koppintott helyen, mielőtt magától visszajön (3. rész)
const COMPANION_STAY_DURATIONS: Array[float] = [2.0, 3.0, 5.0, 8.0, 12.0]
# Ennyi sikeres ismétlés kell a következő szinthez (az n. elem: az n. szintről az n+1.-re)
const COMPANION_TRAINING_GOALS: Dictionary = {
	"range": [10, 20, 30, 40],
	"stay": [5, 10, 15, 20],
}

# Ha nagyobb 0-nál, ez a küldési távolság a szinttől függetlenül (tesztekhez, pl. az
# útkeresési tesztek a pálya távoli pontjaira küldik a lényt)
var companion_send_range_override: float = 0.0
# Ha nagyobb 0-nál, ez a várakozás ideje a szinttől függetlenül (tesztekhez)
var companion_stay_duration_override: float = 0.0

func get_companion_send_range() -> float:
	if companion_send_range_override > 0.0:
		return companion_send_range_override
	return level_value(COMPANION_SEND_RANGES, "range")

func get_companion_stay_duration() -> float:
	if companion_stay_duration_override > 0.0:
		return companion_stay_duration_override
	return level_value(COMPANION_STAY_DURATIONS, "stay")

func level_value(table: Array[float], skill: String) -> float:
	return table[clampi(companion_skills[skill].level, 0, table.size() - 1)]

# Hány sikeres ismétlés kell a következő szinthez; 0, ha a képesség már a legfelső szinten van
func get_training_goal(skill: String) -> int:
	var goals: Array = COMPANION_TRAINING_GOALS[skill]
	var level: int = companion_skills[skill].level
	return goals[level] if level < goals.size() else 0

# Egy sikeres ismétlés; ha megvan a szinthez kellő szám, szintet lép. Igazat ad, ha szintet lépett.
func add_training_progress(skill: String) -> bool:
	var goal: int = get_training_goal(skill)
	if goal == 0:
		return false
	companion_skills[skill].progress += 1
	if companion_skills[skill].progress >= goal:
		level_up_skill(skill)
		return true
	emit_skill_changed(skill)
	return false

func level_up_skill(skill: String) -> void:
	companion_skills[skill].level += 1
	companion_skills[skill].progress = 0
	emit_skill_changed(skill)

func emit_skill_changed(skill: String) -> void:
	SignalBus.companion_skill_changed.emit(skill, companion_skills[skill].level, companion_skills[skill].progress)

func heal(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)
	SignalBus.player_health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> void:
	current_health = clampi(current_health - amount, 0, max_health)
	SignalBus.player_health_changed.emit(current_health, max_health)
	if current_health <= 0:
		SignalBus.player_died.emit()
