extends Node
# Tesztvezérlő a kísérő szintváltásos követéséhez.
# A Playert útpontokon vezeti végig a joystick szignállal, naplózza mindkét karakter
# helyét és szintjét, a végén PASS/FAIL: egy szinten és 200 px-en belül vannak-e.
#
# Futtatás (a projekt mappájából):
#   SCENARIO=tunnel godot --path . res://test/drive.tscn
# Környezeti változók:
#   SCENARIO  tunnel | courtyard | inout | tapcourtyard | tapcourtyard_join (lásd SCENARIOS)
#   OUT       ha meg van adva, ide ment másodpercenként egy képernyőképet
#   OVERLAY=0 kikapcsolja a navigációs háló / zónák / útvonal rajzolását
# Videó: --write-movie kimenet.avi --fixed-fps 30
# Kijelző nélkül: xvfb-run -a ... --rendering-method gl_compatibility --rendering-driver opengl3
const SCENARIOS = {
	# Tunnel under the plateau (zone 2): in through the south arch, out the north end, then back
	"tunnel": [["nav", Vector2(1280, 380)], ["line", Vector2(1280, -650)], ["wait", 6.0],
		["line", Vector2(1280, 380)], ["wait", 6.0]],
	# Courtyard (zone 1): in through the south arch, walk around inside, back out
	"courtyard": [["nav", Vector2(2080, 1420)], ["line", Vector2(2080, 1150)], ["nav", Vector2(2280, 450)], ["wait", 6.0],
		["nav", Vector2(2080, 1150)], ["line", Vector2(2080, 1420)], ["wait", 6.0]],
	# A lényt koppintással beküldjük az udvar alá (2. szint), a hős közben felmegy a lépcsőn
	# és fölötte áll meg (1. szint): a lénynek ki kell jönnie az íven és fel kell mennie
	# keep: a koppintást ismételjük, amíg a "release" lépés el nem engedi (a lény ott vár)
	"tapcourtyard": [["nav", Vector2(1900, 1400)], ["tap", Vector2(2080, 1050)], ["wait", 6.0],
		["keep", Vector2(2080, 900)], ["nav", Vector2(2080, 900)], ["wait", 1.0], ["release"], ["wait", 25.0]],
	# Ugyanígy beküldjük, de most a hős is ugyanazon az íven megy be utána: a lény bent marad
	"tapcourtyard_join": [["nav", Vector2(1900, 1400)], ["tap", Vector2(2080, 1050)], ["wait", 6.0],
		["keep", Vector2(2080, 900)], ["nav", Vector2(2080, 1420)], ["line", Vector2(2080, 1150)],
		["release"], ["nav", Vector2(2280, 450)], ["wait", 6.0]],
	# In and straight back out the same arch before the companion arrives
	"inout": [["nav", Vector2(1280, 380)], ["line", Vector2(1280, 60)], ["line", Vector2(1280, 380)], ["wait", 6.0]],
}
var world; var player; var comp; var pfeet; var cfeet; var cam
var steps = []; var step = 0; var leg_path = PackedVector2Array(); var leg_i = 0
var wait_t = 0.0; var t = 0.0; var log_t = 0.0; var shot_t = 0.0; var shot_n = 0
var keep_target = null; var started = false; var stuck_t = 0.0; var last_pos = Vector2.ZERO; var leg_t = 0.0
var out = OS.get_environment("OUT"); var name_ = OS.get_environment("SCENARIO")

func _ready():
	world = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	if OS.get_environment("OVERLAY") != "0":
		var ov = preload("res://test/overlay.gd").new(); ov.world = world; ov.z_index = 100
		world.add_child(ov)
	player = world.get_node("YSort_Entities/Player"); comp = world.get_node("YSort_Entities/Companion")
	pfeet = player.get_node("CollisionShape2D"); cfeet = comp.get_node("CollisionShape2D")
	cam = Camera2D.new(); world.add_child(cam); cam.zoom = Vector2(0.55, 0.55); cam.make_current()
	cam.global_position = player.global_position
	steps = SCENARIOS[name_]
	print("SCENARIO ", name_)

func lvl(b): return (1 if b.get_collision_mask_value(1) else 0) | (2 if b.get_collision_mask_value(2) else 0)

func start_leg():
	leg_t = 0.0; leg_i = 0
	var s = steps[step]
	if s[0] == "nav":
		leg_path = NavigationServer2D.map_get_path(world.get_world_2d().navigation_map, pfeet.global_position, s[1], true, lvl(player))
	elif s[0] == "line":
		leg_path = PackedVector2Array([s[1]])
	elif s[0] == "tap":
		comp.send_to_position(s[1])
	elif s[0] == "keep":
		keep_target = s[1]
	elif s[0] == "release":
		keep_target = null
	else:
		wait_t = s[1]
	print("%6.2f LEG %d %s" % [t, step, str(s)])

func _physics_process(delta):
	t += delta
	if step >= steps.size():
		finish(); return
	if t < 0.5:
		return # let the navmeshes bake / the nav map sync
	if not started:
		started = true; start_leg()
	if steps[step][0] == "nav" and leg_path.is_empty():
		start_leg() # map not ready yet, retry
		return
	leg_t += delta
	var s = steps[step]
	var dir = Vector2.ZERO
	if s[0] in ["tap", "keep", "release"]:
		next()
	elif s[0] == "wait":
		wait_t -= delta
		if wait_t <= 0.0: next()
	else:
		while leg_i < leg_path.size() and pfeet.global_position.distance_to(leg_path[leg_i]) < 10.0:
			leg_i += 1
		if leg_i >= leg_path.size():
			next()
		else:
			dir = pfeet.global_position.direction_to(leg_path[leg_i])
		# stuck detection
		if pfeet.global_position.distance_to(last_pos) < 0.5: stuck_t += delta
		else: stuck_t = 0.0
		if stuck_t > 2.0:
			print("%6.2f PLAYER STUCK at %s heading %s" % [t, pfeet.global_position, s]); next()
	last_pos = pfeet.global_position
	SignalBus.joystick_moved.emit(dir)
	if keep_target != null and comp.current_state != comp.State.GO_TO_TARGET:
		comp.send_to_position(keep_target)
	# camera frames both characters
	cam.global_position = cam.global_position.lerp((pfeet.global_position + cfeet.global_position) / 2.0, 0.1)
	log_t -= delta
	if log_t <= 0.0:
		log_t = 0.5
		print("%6.2f P%s L%d | C%s L%d state=%d crumbs=%s dist=%.0f" % [t, pfeet.global_position.round(), lvl(player),
			cfeet.global_position.round(), lvl(comp), comp.current_state,
			str(comp.level_crossings.map(func(c): return [c.position.round(), c.level])) if "level_crossings" in comp else "n/a",
			pfeet.global_position.distance_to(cfeet.global_position)])
	shot_t -= delta
	if shot_t <= 0.0 and out != "":
		shot_t = 1.0; shot_n += 1
		get_viewport().get_texture().get_image().save_png("%s/%s_%03d.png" % [out, name_, shot_n])

func next():
	step += 1; leg_t = 0.0; leg_path = PackedVector2Array(); leg_i = 0; wait_t = 0.0; stuck_t = 0.0
	if step < steps.size(): start_leg()

func finish():
	var ok = lvl(player) == lvl(comp) and pfeet.global_position.distance_to(cfeet.global_position) < 200
	print("RESULT %s: player L%d comp L%d dist %.0f -> %s" % [name_, lvl(player), lvl(comp),
		pfeet.global_position.distance_to(cfeet.global_position), "PASS" if ok else "FAIL"])
	get_tree().quit()
