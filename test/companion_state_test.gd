extends SceneTree
# Teszt a lény állapotához (CompanionState): az események a táblázat szerint változtatják
# a hangulatot és a kötődést, a hangulat visszatér a nyugalmi pontjához, és az F3 kijelző.
#
# Futtatás (a projekt mappájából):
#   godot --headless --path . -s res://test/companion_state_test.gd
# Kilépési kód 0 = minden eset PASS.

var failures: int = 0

func check(name: String, ok: bool, detail: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok: failures += 1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var state = root.get_node("CompanionState")
	var bus = root.get_node("SignalBus")
	var moods: Array[float] = []
	var bonds: Array[float] = []
	bus.companion_mood_changed.connect(func(m): moods.append(m))
	bus.companion_bond_changed.connect(func(b): bonds.append(b))

	# 1. Minden esemény a táblázat szerint változtat (semleges kiindulásból, hogy a vágás ne zavarjon)
	var wrong: Array[String] = []
	for event in state.EVENTS:
		state.mood = 0.0; state.bond = 10.0
		moods.clear(); bonds.clear()
		state.apply_event(event)
		var effect: Dictionary = state.EVENTS[event]
		var bond_signalled: bool = effect.bond == 0.0 or bonds == [10.0 + effect.bond]
		if not is_equal_approx(state.mood, effect.mood) or not is_equal_approx(state.bond, 10.0 + effect.bond) \
				or moods.size() != 1 or not bond_signalled:
			wrong.append("%s: mood=%.2f bond=%.1f" % [event, state.mood, state.bond])
	check("events_follow_table", wrong.is_empty() and state.EVENTS.size() == 6, str(wrong))

	# 2. Határok: a hangulat -1 és +1 között, a kötődés nem negatív
	state.mood = 0.95
	state.apply_event(&"skill_level_up")
	var capped_high: bool = state.mood == 1.0
	state.mood = -0.95
	for i in 3: state.apply_event(&"stay_too_short")
	check("mood_clamped", capped_high and state.mood == -1.0, "high=%s low=%.2f" % [capped_high, state.mood])

	# 3. A falat és a visszahívás jele magától eseményt ad
	state.mood = 0.0; state.bond = 0.0
	bus.treat_given.emit()
	var after_treat: float = state.mood
	bus.companion_recalled.emit()
	check("treat_and_recall_signals", is_equal_approx(after_treat, state.EVENTS[&"treat"].mood) and state.bond == state.EVENTS[&"treat"].bond \
			and state.mood < after_treat, "after_treat=%.2f now=%.2f bond=%.1f" % [after_treat, state.mood, state.bond])

	# 4. A hangulat lassan visszatér a nyugalmi pontjához, felülről és alulról is, és nem lő túl
	state.set_mood(state.MOOD_REST + 0.05)
	moods.clear()
	await create_timer(1.0).timeout
	var drifted_down: bool = state.mood < state.MOOD_REST + 0.05 and state.mood >= state.MOOD_REST
	await create_timer(5.0).timeout
	var rested: bool = state.mood == state.MOOD_REST
	state.set_mood(state.MOOD_REST - 0.02)
	await create_timer(3.0).timeout
	check("mood_drifts_to_rest", drifted_down and rested and state.mood == state.MOOD_REST and moods.size() >= 2 and moods.size() < 20,
			"down=%s rested=%s mood=%.3f signals=%d" % [drifted_down, rested, state.mood, moods.size()])

	# 5. F3: a fejlesztői kijelző megjelenik, és mutatja a hangulatot és a kötődést
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var overlay: Label = main.get_node("ScreenUI/DebugOverlay")
	var hidden_at_start: bool = not overlay.visible
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = KEY_F3; e.keycode = KEY_F3; e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame
	await process_frame
	check("debug_overlay_f3", hidden_at_start and overlay.visible and overlay.text.contains("mood") and overlay.text.contains("bond"),
			"hidden_at_start=%s visible=%s text=%s" % [hidden_at_start, overlay.visible, overlay.text.replace("\n", " | ")])

	print("DONE: %d failure(s)" % failures)
	quit(1 if failures else 0)
