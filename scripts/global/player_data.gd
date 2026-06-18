extends Node

# Hős statisztikák
var player_name: String = "Hős"
var current_health: int = 100
var max_health: int = 100
var gold: int = 0

# Ideiglenes inventory (egyelőre csak teszteléshez)
var inventory: Array[String] = []

# Mágikus lény (Companion) alapvető adatai
var companion_name: String = "Lélektárs"
var companion_obedience: int = 1
var companion_unlocked_skills: Array[String] = []

func heal(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)
	SignalBus.player_health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> void:
	current_health = clampi(current_health - amount, 0, max_health)
	SignalBus.player_health_changed.emit(current_health, max_health)
	if current_health <= 0:
		SignalBus.player_died.emit()
