extends SceneTree
# Teszt a fordításokhoz: minden kulcs le van fordítva minden nyelvre, és a gomb felirata,
# a dialógus és a nyelvválasztás a kiválasztott nyelvet mutatja.
#
# Futtatás (a projekt mappájából):
#   godot --headless --path . -s res://test/localization_test.gd
# Kilépési kód 0 = minden eset PASS.

var failures: int = 0

func check(name: String, ok: bool, detail: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok: failures += 1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var settings = root.get_node("Settings")
	var bus = root.get_node("SignalBus")
	var previous_language: String = settings.language

	# 1. Minden kulcsnak van szövege minden nyelven (a CSV nem hiányos)
	var keys: Array[String] = []
	var csv := FileAccess.open("res://localization/texts.csv", FileAccess.READ)
	csv.get_csv_line() # fejléc
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() > 1 and row[0] != "":
			keys.append(row[0])
	var missing: Array[String] = []
	for language in settings.LANGUAGES:
		var translation := TranslationServer.get_translation_object(language)
		for k in keys:
			if translation == null or translation.get_message(k) == "":
				missing.append("%s:%s" % [language, k])
	check("all_keys_translated", keys.size() > 0 and missing.is_empty(), "keys=%d missing=%s" % [keys.size(), missing])

	# 2. A gomb felirata és a dialógus a kiválasztott nyelven
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var label: Label = main.get_node("ScreenUI/InteractionButtonAnchor/InteractionButton/Label")
	var dialogue = main.get_node("ScreenUI/DialogueBox")

	settings.set_language("hu", false)
	bus.show_interaction_button.emit("chat")
	await process_frame
	var hu_label: String = tr_label(label)
	settings.set_language("en", false)
	await process_frame
	var en_label: String = tr_label(label)
	check("button_label_follows_language", hu_label == "Beszéd" and en_label == "Talk", "hu=%s en=%s" % [hu_label, en_label])

	bus.dialogue_started.emit("NPC_OLD_SAGE_NAME", (["NPC_OLD_SAGE_GREETING_1"] as Array[String]))
	await process_frame
	var name_en: String = dialogue.name_label.text
	var text_en: String = dialogue.text_label.text
	check("dialogue_translated", name_en == "Old Sage" and text_en == "Welcome, traveller!", "name=%s text=%s" % [name_en, text_en])

	# 3. Az ideiglenes nyelvváltó gomb: koppintásra a következő nyelvre vált, a felirata
	# követi, és a koppintás nem küldi el a lényt
	bus.dialogue_finished.emit()
	dialogue.hide()
	var button: Button = main.get_node("ScreenUI/LanguageButton")
	var taps: Array[int] = [0]
	bus.screen_tapped.connect(func(_p): taps[0] += 1)
	settings.set_language("en", false)
	var window_pos: Vector2 = button.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0; e.position = window_pos; e.pressed = pressed
		Input.parse_input_event(e)
		for i in 3: await physics_frame
	check("language_button_switches", settings.language == "hu" and button.text == "HU" and taps[0] == 0,
			"language=%s text=%s taps=%d" % [settings.language, button.text, taps[0]])

	# 4. Ismeretlen nyelv: az alapértelmezett (angol) lesz
	settings.set_language("xx", false)
	check("unknown_language_falls_back", settings.language == "en" and TranslationServer.get_locale() == "en",
			"language=%s locale=%s" % [settings.language, TranslationServer.get_locale()])

	# A gomb el is mentette a nyelvet, ezért a régit mentjük vissza
	settings.set_language(previous_language)
	print("DONE: %d failure(s)" % failures)
	quit(1 if failures else 0)

# A Label a kulcsot rajzoláskor fordítja; a látható szöveg a lefordított kulcs
func tr_label(label: Label) -> String:
	return label.atr(label.text)
