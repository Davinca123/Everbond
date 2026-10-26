extends Label

# Fejlesztői kijelző (F3, "toggle_debug"): a lény hangulata, kötődése és tudása,
# a játékteszthez és a hangoláshoz.

func _ready() -> void:
	hide()
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		get_viewport().set_input_as_handled()
		visible = not visible

func _process(_delta: float) -> void:
	if visible:
		text = describe()

func describe() -> String:
	var lines: Array[String] = [
		"mood %+.2f   bond %.1f" % [CompanionState.mood, CompanionState.bond],
		"treats %d   send range %.0f px" % [PlayerData.treats, PlayerData.get_companion_send_range()],
		"stay level %d (%.0f s)   training %d/%d" % [PlayerData.companion_skills.stay.level,
				PlayerData.get_companion_stay_duration(), PlayerData.companion_skills.stay.progress,
				PlayerData.get_training_goal("stay")],
	]
	return "\n".join(lines)
