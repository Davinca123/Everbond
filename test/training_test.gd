extends SceneTree
# Teszt a "maradj" tanításához (scripts/training/stay_training.gd, PlayerData.companion_skills):
# öt teljes ismétlés szintet léptet, a késő falat, a visszahívott küldés és a küldés nélküli
# falat nem számít, és az új várakozási idő a következő várakozástól érvényes.
#
# Futtatás (a projekt mappájából):
#   godot --headless --path . -s res://test/training_test.gd
# Kilépési kód 0 = minden eset PASS.

var failures: int = 0
var bus: Node
var data: Node
var state: Node
var player: CharacterBody2D
var comp: CharacterBody2D
var bubble: Node2D
var toast: Label
var returned: bool = false
var arrived: bool = false

func check(name: String, ok: bool, detail: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok: failures += 1

func _initialize() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	run.call_deferred()

func seconds(t: float) -> void:
	await create_timer(t).timeout

func wait_until(condition: Callable, timeout: float) -> bool:
	var t := 0.0
	while not condition.call() and t < timeout:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return condition.call()

func stay() -> Dictionary:
	return data.companion_skills.stay

# Elküldi a lényt a hős mellől, kivárja (vagy visszahívja), és megvárja, hogy visszaérjen
func send_and_return(full: bool) -> bool:
	await wait_until(func(): return not comp.is_away(), 6.0)
	arrived = false
	returned = false
	comp.send_to_position(player.global_position + Vector2(180, 0))
	await wait_until(func(): return arrived, 6.0)
	if not full:
		await seconds(0.3)
		bus.companion_recalled.emit()
	return await wait_until(func(): return returned, comp.stay_duration + 6.0)

# Falat a T billentyűvel, ahogy a játékos adná (a falat gomb csak akkor ad, ha a lény a hős mellett van)
func give_treat() -> void:
	await wait_until(func(): return comp.is_next_to_player(), 3.0)
	var event := InputEventAction.new()
	event.action = "give_treat"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func keys_of(trigger: StringName) -> Array:
	return bubble.bank.lines.filter(func(l): return l.trigger == trigger).map(func(l): return l.key)

func run() -> void:
	await seconds(1.0)
	bus = root.get_node("SignalBus")
	data = root.get_node("PlayerData")
	state = root.get_node("CompanionState")
	var map = root.get_node("SceneManager").current_map
	player = map.get_node("YSort_Entities/Player")
	comp = map.get_node("YSort_Entities/Companion")
	bubble = comp.get_node("SpeechBubble")
	toast = root.get_node("Main/ScreenUI/TrainingToast")
	bus.companion_arrived.connect(func(): arrived = true)
	bus.companion_returned.connect(func(): returned = true)
	root.get_node("Settings").set_language("en", false)
	data.treats = 50
	var skill_changes: Array = []
	bus.companion_skill_changed.connect(func(s, l, p): skill_changes.append([s, l, p]))

	# 1. Egy teljes ismétlés: haladás, felirat, a lény sora és a CompanionState esemény
	var bond_before: float = state.bond
	var came_back: bool = await send_and_return(true)
	await give_treat()
	await process_frame
	check("full_run_counts", came_back and stay().progress == 1 and stay().level == 0 and skill_changes == [["stay", 0, 1]],
			"returned=%s stay=%s changes=%s" % [came_back, stay(), skill_changes])
	check("feedback_toast_line_and_state", toast.visible and toast.text == "Stay training 1/5"
			and bubble.current_key in keys_of(&"training_progress")
			and is_equal_approx(state.bond - bond_before, state.EVENTS[&"treat"].bond + state.EVENTS[&"training_success"].bond),
			"toast=%s '%s' key=%s bond+%.1f" % [toast.visible, toast.text, bubble.current_key, state.bond - bond_before])

	# 2. Késő falat: TREAT_WINDOW után már nem számít
	await send_and_return(true)
	await seconds(root.get_node("Main/StayTraining").TREAT_WINDOW + 0.5)
	await give_treat()
	check("late_treat_does_not_count", stay().progress == 1, str(stay()))

	# 3. Visszahívott küldés: nem várta ki a teljes időt, nem számít
	await send_and_return(false)
	await give_treat()
	check("recalled_stay_does_not_count", stay().progress == 1, str(stay()))

	# 4. Falat küldés nélkül (egy számított falat után a második sem számít)
	await give_treat()
	check("treat_without_send_does_not_count", stay().progress == 1, str(stay()))

	# 5. Még négy teljes ismétlés: az ötödik szintet léptet, 2 mp -> 3 mp
	var durations: Array[float] = []
	for i in 4:
		await send_and_return(true)
		durations.append(comp.stay_duration)
		await give_treat()
	check("five_successes_level_up", stay().level == 1 and stay().progress == 0 and skill_changes.back() == ["stay", 1, 0]
			and toast.text == "Stay: level 1!" and bubble.current_key in keys_of(&"skill_level_up"),
			"stay=%s last=%s toast='%s' key=%s" % [stay(), skill_changes.back(), toast.text, bubble.current_key])

	# 6. Az új idő a következő várakozástól érvényes
	await send_and_return(true)
	check("new_duration_from_next_wait", durations.all(func(d): return d == 2.0) and comp.stay_duration == 3.0
			and data.get_training_goal("stay") == 10, "before=%s now=%.1f goal=%d" % [durations, comp.stay_duration, data.get_training_goal("stay")])

	# 7. A legfelső szinten nincs több haladás
	stay().level = data.COMPANION_STAY_DURATIONS.size() - 1
	var leveled: bool = data.add_training_progress("stay")
	check("max_level_stops", not leveled and stay().progress == 0 and data.get_companion_stay_duration() == data.COMPANION_STAY_DURATIONS.back(),
			str(stay()))

	print("DONE: %d failure(s)" % failures)
	quit(1 if failures else 0)
