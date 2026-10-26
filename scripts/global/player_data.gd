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

# A küldési távolság (px) szintenként: a lény célja legfeljebb ennyire lehet a hős lábától
# (docs/companion-training-plan.md, 1. és 8. rész; a számok ideiglenesek)
const COMPANION_SEND_RANGES: Array[float] = [500.0, 650.0, 800.0, 1000.0, 1200.0]
var companion_range_level: int = 0
# Ha nagyobb 0-nál, ez a küldési távolság a szinttől függetlenül (tesztekhez, pl. az
# útkeresési tesztek a pálya távoli pontjaira küldik a lényt)
var companion_send_range_override: float = 0.0

func get_companion_send_range() -> float:
	if companion_send_range_override > 0.0:
		return companion_send_range_override
	return COMPANION_SEND_RANGES[clampi(companion_range_level, 0, COMPANION_SEND_RANGES.size() - 1)]

func heal(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)
	SignalBus.player_health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> void:
	current_health = clampi(current_health - amount, 0, max_health)
	SignalBus.player_health_changed.emit(current_health, max_health)
	if current_health <= 0:
		SignalBus.player_died.emit()
