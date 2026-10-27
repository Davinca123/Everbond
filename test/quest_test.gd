extends SceneTree
# Teszt az első küldetéshez (scripts/quests/gate_quest.gd), a feliratához
# (scenes/ui/quest_label.gd) és az életerő csíkhoz (scenes/ui/health_bar.gd).
#
# Futtatás (a projekt mappájából):
#   godot --headless --path . -s res://test/quest_test.gd
# Kilépési kód 0 = minden eset PASS.

var failures: int = 0

func check(name: String, ok: bool, detail: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok: failures += 1

func _initialize() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	run.call_deferred()

func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func put_player(player: Node2D, feet_at: Vector2) -> void:
	player.global_position = feet_at - player.get_node("CollisionShape2D").position
	for i in 3: await physics_frame

func run() -> void:
	await create_timer(1.0).timeout
	var bus = root.get_node("SignalBus")
	var data = root.get_node("PlayerData")
	var quest = root.get_node("Main/GateQuest")
	var label = root.get_node("Main/ScreenUI/QuestLabel")
	var map = root.get_node("SceneManager").current_map
	var player = map.get_node("YSort_Entities/Player")
	var npc = map.get_node("YSort_Entities/Npc")
	var gate = map.get_node("YSort_Entities/GatePen/Gate")
	root.get_node("Settings").set_language("en", false)

	# 1. Az elején nincs küldetés
	check("no_quest_at_start", quest.stage == quest.Stage.NOT_STARTED and not label.visible)

	# 2. A kapu megtalálása előtt nem lép (még nem beszélt a Bölcsel)
	bus.puzzle_event.emit(&"old_gate", &"found")
	check("found_before_sage_ignored", quest.stage == quest.Stage.NOT_STARTED)

	# 3. A Bölcs után: keresd meg a kaput
	await put_player(player, npc.global_position + Vector2(0, 60))
	bus.interaction_pressed.emit()
	await create_timer(0.3).timeout
	var dialogue: Control = root.get_node("Main/ScreenUI/DialogueBox")
	for i in 12:
		if not dialogue.visible: break
		await press("interact")
		await create_timer(0.1).timeout
	check("sage_starts_find_gate", quest.stage == quest.Stage.FIND_GATE and label.visible
			and label.text_label.text == "Find the old gate south-east of the Old Sage." and label.title_label.text == "The old gate",
			"stage=%d text=%s" % [quest.stage, label.text_label.text])

	# 4. A kapu közelében: küldd a lényt a lapra
	await put_player(player, gate.global_position + Vector2(0, 200))
	await create_timer(0.2).timeout
	check("near_gate_send_to_plate", quest.stage == quest.Stage.SEND_TO_PLATE and label.text_label.text.begins_with("Send your companion"),
			"stage=%d" % quest.stage)

	# 5. Túl rövid volt: tanítás, a haladással
	bus.puzzle_event.emit(&"old_gate", &"too_short")
	var train_text: String = label.text_label.text
	data.add_training_progress("stay")
	check("too_short_starts_training_with_progress", quest.stage == quest.Stage.TRAIN and train_text.ends_with("Training: 0/5")
			and label.text_label.text.ends_with("Training: 1/5"), "%s | %s" % [train_text, label.text_label.text])

	# 6. Nyelvváltáskor a felirat is vált
	root.get_node("Settings").set_language("hu", false)
	var hu_text: String = label.text_label.text
	root.get_node("Settings").set_language("en", false)
	check("label_follows_language", hu_text.ends_with("Tanítás: 1/5") and label.title_label.text == "The old gate", hu_text)

	# 7. Szintlépés után: menj át a kapun
	for i in 4: data.add_training_progress("stay")
	check("level_up_enter_gate", quest.stage == quest.Stage.ENTER and label.text_label.text.ends_with("Go through the gate!"),
			"stage=%d" % quest.stage)

	# 8. Lassú volt a hős magasabb szinten: nem kell újra tanítani
	bus.puzzle_event.emit(&"old_gate", &"too_short")
	check("too_short_at_level_1_stays", quest.stage == quest.Stage.ENTER)

	# 9. Átjutott: teljesítve, és a felirat elhalványul
	bus.puzzle_event.emit(&"old_gate", &"passed")
	var done_shown: bool = label.visible and label.text_label.text == "Quest completed!"
	await create_timer(label.DONE_SHOW_TIME + label.FADE_TIME + 0.3).timeout
	check("passed_completes_and_hides", quest.stage == quest.Stage.DONE and done_shown and not label.visible)

	# 10. Az életerő csík a bal felső sarokban, és a változásra újrarajzol
	var health = root.get_node("Main/ScreenUI/HealthBar")
	var rect: Rect2 = health.get_global_rect()
	data.take_damage(30)
	check("health_bar_top_left", rect.position.x < 60 and rect.position.y < 60 and rect.size.x > 300 and data.current_health == 70,
			"rect=%s health=%d" % [rect, data.current_health])
	data.heal(30)

	print("DONE: %d failure(s)" % failures)
	quit(1 if failures else 0)
