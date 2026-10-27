extends SceneTree
# Plays the first playable slice, "the dragon and the gate" (docs/gameplay-plan.md, section 10),
# the way a player would: talk to the Old Sage, try the gate with the companion on the plate
# at stay level 0 (too short), train stay five times with treats, get through at level 1,
# and open the chest. The quest label follows each step.
# Screenshots go to $OUT. Exit code 0 = every check passed.
#
#   OUT=.claude/tmp/screenshots/slice timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" \
#     "$G" --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
#     --audio-driver Dummy -s .claude/skills/run-game/slice_playthrough.gd

var out := OS.get_environment("OUT")
var checks := 0
var failed := 0
var shot_n := 0
var quest; var map; var player; var comp; var bubble; var npc; var pen; var gate; var plate; var chest
var returned := false

func _initialize() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	run.call_deferred()

func bus(): return root.get_node("SignalBus")
func data(): return root.get_node("PlayerData")

func check(name: String, ok: bool, info := "") -> void:
	checks += 1
	if not ok: failed += 1
	print("CHECK %-45s %s %s" % [name, "PASS" if ok else "FAIL", info])

func shot(tag: String) -> void:
	if out == "": return
	await RenderingServer.frame_post_draw
	shot_n += 1
	root.get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [out, shot_n, tag])

func seconds(t: float) -> void:
	await create_timer(t).timeout

func wait_until(condition: Callable, timeout: float) -> bool:
	var t := 0.0
	while not condition.call() and t < timeout:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return condition.call()

func feet(body: Node2D) -> Vector2:
	return body.get_node("CollisionShape2D").global_position

# Puts the player's feet at a point, with the companion beside them, following
func put_player(at: Vector2) -> void:
	player.global_position = at - player.get_node("CollisionShape2D").position
	comp.global_position = player.global_position + Vector2(-70, 0)
	comp.on_map_entered()
	await seconds(0.6)

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

# A tap on the screen at a world point, as the touch UI sends it
func tap_world(at: Vector2) -> void:
	bus().screen_tapped.emit(root.get_viewport().get_canvas_transform() * at)

func run() -> void:
	await seconds(1.5)
	map = root.get_node("SceneManager").current_map
	player = map.get_node("YSort_Entities/Player")
	comp = map.get_node("YSort_Entities/Companion")
	bubble = comp.get_node("SpeechBubble")
	npc = map.get_node("YSort_Entities/Npc")
	pen = map.get_node("YSort_Entities/GatePen")
	gate = pen.get_node("Gate"); plate = pen.get_node("PressurePlate"); chest = pen.get_node("Chest")
	quest = root.get_node("Main/GateQuest")
	root.get_node("Settings").set_language("en", false)
	bus().companion_returned.connect(func(): returned = true)
	var treats_at_start: int = data().treats

	# 1. The Old Sage tells about the gate; afterwards the companion answers
	await put_player(npc.global_position + Vector2(0, 60))
	bus().interaction_pressed.emit()
	await seconds(0.3)
	var lines_seen: Array = []
	var dialogue: Control = root.get_node("Main/ScreenUI/DialogueBox")
	for i in 12:
		if not dialogue.visible: break
		var line: String = dialogue.dialog_lines[dialogue.current_line_index]
		if line not in lines_seen: lines_seen.append(line)
		if line == "NPC_OLD_SAGE_GATE_HINT": await shot("sage_hint")
		await press("interact")
		await seconds(0.15)
	await seconds(0.2)
	check("sage tells about the gate", "NPC_OLD_SAGE_GATE_HINT" in lines_seen and not dialogue.visible, str(lines_seen))
	check("quest: find the gate", quest.stage == quest.Stage.FIND_GATE, quest.text())
	check("companion answers the sage", bubble.visible and bubble.current_key.begins_with("COMP_SAGE_HINT"), bubble.current_key)
	await shot("companion_answers")

	# 2. At the gate, stay level 0: the companion holds the plate, the gate opens slowly,
	#    the player runs for it, and it shuts in front of them
	var gate_front: Vector2 = gate.global_position + Vector2(0, 40)
	await put_player(gate_front)
	check("quest: send the companion to the plate", quest.stage == quest.Stage.SEND_TO_PLATE, quest.text())
	bubble.last_line_time = -INF
	tap_world(plate.center())
	var opened: bool = await wait_until(func(): return gate.is_open, 6.0)
	await shot("level0_gate_open")
	bus().joystick_moved.emit(Vector2.UP)
	await wait_until(func(): return not gate.is_open or gate.latched, 4.0)
	await seconds(0.5)
	bus().joystick_moved.emit(Vector2.ZERO)
	await seconds(0.3)
	var through: bool = feet(player).y < gate.doorway_rect().position.y
	check("level 0: gate opens with the companion on the plate", opened)
	check("level 0: too short, the player is pushed back", not through and not gate.latched, "player_y=%.0f" % feet(player).y)
	check("level 0: companion says its stay was too short", bubble.current_key.begins_with("COMP_STAY_TOO_SHORT"), bubble.current_key)
	check("quest: train, with progress", quest.stage == quest.Stage.TRAIN and quest.text().ends_with("0/5"), quest.text())
	await shot("level0_too_short")
	await wait_until(func(): return not comp.is_away(), 6.0)

	# 3. Training next to the gate: send, let it wait, give a treat when it's back (T). Five times.
	var training_spot: Vector2 = gate_front + Vector2(-220, 120)
	await put_player(training_spot)
	for i in 5:
		await wait_until(func(): return not comp.is_away(), 6.0)
		returned = false
		tap_world(training_spot + Vector2(200, 0))
		var back: bool = await wait_until(func(): return returned, 10.0)
		await wait_until(func(): return comp.is_next_to_player(), 3.0)
		await press("give_treat")
		await seconds(0.3)
		if i == 2: await shot("training_3_of_5")
		if not back: print("  training run %d: companion did not come back" % (i + 1))
	var stay: Dictionary = data().companion_skills.stay
	check("five trainings raise stay to level 1", stay.level == 1 and data().get_companion_stay_duration() == 3.0, str(stay))
	check("companion celebrates the level up", bubble.current_key.begins_with("COMP_SKILL_LEVEL_UP"), bubble.current_key)
	check("quest: enter the gate", quest.stage == quest.Stage.ENTER, quest.text())
	await shot("level_up")
	await seconds(2.0)

	# 4. Again at level 1: the player gets through, the latch holds the gate, the companion follows
	await put_player(gate_front)
	bubble.last_line_time = -INF
	tap_world(plate.center())
	await wait_until(func(): return gate.is_open, 6.0)
	bus().joystick_moved.emit(Vector2.UP)
	await wait_until(func(): return not gate.is_open or gate.latched, 4.0)
	await seconds(0.5)
	bus().joystick_moved.emit(Vector2.ZERO)
	through = feet(player).y < gate.doorway_rect().position.y
	check("level 1: the player gets through and the gate latches", through and gate.latched and gate.is_open, "player_y=%.0f" % feet(player).y)
	check("level 1: companion cheers the open gate", bubble.current_key.begins_with("COMP_GATE_OPENED"), bubble.current_key)
	check("quest: completed", quest.stage == quest.Stage.DONE, quest.text())
	await shot("level1_through")
	var followed: bool = await wait_until(func(): return not comp.is_away() and feet(comp).y < gate.doorway_rect().position.y, 10.0)
	check("companion follows through the latched gate", followed, "comp_y=%.0f" % feet(comp).y)

	# 5. The chest holds more treats
	var treats_before: int = data().treats
	await put_player(chest.global_position + Vector2(0, 50))
	bus().interaction_pressed.emit()
	await seconds(0.3)
	await shot("chest")
	check("chest opens and gives five treats", chest.is_open and data().treats == treats_before + 5,
			"treats %d -> %d (start %d)" % [treats_before, data().treats, treats_at_start])
	for i in 4:
		if not dialogue.visible: break
		await press("interact")
		await seconds(0.15)

	print("RESULT %d checks, %d failed" % [checks, failed])
	quit(1 if failed else 0)
