extends Button

# IDEIGLENES nyelvváltó gomb, amíg nincs beállítások menü: minden megnyomás a
# következő nyelvre vált (Settings.LANGUAGES), a felirat a mostani nyelv kódja.
# A koppintásfelismerés (screen_ui.gd) a "blocks_taps" csoport miatt nem küldi el
# a lényt, ha a gombra koppintanak.

func _ready() -> void:
	add_to_group("blocks_taps")
	# Ne kapjon fókuszt, különben a szóköz/Enter ("interact") is megnyomná
	focus_mode = Control.FOCUS_NONE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pressed.connect(_on_pressed)
	SignalBus.language_changed.connect(func(_language): _update_text())
	_update_text()

func _update_text() -> void:
	text = Settings.language.to_upper()

func _on_pressed() -> void:
	var languages: Array[String] = Settings.LANGUAGES
	var next: int = (languages.find(Settings.language) + 1) % languages.size()
	Settings.set_language(languages[next])
