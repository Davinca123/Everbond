extends SceneTree
# Teszt a lény buborékjához és a mondatok tárához (scenes/companion/speech_bubble.gd,
# companion_line_bank.gd, localization/companion_lines.csv).
#
# Futtatás (a projekt mappájából):
#   godot --headless --path . -s res://test/speech_test.gd
# Kilépési kód 0 = minden eset PASS.

const TRIGGERS: Array[StringName] = [&"sent", &"arrived", &"recalled", &"ignored_tap", &"stay_too_short", &"treat",
		&"training_progress", &"skill_level_up", &"gate_opened", &"bored", &"sage_hint"]

var failures: int = 0

func check(name: String, ok: bool, detail: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok: failures += 1

func _initialize() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	run.call_deferred()

func keys_of(bank: CompanionLineBank, trigger: StringName) -> Array:
	return bank.lines.filter(func(l): return l.trigger == trigger).map(func(l): return l.key)

func run() -> void:
	await create_timer(1.0).timeout
	var bus = root.get_node("SignalBus")
	var state = root.get_node("CompanionState")
	var map = root.get_node("SceneManager").current_map
	var comp = map.get_node("YSort_Entities/Companion")
	var bubble = comp.get_node("SpeechBubble")
	var bank: CompanionLineBank = bubble.bank

	# 1. A tár: minden helyzetre 2-3 mondat, és minden kulcsnak van szövege mindkét nyelven
	var counts: Dictionary = {}
	for t in TRIGGERS: counts[t] = keys_of(bank, t).size()
	var untranslated: Array[String] = []
	for line in bank.lines:
		for language in ["en", "hu"]:
			var translation := TranslationServer.get_translation_object(language)
			if translation == null or translation.get_message(line.key) == "":
				untranslated.append("%s:%s" % [language, line.key])
	var sizes_ok: bool = counts.values().all(func(c): return c >= 2 and c <= 4)
	check("bank_complete_and_translated", sizes_ok and bank.lines.size() >= 25 and untranslated.is_empty(),
			"lines=%d counts=%s untranslated=%s" % [bank.lines.size(), counts, untranslated])

	# 2. A helyzet jele a saját mondatai közül mutat egyet, a buborék a lény feje fölött van
	state.mood = 0.3; state.bond = 0.0
	bubble.last_line_time = -INF
	bus.companion_sent.emit(Vector2.ZERO)
	await process_frame
	check("trigger_shows_its_line", bubble.visible and bubble.current_key in keys_of(bank, &"sent")
			and bubble.panel.get_global_rect().end.y <= comp.get_node("Sprite2D").global_position.y,
			"visible=%s key=%s" % [bubble.visible, bubble.current_key])

	# 3. Beszédesség: 4 mp-en belül egy sima mondat nem jön, egy fontos igen
	var said_small: bool = bubble.say(&"treat")
	var said_important: bool = bubble.say(&"gate_opened")
	check("chattiness_gap", not said_small and said_important and bubble.current_key in keys_of(bank, &"gate_opened"),
			"small=%s important=%s key=%s" % [said_small, said_important, bubble.current_key])

	# 4. Feltételek: rossz hangulatban a visszahívásra csak a morcos mondat jöhet, jóban sosem
	var test_bank := CompanionLineBank.load_csv("res://localization/companion_lines.csv")
	var grumpy: Dictionary = {}
	var happy: Dictionary = {}
	for i in 30:
		test_bank.last_said.clear()
		grumpy[test_bank.pick(&"recalled", -0.8, 0.0, 0.0)] = true
		test_bank.last_said.clear()
		happy[test_bank.pick(&"recalled", 0.8, 0.0, 0.0)] = true
	check("mood_conditions", grumpy.keys() == ["COMP_RECALLED_3"] and not happy.has("COMP_RECALLED_3") and happy.size() == 2,
			"grumpy=%s happy=%s" % [grumpy.keys(), happy.keys()])

	# 5. Hűlés: amit nemrég mondott, azt kihagyja; ha mind hűl, nem mond semmit; utána újra
	test_bank.last_said.clear()
	var picked: Array[String] = []
	for i in 4: picked.append(test_bank.pick(&"ignored_tap", 0.0, 0.0, 100.0))
	var later: String = test_bank.pick(&"ignored_tap", 0.0, 0.0, 111.0)
	var distinct: bool = picked[0] != picked[1] and picked[1] != picked[2] and picked[0] != picked[2]
	check("cooldowns", distinct and picked[3] == "" and later != "", "picked=%s later=%s" % [picked, later])

	# 6. Súly és kötődés: a falatnál jó kedvben a harmadik mondat is előjön, rosszban soha
	var seen_best: bool = false
	var seen_best_grumpy: bool = false
	for i in 60:
		test_bank.last_said.clear()
		if test_bank.pick(&"treat", 0.8, 0.0, 0.0) == "COMP_TREAT_3": seen_best = true
		test_bank.last_said.clear()
		if test_bank.pick(&"treat", 0.0, 0.0, 0.0) == "COMP_TREAT_3": seen_best_grumpy = true
	check("weighted_pick_respects_mood", seen_best and not seen_best_grumpy, "happy=%s neutral=%s" % [seen_best, seen_best_grumpy])

	# 7. A buborék követi a lényt, és eltűnik
	bubble.last_line_time = -INF
	bus.companion_say.emit(&"arrived")
	var offset: Vector2 = bubble.panel.global_position - comp.global_position
	comp.global_position += Vector2(150, 40)
	await process_frame
	var followed: bool = (bubble.panel.global_position - comp.global_position).distance_to(offset) < 1.0
	await create_timer(bubble.SHOW_MAX + 0.5).timeout
	check("bubble_follows_and_hides", followed and not bubble.visible, "followed=%s visible=%s" % [followed, bubble.visible])

	# 8. Dialógus alatt nem beszél, és a dialógus elrejti a buborékot
	bubble.last_line_time = -INF
	bus.companion_say.emit(&"arrived")
	var shown_before: bool = bubble.visible
	bus.dialogue_started.emit("", (["DOOR_LOCKED"] as Array[String]))
	await process_frame
	var hidden_by_dialogue: bool = not bubble.visible
	bubble.last_line_time = -INF
	var said_during: bool = bubble.say(&"sage_hint")
	bus.dialogue_finished.emit()
	check("quiet_during_dialogue", shown_before and hidden_by_dialogue and not said_during,
			"shown=%s hidden=%s said=%s" % [shown_before, hidden_by_dialogue, said_during])

	# 9. Unalom: sokáig áll a hős mellett -> egyszer szól
	bubble.hide_line()
	bubble.last_line_time = -INF
	bubble.bored_said = false
	comp.idle_time = bubble.BORED_TIME + 1.0
	await process_frame
	var bored_key: String = bubble.current_key
	bubble.last_line_time = -INF
	bubble.hide_line()
	await process_frame
	check("bored_once", bored_key in keys_of(bank, &"bored") and bubble.current_key == "", "first=%s second=%s" % [bored_key, bubble.current_key])

	print("DONE: %d failure(s)" % failures)
	quit(1 if failures else 0)
