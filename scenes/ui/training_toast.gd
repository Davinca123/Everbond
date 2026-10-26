extends Label

# Rövid felirat a képernyő tetején, amikor a lény tanulás közben halad
# ("Maradj-tanítás 3/5") vagy szintet lép (SignalBus.companion_skill_changed).

## Ennyi ideig látszik (mp), utána elhalványul
const SHOW_TIME: float = 2.5
const FADE_TIME: float = 0.4

var tween: Tween

func _ready() -> void:
	hide()
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SignalBus.companion_skill_changed.connect(_on_skill_changed)

func _on_skill_changed(skill: String, level: int, progress: int) -> void:
	var skill_name: String = tr("SKILL_" + skill.to_upper())
	if progress == 0:
		text = tr("UI_SKILL_LEVEL_UP") % [skill_name, level]
	else:
		text = tr("UI_TRAINING_PROGRESS") % [skill_name, progress, PlayerData.get_training_goal(skill)]
	show_toast()

func show_toast() -> void:
	if tween:
		tween.kill()
	modulate.a = 1.0
	show()
	tween = create_tween()
	tween.tween_interval(SHOW_TIME)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(hide)
