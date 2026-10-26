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
