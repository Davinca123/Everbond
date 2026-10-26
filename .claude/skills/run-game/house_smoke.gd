extends SceneTree
# Smoke test (via scenes/main/main.tscn): World -> Door1 -> House1Interior (companion present, follows, tap-to-send) -> exit -> World,
# then back in through the door that stayed open (saved map state) and out again.
# Run it as described in SKILL.md. Exit code 0 = every CHECK passed. OUT=<dir> saves screenshots.

var out := OS.get_environment("OUT")
var phase := "boot"
var t := 0.0
var phase_t := 0.0
var shot_n := 0
var results := []
var tap_world := Vector2.ZERO
var comp_start := Vector2.ZERO
var tap_checked := false
var back_logged := false

func _initialize():
	# The send range (500 px) would clamp the far taps; this checks path finding, not the range
	root.get_node("PlayerData").companion_send_range_override = INF
	change_scene_to_file("res://scenes/main/main.tscn")

# The map loaded inside Main (Main itself is current_scene and never changes)
func scene(): return root.get_node("SceneManager").current_map
func P(): return scene().get_node_or_null("YSort_Entities/Player") if scene() else null
func C(): return scene().get_node_or_null("YSort_Entities/Companion") if scene() else null
func bus(): return root.get_node("SignalBus")

func set_phase(p):
	print("%6.2f PHASE %s" % [t, p]); phase = p; phase_t = 0.0

func shot(tag):
	if out == "": return
	shot_n += 1
	root.get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [out, shot_n, tag])

func check(name, ok, info := ""):
	results.append([name, ok]); print("CHECK %-40s %s %s" % [name, "PASS" if ok else "FAIL", info])

func log_state():
	var p = P(); var c = C()
	print("%6.2f [%s] P%s C%s dist=%s state=%s" % [t, scene().name, p.global_position.round() if p else "-",
		c.global_position.round() if c else "-", str(round(p.global_position.distance_to(c.global_position))) if p and c else "-",
		str(c.current_state) if c else "-"])

func _process(delta):
	t += delta; phase_t += delta
	if scene() == null: return false
	if int(t * 2) != int((t - delta) * 2): log_state()
	match phase:
		"boot":
			if phase_t > 1.0 and scene().name == "World":
				var door = scene().get_node("YSort_Entities/Doors/Door1")
				P().global_position = door.global_position + Vector2(0, 30)
				set_phase("enter")
		"enter":
			bus().joystick_moved.emit(Vector2.ZERO)
			if phase_t > 0.3: bus().interaction_pressed.emit()
			if scene().name == "House1Interior": set_phase("inside")
			elif phase_t > 3.0: check("entered house", false); return finish()
		"inside":
			if phase_t > 0.5:
				var c = C(); var p = P()
				check("companion exists in interior", c != null)
				if c == null: return finish()
				check("companion visible", c.is_visible_in_tree())
				var d = p.global_position.distance_to(c.global_position)
				check("companion spawned near player", d < 120, "dist=%.0f" % d)
				var cam = root.get_viewport().get_camera_2d()
				var vr = Rect2(cam.get_screen_center_position() - root.get_viewport().get_visible_rect().size / 2 / cam.zoom,
					root.get_viewport().get_visible_rect().size / cam.zoom)
				check("companion on screen", vr.has_point(c.global_position), str(vr))
				shot("inside_spawn")
				comp_start = c.global_position
				set_phase("walk")
		"walk":
			bus().joystick_moved.emit(Vector2(1, 0.3).normalized())
			if phase_t > 2.0:
				bus().joystick_moved.emit(Vector2.ZERO); set_phase("settle")
		"settle":
			if phase_t > 2.0:
				var c = C(); var p = P()
				var d = p.global_position.distance_to(c.global_position)
				check("companion followed player", c.global_position.distance_to(comp_start) > 150 and d < 150,
					"moved=%.0f dist=%.0f" % [c.global_position.distance_to(comp_start), d])
				shot("after_follow")
				# Free floor in the bottom-left of the room, away from the furniture
				tap_world = scene().get_node("Spawns/from_world").global_position + Vector2(-400, 370)
				var screen = root.get_viewport().get_canvas_transform() * tap_world
				bus().screen_tapped.emit(screen)
				set_phase("tap")
		"tap":
			var c = C()
			if phase_t < 0.1: return false
			if not tap_checked:
				tap_checked = true
				check("tap -> GO_TO_TARGET", c.current_state == c.State.GO_TO_TARGET or c.current_state == c.State.IDLE)
			if c.current_state == c.State.IDLE:
				var d = c.feet.global_position.distance_to(tap_world)
				check("companion reached tap target", d < 20, "dist=%.0f target=%s" % [d, tap_world.round()])
				shot("at_tap_target")
				set_phase("return")
			elif phase_t > 8.0: check("companion reached tap target", false, "timeout"); set_phase("return")
		"return":
			var c = C()
			var d = P().global_position.distance_to(c.global_position)
			if c.current_state == c.State.FOLLOW and d < 150 and c.velocity == Vector2.ZERO:
				check("companion came back to player", true, "dist=%.0f after %.1fs" % [d, phase_t])
				shot("back_with_player")
				var door = scene().get_node("YSort_Entities/Doors/ExitDoor")
				P().global_position = door.global_position + Vector2(0, 30)
				set_phase("exit")
			elif phase_t > 10.0: check("companion came back to player", false, "timeout"); return finish()
		"exit":
			bus().joystick_moved.emit(Vector2.ZERO)
			if phase_t > 0.3: bus().interaction_pressed.emit()
			if scene().name == "World": set_phase("back")
			elif phase_t > 3.0: check("left house", false); return finish()
		"back":
			if phase_t > 0.5 and not back_logged:
				back_logged = true
				var d = P().global_position.distance_to(C().global_position)
				print("INFO back in World: player %s companion %s dist=%.0f" % [P().global_position.round(), C().global_position.round(), d])
				shot("back_in_world")
			if phase_t > 4.0:
				var d = P().global_position.distance_to(C().global_position)
				print("INFO back in World after 4s: dist=%.0f" % d)
				shot("back_in_world_4s")
				var door = scene().get_node("YSort_Entities/Doors/Door1")
				check("world door still open", door.is_open)
				P().global_position = door.global_position + Vector2(0, 30)
				set_phase("reenter")
		"reenter":
			bus().joystick_moved.emit(Vector2.ZERO)
			if phase_t > 0.3: bus().interaction_pressed.emit()
			if scene().name == "House1Interior": set_phase("inside_again")
			elif phase_t > 3.0: check("entered house through open door", false); return finish()
		"inside_again":
			if phase_t > 0.5:
				check("entered house through open door", true)
				var door = scene().get_node("YSort_Entities/Doors/ExitDoor")
				check("house exit door still open", door.is_open)
				P().global_position = door.global_position + Vector2(0, 30)
				set_phase("exit_again")
		"exit_again":
			bus().joystick_moved.emit(Vector2.ZERO)
			if phase_t > 0.3: bus().interaction_pressed.emit()
			if scene().name == "World":
				check("left house through open door", true); return finish()
			elif phase_t > 3.0: check("left house through open door", false); return finish()
	return false

func finish():
	var fails = results.filter(func(r): return not r[1]).size()
	print("RESULT %d checks, %d failed" % [results.size(), fails])
	quit(1 if fails else 0)
	return true
