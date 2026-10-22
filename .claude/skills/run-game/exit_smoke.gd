extends SceneTree
# Smoke test (via scenes/main/main.tscn): World -> east exit -> Town (arrival, building collision, companion tap) -> west exit -> World.
# Run it as described in SKILL.md. Exit code 0 = every CHECK passed. OUT=<dir> saves screenshots.
var out := OS.get_environment("OUT")
var t := 0.0
var phase := "boot"
var phase_t := 0.0
var results := []
var marks := {}
func _initialize(): change_scene_to_file("res://scenes/main/main.tscn")
func sm(): return root.get_node("SceneManager")
func scene(): return sm().current_map
func P(): return scene().get_node_or_null("YSort_Entities/Player")
func C(): return scene().get_node_or_null("YSort_Entities/Companion")
func bus(): return root.get_node("SignalBus")
func shot(tag): if out != "": root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, tag])
func check(name, ok, info := ""):
	results.append(ok); print("CHECK %-42s %s %s" % [name, "PASS" if ok else "FAIL", info])
func go(p): print("%6.2f PHASE %s in %s P=%s" % [t, p, scene().name, P().global_position.round() if P() else "-"]); phase = p; phase_t = 0.0
func finish():
	var failed = results.count(false)
	print("RESULT %d checks, %d failed" % [results.size(), failed]); quit(1 if failed else 0)
func _process(delta):
	t += delta; phase_t += delta
	if scene() == null: return false
	if t > 90: check("timeout", false, phase); finish(); return true
	match phase:
		"boot":
			if phase_t > 1.0 and scene().name == "World":
				P().global_position = Vector2(5000, 320); C().global_position = Vector2(4940, 320)
				go("walk_east")
		"walk_east":
			bus().joystick_moved.emit(Vector2.RIGHT)
			if scene().name == "Town": bus().joystick_moved.emit(Vector2.ZERO); go("in_town")
			elif phase_t > 5: check("east exit leads to Town", false); finish()
		"in_town":
			bus().joystick_moved.emit(Vector2.ZERO)
			if phase_t > 1.0 and not sm().changing:
				check("east exit leads to Town", true)
				check("arrived at Town.from_world", P().global_position.distance_to(Vector2(280, 320)) < 5, str(P().global_position))
				check("companion moved along", C() != null and C().global_position.distance_to(P().global_position) < 200)
				shot("01_town_arrival")
				P().global_position = Vector2(1265, 500); go("walk_into_bakery")
		"walk_into_bakery":
			bus().joystick_moved.emit(Vector2.UP)
			if phase_t > 2.0:
				bus().joystick_moved.emit(Vector2.ZERO)
				check("bakery blocks the player at its front", abs(P().global_position.y - 188) < 6, str(P().global_position))
				shot("02_at_bakery")
				P().global_position = Vector2(1600, 700); go("tap")
		"tap":
			if phase_t > 0.5 and not marks.has("tap"):
				marks["tap"] = Vector2(2300, 1250)
				var screen = root.get_viewport().get_canvas_transform() * marks["tap"]
				bus().screen_tapped.emit(screen)
			if phase_t > 1.2 and not marks.has("tap_shot"): marks["tap_shot"] = true; shot("03_companion_sent")
			if marks.has("tap") and C().global_position.distance_to(marks["tap"]) < 40:
				check("companion reaches a tap in Town", true, "after %.1fs" % phase_t)
				go("walk_west")
			elif phase_t > 20:
				check("companion reaches a tap in Town", false, str(C().global_position)); go("walk_west")
		"walk_west":
			if phase_t < 0.1: P().global_position = Vector2(400, 320)
			bus().joystick_moved.emit(Vector2.LEFT)
			if scene().name == "World": bus().joystick_moved.emit(Vector2.ZERO); go("back")
			elif phase_t > 5: check("west exit leads to World", false); finish()
		"back":
			bus().joystick_moved.emit(Vector2.ZERO)
			if phase_t > 1.5 and not sm().changing:
				check("west exit leads to World", true)
				check("arrived at World.from_town, no bounce", scene().name == "World" and P().global_position.distance_to(Vector2(5160, 320)) < 5, str(P().global_position))
				shot("04_back_in_world")
				finish()
	return false
