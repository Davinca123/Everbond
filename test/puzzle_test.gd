extends SceneTree
# Teszt a nyomólaphoz, a kapuhoz és a ládához (World, GatePen; docs/gameplay-plan.md, 10. rész).
#
# Futtatás (a projekt mappájából):
#   godot --headless --path . -s res://test/puzzle_test.gd
# Kilépési kód 0 = minden eset PASS.

var failures: int = 0
var map; var player; var comp; var pen; var plate; var gate; var chest

func check(name: String, ok: bool, detail: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok: failures += 1

func _initialize() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	run.call_deferred()

func seconds(t: float) -> void:
	await create_timer(t, true, true).timeout

func frames(n: int) -> void:
	for i in n: await physics_frame

func bus(): return root.get_node("SignalBus")

func find_nodes() -> void:
	map = root.get_node("SceneManager").current_map
	player = map.get_node("YSort_Entities/Player"); comp = map.get_node("YSort_Entities/Companion")
	pen = map.get_node("YSort_Entities/GatePen")
	plate = pen.get_node("PressurePlate"); gate = pen.get_node("Gate"); chest = pen.get_node("Chest")

# A hős lába (ütközési alakzata) ide kerüljön
func put_player(feet_at: Vector2) -> void:
	player.global_position = feet_at - player.get_node("CollisionShape2D").position
	await frames(3)

# A lény a hős mellé, követő állapotba
func reset_companion() -> void:
	comp.global_position = player.global_position + Vector2(-80, 0)
	comp.on_map_entered()
	root.get_node("PlayerData").companion_skills.stay.level = 0
	root.get_node("PlayerData").companion_stay_duration_override = 0.0
	await frames(3)

func wait_until(condition: Callable, timeout: float) -> bool:
	var t := 0.0
	while not condition.call() and t < timeout:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return condition.call()

func change_map(path: String, spawn: StringName) -> void:
	root.get_node("SceneManager").change_map(path, spawn)
	await seconds(1.5)

func run() -> void:
	await seconds(1.0)
	find_nodes()
	var gate_front: Vector2 = gate.global_position + Vector2(0, 40)

	# 1. A hős a lapra áll: lenyomódik; lelép: felenged. A kapu lassan nyílik, és azonnal zárul.
	await put_player(plate.center())
	var pressed_by_player: bool = plate.pressed
	var half_open: bool = false
	await seconds(gate.open_time * 0.5)
	half_open = gate.progress > 0.3 and gate.progress < 0.7 and not gate.is_open
	await seconds(gate.open_time * 0.5 + 0.2)
	var opened: bool = gate.is_open and gate.collision_shape.disabled
	await put_player(plate.center() + Vector2(0, 200))
	await frames(3)
	check("plate_and_gate_with_player", pressed_by_player and half_open and opened and not plate.pressed and not gate.is_open \
			and gate.progress == 0.0, "pressed=%s half_open=%s opened=%s released=%s closed=%s" % [pressed_by_player,
			half_open, opened, not plate.pressed, not gate.is_open])

	# 2. A lényt a lap közelébe küldjük: a lap közepére megy, lenyomja, a várakozás végén
	# lelép, és a lap felenged
	await put_player(gate_front + Vector2(-150, 60))
	await reset_companion()
	comp.send_to_position(plate.center() + Vector2(40, -25))
	var snapped: bool = comp.click_target_pos.distance_to(plate.center()) < 2.0
	var pressed_by_companion: bool = await wait_until(func(): return plate.pressed, 4.0)
	await wait_until(func(): return comp.current_state == comp.State.IDLE, 2.0)
	var held_while_waiting: bool = plate.pressed
	var released: bool = await wait_until(func(): return not plate.pressed, comp.stay_duration + 2.0)
	check("plate_with_companion", snapped and pressed_by_companion and held_while_waiting and released and comp.current_state == comp.State.FOLLOW,
			"snapped=%s pressed=%s held=%s released=%s state=%d" % [snapped, pressed_by_companion, held_while_waiting, released, comp.current_state])
	await wait_until(func(): return not comp.is_away(), 4.0)

	# 3. Időzítés: a hős a kapu előtt vár, és amint kinyílik, nekiindul. 2 mp várakozással
	# (0. szint) nem jut át, a kapu kitolja; 3 mp-vel (1. szint) átjut, és a retesz nyitva tartja.
	var through: Dictionary = {}
	for stay in [2.0, 3.0]:
		await put_player(gate_front)
		await reset_companion()
		root.get_node("PlayerData").companion_skills.stay.level = 0 if stay == 2.0 else 1
		comp.send_to_position(plate.center())
		await wait_until(func(): return gate.is_open, 6.0)
		bus().joystick_moved.emit(Vector2.UP)
		await wait_until(func(): return not gate.is_open or gate.latched, 4.0)
		await seconds(0.5)
		bus().joystick_moved.emit(Vector2.ZERO)
		through[stay] = player.global_position.y < gate.doorway_rect().position.y
		if stay == 2.0:
			var pushed_back: bool = player.global_position.y > gate.doorway_rect().end.y and not gate.is_open and not gate.latched
			check("stay_level_0_too_short", not through[stay] and pushed_back,
					"through=%s player_y=%.0f doorway=%s" % [through[stay], player.global_position.y, gate.doorway_rect()])
		await wait_until(func(): return not comp.is_away(), 8.0)
	check("stay_level_1_gets_through_and_latches", through[3.0] and gate.latched and gate.is_open and gate.collision_shape.disabled,
			"through=%s latched=%s open=%s" % [through[3.0], gate.latched, gate.is_open])

	# 4. A ládát a hős egyszer nyithatja ki
	var opened_signals: Array[int] = [0]
	chest.opened.connect(func(): opened_signals[0] += 1)
	await put_player(chest.global_position + Vector2(0, 60))
	var treats_before: int = root.get_node("PlayerData").treats
	var could_open: bool = root.get_node("InteractionManager").current() == chest
	bus().interaction_pressed.emit()
	await frames(3)
	# A "találtál falatot" üzenetet végiglapozzuk (a gombnyomás most a dialógusé), aztán még egyszer próbáljuk
	var dialogue = root.get_node("Main/ScreenUI/DialogueBox") if root.has_node("Main") else null
	if dialogue: dialogue.finish_dialogue()
	await frames(3)
	bus().interaction_pressed.emit()
	await frames(3)
	var treats_gained: int = root.get_node("PlayerData").treats - treats_before
	check("chest_opens_once_with_treats", could_open and chest.is_open and opened_signals[0] == 1 \
			and root.get_node("InteractionManager").current() != chest and treats_gained == chest.treats,
			"could_open=%s open=%s signals=%d treats_gained=%d" % [could_open, chest.is_open, opened_signals[0], treats_gained])

	# 5. A retesz és a nyitott láda megmarad pályaváltás után (World -> Town -> World)
	await put_player(gate_front + Vector2(0, 200))
	await change_map("res://scenes/maps/world/town.tscn", &"from_world")
	await change_map("res://scenes/maps/world/world.tscn", &"from_town")
	find_nodes()
	check("latch_and_chest_survive_map_change", gate.latched and gate.is_open and gate.collision_shape.disabled and chest.is_open,
			"latched=%s open=%s disabled=%s chest=%s" % [gate.latched, gate.is_open, gate.collision_shape.disabled, chest.is_open])

	# 6. Kitolás északra is: aki belülről lép a kapuba, azt befelé tolja vissza (reteszeletlen
	# kapuval, a lapon álló lénnyel)
	gate.latched = false
	gate.is_open = false
	gate.progress = 0.0
	gate.collision_shape.disabled = false
	await put_player(gate.global_position + Vector2(0, -300))
	await reset_companion()
	comp.global_position = plate.center() - comp.get_node("CollisionShape2D").position
	root.get_node("PlayerData").companion_stay_duration_override = 30.0
	comp.go_to_position(plate.center())
	await wait_until(func(): return gate.is_open, 4.0)
	bus().joystick_moved.emit(Vector2.DOWN)
	await seconds(0.4)
	bus().joystick_moved.emit(Vector2.ZERO)
	var in_doorway: bool = gate.doorway.get_overlapping_bodies().has(player)
	bus().companion_recalled.emit()
	await wait_until(func(): return not gate.is_open, 2.0)
	await frames(2)
	check("pushed_back_the_way_they_came", in_doorway and not gate.is_open and player.global_position.y < gate.doorway_rect().position.y + 1.0,
			"in_doorway=%s open=%s player_y=%.0f doorway_top=%.0f" % [in_doorway, gate.is_open, player.global_position.y, gate.doorway_rect().position.y])

	print("DONE: %d failure(s)" % failures)
	quit(1 if failures else 0)
