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

	# 3. Időzítés: a hős végig a kapunak nyomul. 0. szinten (1 mp) a kapu félig felemelkedik és
	# visszaesik: nem nyílik ki, a hős be sem lép a nyílásba (nem is tolja ki); 1. szinten (3 mp)
	# kinyílik, a hős átjut, és a retesz nyitva tartja.
	var through: Dictionary = {}
	for level in [0, 1]:
		await put_player(gate_front)
		await reset_companion()
		root.get_node("PlayerData").companion_skills.stay.level = level
		comp.send_to_position(plate.center())
		bus().joystick_moved.emit(Vector2.UP)
		var peak: float = 0.0
		var ever_open: bool = false
		var entered_doorway: bool = false
		var t: float = 0.0
		while t < 7.0 and not gate.latched and not (level == 0 and t > 1.0 and not comp.is_away()):
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			peak = maxf(peak, gate.progress)
			ever_open = ever_open or gate.is_open
			entered_doorway = entered_doorway or gate.doorway.get_overlapping_bodies().has(player)
		await seconds(0.5)
		bus().joystick_moved.emit(Vector2.ZERO)
		through[level] = player.global_position.y < gate.doorway_rect().position.y
		if level == 0:
			check("stay_level_0_gate_rises_and_drops", not ever_open and peak > 0.4 and peak < 1.0 and not through[0]
					and not entered_doorway and gate.progress == 0.0,
					"open=%s peak=%.2f through=%s in_doorway=%s" % [ever_open, peak, through[0], entered_doorway])
		await wait_until(func(): return not comp.is_away(), 8.0)
	check("stay_level_1_gets_through_and_latches", through[1] and gate.latched and gate.is_open and gate.collision_shape.disabled,
			"through=%s latched=%s open=%s" % [through[1], gate.latched, gate.is_open])

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

	# A kapu képe: teljesen nyitva nem látszik, záráskor close_time alatt csúszik vissza
	gate.latched = false
	gate.progress = 1.0
	gate.shown_progress = 1.0
	gate.set_open(true)
	gate.update_sprite()
	var hidden_when_open: bool = not gate.sprite.visible
	gate.progress = 0.0
	gate.set_open(false)
	await frames(3)
	var closing_visible: bool = gate.sprite.visible and gate.shown_progress > 0.0 and gate.shown_progress < 1.0
	await seconds(gate.close_time + 0.1)
	check("gate_hides_when_open_and_slides_shut", hidden_when_open and closing_visible and gate.shown_progress == 0.0
			and gate.sprite.region_rect == gate.CLOSED_REGION and not gate.collision_shape.disabled,
			"hidden=%s closing=%s shown=%.2f" % [hidden_when_open, closing_visible, gate.shown_progress])

	# A tető (opacity zóna, changes_level = false): kintről látszik, a kapun besétálva elhalványul,
	# kisétálva visszaáll; a hős ütközési rétege és z-indexe közben nem változik
	var zone: Area2D = pen.get_node("RoofOpacityZone")
	gate.latch()
	await put_player(gate.global_position + Vector2(0, 60))
	await reset_companion()
	# A korábbi esetek teleportálták a hőst a szobába és ki, ami kihagyhatja a zóna belépő
	# sávjának jeleit (játék közben csak pályaváltáskor van teleport, akkor a zóna is újraépül)
	zone.player_in = false; zone.companion_in = false
	zone.player_in_shader_zone = false; zone.companion_in_shader_zone = false
	zone.update_zone_state()
	await seconds(0.4)
	var outside_opacity: float = zone.current_opacity
	bus().joystick_moved.emit(Vector2.UP)
	await seconds(1.5)
	bus().joystick_moved.emit(Vector2.ZERO)
	await seconds(0.4)
	var inside_opacity: float = zone.current_opacity
	var same_level: bool = player.z_index == 1 and player.get_collision_mask_value(1) and not player.get_collision_mask_value(2)
	bus().joystick_moved.emit(Vector2.DOWN)
	await seconds(1.8)
	bus().joystick_moved.emit(Vector2.ZERO)
	await seconds(0.4)
	check("roof_fades_inside", outside_opacity == 1.0 and inside_opacity < 0.3 and zone.current_opacity == 1.0 and same_level
			and zone.portals.is_empty(), "outside=%.2f inside=%.2f after=%.2f same_level=%s" % [outside_opacity, inside_opacity, zone.current_opacity, same_level])

	# A lény egyedül is elhalványítja a tetőt, ha besétál (a hős kint marad)
	await put_player(gate.global_position + Vector2(0, 120))
	await reset_companion()
	root.get_node("PlayerData").companion_stay_duration_override = 30.0
	comp.go_to_position(gate.global_position + Vector2(0, -330))
	await wait_until(func(): return comp.current_state == comp.State.IDLE, 6.0)
	await seconds(0.4)
	var companion_alone: float = zone.current_opacity
	bus().companion_recalled.emit()
	await wait_until(func(): return not comp.is_away(), 6.0)
	await seconds(0.4)
	root.get_node("PlayerData").companion_stay_duration_override = 0.0
	check("companion_fades_roof_too", companion_alone < 0.3 and zone.current_opacity == 1.0,
			"alone=%.2f after=%.2f" % [companion_alone, zone.current_opacity])

	# A szoba két első sarkánál nem lehet kimenni a falon át (ott rés volt a falak ütközői között)
	var leaks: Array[String] = []
	for side in [-1, 1]:
		await put_player(pen.global_position + Vector2(side * 290, -250))
		bus().joystick_moved.emit(Vector2(side, 0))
		await seconds(1.0)
		bus().joystick_moved.emit(Vector2.ZERO)
		await frames(3)
		var x: float = player.get_node("CollisionShape2D").global_position.x - pen.global_position.x
		if absf(x) > 330.0:
			leaks.append("%s x=%.0f" % ["left" if side < 0 else "right", x])
	check("no_gaps_in_the_room_corners", leaks.is_empty(), str(leaks))

	# A lény nem léphet ki a hős köréből akkor sem, ha a cél a körön belül van, de az út kivezetne
	# (mint a lépcsőn át egy fenti pontra): a kör szélén megáll. Itt a cél a szobában van, egyenesen
	# a körön belül, de csak a kapun át vezet út, ami a körön kívül esik.
	gate.latch()
	await put_player(pen.global_position + Vector2(-300, 60))
	await reset_companion()
	var test_range: float = 320.0
	root.get_node("PlayerData").companion_send_range_override = test_range
	var inside_target: Vector2 = pen.global_position + Vector2(-300, -250)
	var pfeet: Vector2 = player.get_node("CollisionShape2D").global_position
	var cfeet_node: Node2D = comp.get_node("CollisionShape2D")
	var target_in_range: bool = inside_target.distance_to(pfeet) < test_range
	comp.send_to_position(inside_target)
	var farthest: float = 0.0
	var t2: float = 0.0
	while comp.current_state == comp.State.GO_TO_TARGET and t2 < 8.0:
		await physics_frame
		t2 += 1.0 / Engine.physics_ticks_per_second
		farthest = maxf(farthest, cfeet_node.global_position.distance_to(pfeet))
	var stopped_at: Vector2 = cfeet_node.global_position
	var waiting: bool = comp.current_state == comp.State.IDLE
	root.get_node("PlayerData").companion_send_range_override = 0.0
	bus().companion_recalled.emit()
	await wait_until(func(): return not comp.is_away(), 8.0)
	check("companion_stays_inside_the_circle", target_in_range and waiting and farthest <= test_range + 5.0
			and stopped_at.distance_to(inside_target) > 100.0,
			"target_in_range=%s waiting=%s farthest=%.0f range=%.0f stopped=%s" % [target_in_range, waiting, farthest, test_range, (stopped_at - pen.global_position).round()])

	print("DONE: %d failure(s)" % failures)
	quit(1 if failures else 0)
