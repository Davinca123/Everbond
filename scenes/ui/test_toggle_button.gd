extends Button

# TESZT gomb a játékteszthez: a lény várakozási idejét vagy küldési távolságát kapcsolja
# a szint szerinti érték és a végtelen között (PlayerData.companion_*_override).
# Csak fejlesztői (debug) buildben látszik. Az új várakozási idő a következő megérkezéstől
# számít, mint egy szintlépésnél.

enum Setting { STAY, RANGE }

@export var setting: Setting = Setting.STAY

func _ready() -> void:
	visible = OS.is_debug_build()
	add_to_group("blocks_taps")
	# Ne kapjon fókuszt, különben a szóköz/Enter ("interact") is megnyomná
	focus_mode = Control.FOCUS_NONE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pressed.connect(_on_pressed)
	_update_text()

func is_infinite() -> bool:
	match setting:
		Setting.STAY:
			return is_inf(PlayerData.companion_stay_duration_override)
		_:
			return is_inf(PlayerData.companion_send_range_override)

func _on_pressed() -> void:
	var value: float = 0.0 if is_infinite() else INF
	match setting:
		Setting.STAY:
			PlayerData.companion_stay_duration_override = value
		Setting.RANGE:
			PlayerData.companion_send_range_override = value
	_update_text()

func _update_text() -> void:
	var setting_name: String = "Stay" if setting == Setting.STAY else "Range"
	text = "%s: %s" % [setting_name, "∞" if is_infinite() else "level"]
