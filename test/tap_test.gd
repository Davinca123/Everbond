extends Node
# Teszt a koppintásos lény-küldéshez. Valódi érintés eseményeket küld a Godot
# bemeneti láncán át (Input.parse_input_event), így a joystick, a gombok és a
# dialógus is ugyanúgy látják, mint a telefonon. Minden eset végén PASS/FAIL.
#
# Futtatás (a projekt mappájából), kisebb ablakkal, hogy a nyújtás (stretch) is tesztelve legyen:
#   godot --path . --resolution 1200x540 res://test/tap_test.tscn
# Kijelző nélkül: xvfb-run -a ... --rendering-method gl_compatibility --rendering-driver opengl3
# OUT=<mappa>: minden eset végén képernyőkép

var main; var world; var player; var comp; var pfeet; var cfeet
var taps: int = 0
var failures: int = 0
var out = OS.get_environment("OUT")

func _ready():
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	world = SceneManager.current_map
	if out != "":
		var ov = preload("res://test/overlay.gd").new(); ov.world = world; ov.z_index = 100
		world.add_child(ov)
	player = world.get_node("YSort_Entities/Player"); comp = world.get_node("YSort_Entities/Companion")
	pfeet = player.get_node("CollisionShape2D"); cfeet = comp.get_node("CollisionShape2D")
	SignalBus.screen_tapped.connect(func(_p): taps += 1)
	await run()
	print("DONE: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)

# --- segédek ---

func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame

func seconds(t: float) -> void:
	await get_tree().create_timer(t, true, true).timeout

# Világ pont -> ablak pixel (a kamera és az ablak nyújtása szerint), ide "koppint" az ujj
func to_window(world_pos: Vector2) -> Vector2:
	var viewport_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	return viewport_pos * Vector2(get_window().size) / get_viewport().get_visible_rect().size

func viewport_to_window(viewport_pos: Vector2) -> Vector2:
	return viewport_pos * Vector2(get_window().size) / get_viewport().get_visible_rect().size

func touch(index: int, window_pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index; e.position = window_pos; e.pressed = pressed
	Input.parse_input_event(e)

func drag(index: int, window_pos: Vector2, relative: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index; e.position = window_pos; e.relative = relative
	Input.parse_input_event(e)

func tap(window_pos: Vector2, index: int = 0) -> void:
	touch(index, window_pos, true)
	await frames(3)
	touch(index, window_pos, false)
	await frames(2)

func key(keycode: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = keycode; e.keycode = keycode; e.pressed = pressed
		Input.parse_input_event(e)
		await frames(2)

func click(window_pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT; e.position = window_pos; e.global_position = window_pos; e.pressed = pressed
		Input.parse_input_event(e)
		await frames(3 if pressed else 2)

func check(name: String, ok: bool, detail: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok: failures += 1
	if out != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])

func wait_until_idle(timeout: float) -> void:
	var t := 0.0
	while comp.current_state != comp.State.IDLE and t < timeout:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()

func settle() -> void:
	# A kamera simítása miatt várunk, amíg a kép megáll
	await seconds(1.5)

# Megvárjuk, amíg a lény újra a hős mellett jár (követő állapot, közel a hőshöz)
func wait_until_following(timeout: float = 8.0) -> void:
	var t := 0.0
	while (comp.current_state != comp.State.FOLLOW or cfeet.global_position.distance_to(pfeet.global_position) > comp.min_distance + 20.0) and t < timeout:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()

# A hős adott ideig megy egy irányba (a joystick szignálján át)
func walk(direction: Vector2, time: float) -> void:
	SignalBus.joystick_moved.emit(direction)
	await seconds(time)
	SignalBus.joystick_moved.emit(Vector2.ZERO)
	await frames(2)

# --- esetek ---

func run() -> void:
	await seconds(0.5)
	await settle()
	var half_width: float = get_viewport().get_visible_rect().size.x / 2.0

	# 1. Koppintás a képernyő jobb oldalán: a lény a koppintott világ pontra megy
	var target: Vector2 = pfeet.global_position + Vector2(350, 60)
	var tp: Vector2 = to_window(target)
	await tap(tp)
	await frames(3)
	var marker: Node2D = comp.target_marker
	var marker_spot: Vector2 = marker.get_child(0).global_position
	await check("marker_shown_while_walking", marker.is_visible_in_tree() and marker_spot.distance_to(target) < 2.0,
			"visible=%s marker=%s target=%s" % [marker.visible, marker_spot.round(), target.round()])
	await wait_until_idle(5.0)
	await frames(2)
	await check("marker_hidden_on_arrival", not marker.visible, "visible=%s" % marker.visible)
	await check("right_tap", taps == 1 and comp.click_target_pos.distance_to(target) < 2.0 \
			and cfeet.global_position.distance_to(target) < 10.0,
			"taps=%d target=%s sent=%s comp=%s" % [taps, target.round(), comp.click_target_pos.round(), cfeet.global_position.round()])

	# 2. Vár, majd visszamegy a hőshöz
	await seconds(2.3)
	await check("returns_to_follow", comp.current_state == comp.State.FOLLOW, "state=%d" % comp.current_state)
	await seconds(2.0)

	# 3. Koppintás a képernyő BAL oldalán (joystick terület): a lény odamegy, a hős alig mozdul
	await settle()
	taps = 0
	target = pfeet.global_position + Vector2(-300, 80)
	tp = to_window(target)
	var player_before: Vector2 = pfeet.global_position
	var on_left: bool = get_viewport().get_canvas_transform() * target < Vector2(half_width, INF)
	await tap(tp)
	await wait_until_idle(5.0)
	await check("left_tap", on_left and taps == 1 and comp.click_target_pos.distance_to(target) < 2.0 \
			and cfeet.global_position.distance_to(target) < 10.0 and pfeet.global_position.distance_to(player_before) < 5.0,
			"left=%s taps=%d target=%s comp=%s player_moved=%.1f" % [on_left, taps, target.round(),
			cfeet.global_position.round(), pfeet.global_position.distance_to(player_before)])
	await seconds(4.5)

	# 4. Joystick húzás a bal oldalon: a hős megy, ez NEM koppintás
	taps = 0
	player_before = pfeet.global_position
	var start: Vector2 = viewport_to_window(Vector2(400, 700))
	touch(0, start, true)
	for i in 10:
		await frames(1)
		drag(0, start + Vector2(8 * (i + 1), 0), Vector2(8, 0))
	await seconds(1.0)
	touch(0, start + Vector2(80, 0), false)
	await frames(5)
	var moved: float = pfeet.global_position.x - player_before.x
	await check("joystick_drag_not_tap", taps == 0 and moved > 100.0 and comp.current_state == comp.State.FOLLOW,
			"taps=%d player_moved_x=%.0f state=%d" % [taps, moved, comp.current_state])

	# 5. Hosszú, mozdulatlan nyomás: nem koppintás
	taps = 0
	touch(0, viewport_to_window(Vector2(400, 700)), true)
	await seconds(0.6)
	touch(0, viewport_to_window(Vector2(400, 700)), false)
	await frames(5)
	await check("long_press_not_tap", taps == 0, "taps=%d" % taps)

	# 6. Több ujj: bal ujj a joysticken (a hős megy), közben a jobb oldalon koppintunk
	taps = 0
	player_before = pfeet.global_position
	touch(0, start, true)
	for i in 10:
		await frames(1)
		drag(0, start + Vector2(0, 8 * (i + 1)), Vector2(0, 8))
	await seconds(0.3)
	await tap(viewport_to_window(Vector2(1900, 500)), 1)
	await seconds(0.5)
	var still_moving: bool = player.velocity.length() > 100.0
	touch(0, start + Vector2(0, 80), false)
	await frames(5)
	await check("multitouch_tap_while_moving", taps == 1 and comp.current_state != comp.State.FOLLOW and still_moving,
			"taps=%d state=%d player_moving=%s" % [taps, comp.current_state, still_moving])
	await seconds(4.5)

	await run_send_range()
	await run_send_once()
	await run_treats()

	# 7. Az interakció gomb megnyomása nem küldi el a lényt, és a dialógus alatti koppintások sem
	var npc = world.get_node("YSort_Entities/Npc")
	player.global_position = npc.global_position + Vector2(-116, 29)
	await seconds(0.5)
	var button = main.get_node("ScreenUI/InteractionButtonAnchor/InteractionButton")
	var button_center: Vector2 = button.get_global_transform_with_canvas() * (button.texture_normal.get_size() / 2.0)
	taps = 0
	var dialogue := { "started": false, "finished": false }
	SignalBus.dialogue_started.connect(func(_s, _l): dialogue.started = true)
	SignalBus.dialogue_finished.connect(func(): dialogue.finished = true)
	var button_visible: bool = button.visible
	await tap(viewport_to_window(button_center))
	await frames(5)
	# A dialógust végig koppintjuk; ezek a koppintások a dialógusé, nem a lényé
	var dialogue_taps: int = 0
	while dialogue.started and not dialogue.finished and dialogue_taps < 15:
		await tap(viewport_to_window(Vector2(1800, 300)))
		await seconds(0.2)
		dialogue_taps += 1
	await check("button_and_dialogue_not_tap", button_visible and dialogue.started and dialogue.finished \
			and taps == 0 and comp.current_state == comp.State.FOLLOW,
			"button_visible=%s dialogue=%s/%s dialogue_taps=%d taps=%d state=%d" % [button_visible,
			dialogue.started, dialogue.finished, dialogue_taps, taps, comp.current_state])

	# 8. Navigációs háló nélkül (pl. belső tér) a lény egyenesen megy; ha falba ütközik,
	# nem ragad be örökre, hanem feladja és visszamegy a hőshöz
	await seconds(2.0)
	for region in world.find_children("*", "NavigationRegion2D", true, false):
		region.enabled = false
	await frames(5)
	await settle()
	target = cfeet.global_position + Vector2(0, -500) # egyenesen észak felé, a fal túloldalára
	await tap(to_window(target))
	await wait_until_idle(5.0)
	var gave_up: bool = comp.current_state == comp.State.IDLE and cfeet.global_position.distance_to(target) > 100.0
	await seconds(2.3)
	await check("stuck_gives_up_and_returns", gave_up and comp.current_state == comp.State.FOLLOW,
			"gave_up=%s comp=%s target=%s state=%d" % [gave_up, cfeet.global_position.round(), target.round(), comp.current_state])
	for region in world.find_children("*", "NavigationRegion2D", true, false):
		region.enabled = true

	# 9. PC: az "interact" billentyű (E) elindítja a dialógust, az E és az egérkattintás
	# lapoz, és egyik sem küldi el a lényt
	await seconds(2.0)
	player.global_position = npc.global_position + Vector2(-116, 29)
	await seconds(0.5)
	taps = 0
	dialogue.started = false; dialogue.finished = false
	await key(KEY_E)
	var started_by_key: bool = dialogue.started
	var presses: int = 0
	while dialogue.started and not dialogue.finished and presses < 15:
		# Felváltva billentyű és egérkattintás
		if presses % 2 == 0: await click(viewport_to_window(Vector2(1800, 300)))
		else: await key(KEY_E)
		await seconds(0.2)
		presses += 1
	await check("pc_key_and_mouse_dialogue", started_by_key and dialogue.finished and presses >= 2 \
			and taps == 0 and comp.current_state == comp.State.FOLLOW,
			"started_by_key=%s finished=%s presses=%d taps=%d state=%d" % [started_by_key,
			dialogue.finished, presses, taps, comp.current_state])

	# 10. Egymást fedő tárgyak (NPC és zárt ajtó): csak a legutóbb belépett kapja a
	# gombnyomást; a "Zárva van..." után a gomb visszajön; az egyikből kilépve a gomb
	# a másiknak marad
	var door = world.get_node("YSort_Entities/Doors/Door1")
	door.is_locked = true
	player.global_position = npc.global_position + Vector2(-116, 29)
	await seconds(0.5)
	InteractionManager.enter(door)
	await frames(2)
	var speakers: Array[String] = []
	var on_started := func(s, _l): speakers.append(s)
	SignalBus.dialogue_started.connect(on_started)
	dialogue.finished = false
	await key(KEY_E)
	presses = 0
	while not dialogue.finished and presses < 15:
		await key(KEY_E)
		await seconds(0.2)
		presses += 1
	await frames(2)
	var button_after_locked: bool = button.visible
	InteractionManager.exit(door)
	await frames(2)
	var npc_keeps_button: bool = button.visible and InteractionManager.current() == npc
	SignalBus.dialogue_started.disconnect(on_started)
	door.is_locked = false
	await check("overlapping_interactables", speakers == ([""] as Array[String]) and button_after_locked \
			and npc_keeps_button and SceneManager.current_map == world,
			"speakers=%s button_after_locked=%s npc_keeps_button=%s" % [speakers, button_after_locked, npc_keeps_button])

	# 11. Zárt ajtó kulccsal: a kulcs nélkül zárva marad, a kulccsal kinyílik
	# (utolsó eset: az ajtó a házba visz)
	door.is_locked = true; door.required_key_name = "test_key"
	player.global_position = door.global_position + Vector2(0, 30)
	await seconds(0.5)
	PlayerData.inventory.append("test_key")
	var was_current: bool = InteractionManager.current() == door
	await key(KEY_E)
	await frames(2)
	await check("locked_door_opens_with_key", was_current and not door.is_locked and door.is_open,
			"was_current=%s locked=%s open=%s" % [was_current, door.is_locked, door.is_open])
	await seconds(1.0)

# --- küldési távolság (docs/companion-training-plan.md, 1. rész) ---

func run_send_range() -> void:
	var send_range: float = PlayerData.get_companion_send_range()

	# 12. Távolságon túli koppintás: a cél a távolság körén van, a koppintás felé, és a jelölő ott van
	await wait_until_following()
	await settle()
	var target: Vector2 = pfeet.global_position + Vector2(900, 40)
	await tap(to_window(target))
	await frames(3)
	var from_player: Vector2 = comp.click_target_pos - pfeet.global_position
	var marker_spot: Vector2 = comp.target_marker.get_child(0).global_position
	await check("tap_beyond_range_clamped", absf(from_player.length() - send_range) < 40.0 \
			and from_player.angle_to(target - pfeet.global_position) < 0.1 and marker_spot.distance_to(comp.click_target_pos) < 2.0,
			"dist=%.0f range=%.0f marker=%s dest=%s" % [from_player.length(), send_range, marker_spot.round(), comp.click_target_pos.round()])
	await wait_until_idle(6.0)
	await wait_until_following()

	# 13. A hős mozog, amíg a lény megy: a cél vele mozog, a távolságon belül marad, és ha
	# a hős visszamegy, a cél visszaáll a koppintott pontra
	await settle()
	target = pfeet.global_position + Vector2(480, 0)
	await tap(to_window(target))
	await frames(3)
	await walk(Vector2.LEFT, 0.6)
	await frames(10)
	var moved_dest: Vector2 = comp.click_target_pos
	var dest_dist: float = moved_dest.distance_to(pfeet.global_position)
	var walking: bool = comp.current_state == comp.State.GO_TO_TARGET
	await walk(Vector2.RIGHT, 0.6)
	await frames(10)
	var back_dest: Vector2 = comp.click_target_pos
	await check("destination_follows_player", walking and moved_dest.x < target.x - 40.0 and dest_dist <= send_range + 2.0 \
			and back_dest.distance_to(target) < 5.0,
			"walking=%s moved=%s dist=%.0f back=%s target=%s" % [walking, moved_dest.round(), dest_dist, back_dest.round(), target.round()])
	await wait_until_idle(6.0)
	await wait_until_following()

	# 14. A hős a távolságon belül mozog a várakozás alatt: a lény kivárja az időt
	await settle()
	target = pfeet.global_position + Vector2(300, 0)
	await tap(to_window(target))
	await wait_until_idle(5.0)
	await walk(Vector2.LEFT, 0.4)
	await frames(5)
	var still_waiting: bool = comp.current_state == comp.State.IDLE
	await seconds(comp.stay_duration)
	await check("player_moves_within_range_keeps_wait", still_waiting and comp.current_state == comp.State.FOLLOW,
			"still_waiting=%s state=%d" % [still_waiting, comp.current_state])
	await wait_until_following()

	# 15. A hős kilép a távolságból a várakozás alatt: a lény abban a pillanatban feladja,
	# és a csík eltűnik
	await settle()
	target = pfeet.global_position + Vector2(440, 0)
	await tap(to_window(target))
	await wait_until_idle(5.0)
	var waited_at: Vector2 = cfeet.global_position
	var limit: float = send_range + comp.SEND_RANGE_TOLERANCE
	var gave_up_at: float = -1.0
	SignalBus.joystick_moved.emit(Vector2.LEFT)
	for i in 120:
		await get_tree().physics_frame
		if comp.current_state != comp.State.IDLE:
			gave_up_at = waited_at.distance_to(pfeet.global_position)
			break
	SignalBus.joystick_moved.emit(Vector2.ZERO)
	await frames(3)
	await check("player_leaves_range_ends_wait", gave_up_at > limit and gave_up_at < limit + 10.0 \
			and comp.current_state == comp.State.FOLLOW and not comp.stay_bar_shown,
			"gave_up_at=%.0f limit=%.0f state=%d bar=%s" % [gave_up_at, limit, comp.current_state, comp.stay_bar_shown])
	await wait_until_following()

# --- egy küldés, visszahívás (docs/companion-training-plan.md, 2. rész) ---

func button_window_center(button: TouchScreenButton) -> Vector2:
	return viewport_to_window(button.get_global_transform_with_canvas() * (button.texture_normal.get_size() / 2.0))

func run_send_once() -> void:
	var events: Array[String] = []
	var log_event := func(event_name: String): events.append(event_name)
	var on_sent := func(_t): log_event.call("sent")
	var on_ignored := func(): log_event.call("ignored")
	var on_arrived := func(): log_event.call("arrived")
	var on_finished := func(full: bool): log_event.call("finished_full" if full else "finished_cut")
	var on_returned := func(): log_event.call("returned")
	var on_recalled := func(): log_event.call("recalled")
	SignalBus.companion_sent.connect(on_sent)
	SignalBus.companion_tap_ignored.connect(on_ignored)
	SignalBus.companion_arrived.connect(on_arrived)
	SignalBus.companion_stay_finished.connect(on_finished)
	SignalBus.companion_returned.connect(on_returned)
	SignalBus.companion_recalled.connect(on_recalled)
	var button: TouchScreenButton = main.get_node("ScreenUI/CallBackButtonAnchor/CallBackButton")

	# 16. Egy küldés: amíg a lény kint van (megy, vár, jön vissza), a koppintást nem fogadja
	# el; a jelek sorrendben jönnek; visszaérve újra lehet küldeni
	await wait_until_following()
	await settle()
	events.clear()
	var target: Vector2 = pfeet.global_position + Vector2(300, 0)
	await tap(to_window(target))
	await frames(5)
	await tap(to_window(pfeet.global_position + Vector2(0, 200)))
	var kept_walking: bool = comp.click_target_pos.distance_to(target) < 2.0
	await wait_until_idle(5.0)
	await tap(to_window(pfeet.global_position + Vector2(0, 200)))
	var kept_waiting: bool = comp.current_state == comp.State.IDLE
	while comp.current_state == comp.State.IDLE:
		await get_tree().physics_frame
	await frames(10)
	var returning: bool = comp.returning
	await tap(to_window(pfeet.global_position + Vector2(0, 200)))
	var not_resent: bool = comp.current_state == comp.State.FOLLOW
	await wait_until_following()
	await frames(10)
	var expected: Array[String] = ["sent", "ignored", "arrived", "ignored", "finished_full", "ignored", "returned"]
	await check("second_tap_ignored_until_back", kept_walking and kept_waiting and returning and not_resent and events == expected,
			"walking=%s waiting=%s returning=%s not_resent=%s events=%s" % [kept_walking, kept_waiting, returning, not_resent, events])
	events.clear()
	await tap(to_window(pfeet.global_position + Vector2(250, 0)))
	await frames(3)
	await check("tap_accepted_after_return", comp.current_state == comp.State.GO_TO_TARGET and events == (["sent"] as Array[String]),
			"state=%d events=%s" % [comp.current_state, events])

	# 17. A visszahívó gomb a cél felé menet: látszik, megnyomva a lény megfordul, a gomb
	# eltűnik, és a gombnyomás nem koppintás
	await frames(10)
	var shown_while_walking: bool = button.visible
	taps = 0
	events.clear()
	await tap(button_window_center(button))
	await frames(3)
	await check("call_back_button_while_walking", shown_while_walking and taps == 0 and not button.visible \
			and comp.current_state == comp.State.FOLLOW and comp.returning and events == (["recalled"] as Array[String]),
			"shown=%s taps=%d visible=%s state=%d returning=%s events=%s" % [shown_while_walking, taps, button.visible,
			comp.current_state, comp.returning, events])
	await wait_until_following()
	await frames(10)

	# 18. Q a várakozás alatt: a lény abbahagyja a várakozást, nem teljes (full = false)
	await settle()
	await tap(to_window(pfeet.global_position + Vector2(250, 0)))
	await wait_until_idle(5.0)
	var shown_while_waiting: bool = button.visible
	events.clear()
	await key(KEY_Q)
	await frames(2)
	# A két jel sorrendje csak a feliratkozások sorrendjén múlik
	events.sort()
	await check("call_back_key_while_waiting", shown_while_waiting and not button.visible and comp.current_state == comp.State.FOLLOW \
			and events == (["finished_cut", "recalled"] as Array[String]),
			"shown=%s visible=%s state=%d events=%s" % [shown_while_waiting, button.visible, comp.current_state, events])
	await wait_until_following()
	await frames(10)

	# 19. Q, amikor a lény a hős mellett van: semmi (a gomb sem látszik)
	events.clear()
	await key(KEY_Q)
	await frames(2)
	await check("call_back_key_ignored_when_following", events.is_empty() and not button.visible, "events=%s" % [events])

	for connection in [[SignalBus.companion_sent, on_sent], [SignalBus.companion_tap_ignored, on_ignored],
			[SignalBus.companion_arrived, on_arrived], [SignalBus.companion_stay_finished, on_finished],
			[SignalBus.companion_returned, on_returned], [SignalBus.companion_recalled, on_recalled]]:
		connection[0].disconnect(connection[1])

# --- jutalomfalat (docs/gameplay-plan.md, 10. rész, 4. lépés) ---

func run_treats() -> void:
	var button: TouchScreenButton = main.get_node("ScreenUI/CallBackButtonAnchor/TreatButton")
	var given: Array[int] = [0]
	var on_given := func(): given[0] += 1
	SignalBus.treat_given.connect(on_given)
	await wait_until_following()
	await frames(5)
	PlayerData.treats = 2

	# 20. A lény a hős mellett van, és van falat: a gomb látszik; megnyomva a lény kap egyet,
	# és ez nem koppintás
	var near: bool = comp.is_next_to_player()
	var shown: bool = button.visible
	taps = 0
	await tap(button_window_center(button))
	await frames(3)
	await check("treat_button_gives_a_treat", near and shown and given[0] == 1 and PlayerData.treats == 1 and taps == 0 \
			and comp.current_state == comp.State.FOLLOW,
			"near=%s shown=%s given=%d treats=%d taps=%d" % [near, shown, given[0], PlayerData.treats, taps])

	# 21. A T billentyű is ad egyet; elfogyott: a gomb eltűnik, a T nem ad többet
	await key(KEY_T)
	await frames(2)
	var after_key: int = PlayerData.treats
	await key(KEY_T)
	await frames(2)
	await check("treat_key_and_running_out", after_key == 0 and given[0] == 2 and PlayerData.treats == 0 and not button.visible,
			"after_key=%d given=%d treats=%d visible=%s" % [after_key, given[0], PlayerData.treats, button.visible])

	# 22. Van falat, de a lény messze van: nincs gomb, a T nem ad
	PlayerData.add_treats(5)
	await settle()
	await tap(to_window(pfeet.global_position + Vector2(350, 0)))
	await wait_until_idle(5.0)
	await key(KEY_T)
	await frames(2)
	await check("no_treat_when_far", not button.visible and given[0] == 2 and PlayerData.treats == 5,
			"visible=%s given=%d treats=%d" % [button.visible, given[0], PlayerData.treats])
	await wait_until_following()
	await frames(5)
	await check("treat_button_back_when_near", button.visible, "visible=%s" % button.visible)
	SignalBus.treat_given.disconnect(on_given)
