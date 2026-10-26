extends SceneTree
# Teszt a lény jelzőjéhez (scenes/ui/companion_hud.gd), a teszt kapcsolókhoz
# (scenes/ui/test_toggle_button.gd) és a kezdő falatokhoz.
#
# Futtatás (a projekt mappájából):
#   godot --headless --path . -s res://test/hud_test.gd
# Kilépési kód 0 = minden eset PASS.

var failures: int = 0

func check(name: String, ok: bool, detail: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok: failures += 1

func _initialize() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	run.call_deferred()

func run() -> void:
	await create_timer(1.0).timeout
	var data = root.get_node("PlayerData")
	var ui = root.get_node("Main/ScreenUI")
	var map = root.get_node("SceneManager").current_map
	var comp = map.get_node("YSort_Entities/Companion")
	var player = map.get_node("YSort_Entities/Player")

	# 1. Tíz falattal indul
	check("starts_with_ten_treats", data.treats == 10, str(data.treats))

	# 2. A jelző a jobb felső sarokban van, a körben a lény sprite-ja, ugyanazzal a képkockával
	var hud = ui.get_node("CompanionHud")
	var sprite: Sprite2D = comp.get_node("Sprite2D")
	var rect: Rect2 = hud.get_global_rect()
	var screen: Vector2 = hud.get_viewport_rect().size
	check("hud_top_right_with_fox", rect.end.x > screen.x - 60 and rect.position.y < 60 and hud.fox.texture == sprite.texture
			and hud.fox.frame == sprite.frame, "rect=%s screen=%s frame=%d/%d" % [rect, screen, hud.fox.frame, sprite.frame])

	# 3. A várakozás kapcsoló: végtelen, a lény a következő megérkezéstől nem jön vissza; majd vissza a szinthez
	var stay_toggle = ui.get_node("StayToggle")
	var range_toggle = ui.get_node("RangeToggle")
	stay_toggle.pressed.emit()
	comp.go_to_position(player.global_position + Vector2(150, 0))
	await create_timer(3.5).timeout
	var stays_forever: bool = is_inf(comp.stay_duration) and comp.is_away() and stay_toggle.text == "Stay: ∞"
	stay_toggle.pressed.emit()
	check("stay_toggle", stays_forever and data.companion_stay_duration_override == 0.0 and data.get_companion_stay_duration() == 2.0
			and stay_toggle.text == "Stay: level", "forever=%s duration=%s text=%s" % [stays_forever, comp.stay_duration, stay_toggle.text])
	root.get_node("SignalBus").companion_recalled.emit()

	# 4. A távolság kapcsoló: végtelen, a cél nincs levágva; majd vissza a szinthez
	range_toggle.pressed.emit()
	var far: Vector2 = player.get_node("CollisionShape2D").global_position + Vector2(3000, 0)
	var unclamped: bool = comp.clamp_to_send_range(far) == far and not comp.is_player_out_of_range()
	range_toggle.pressed.emit()
	check("range_toggle", unclamped and data.get_companion_send_range() == 500.0 and comp.clamp_to_send_range(far) != far
			and range_toggle.text == "Range: level", "unclamped=%s range=%.0f" % [unclamped, data.get_companion_send_range()])

	# 5. A gombok nem küldik el a lényt (blocks_taps), és a falat / visszahívó gomb a jobb alsó részen van
	var buttons_right: bool = true
	for path in ["CallBackButtonAnchor/CallBackButton", "CallBackButtonAnchor/TreatButton"]:
		var button: TouchScreenButton = ui.get_node(path)
		var at: Vector2 = button.get_global_transform() * Vector2.ZERO
		if at.x < screen.x * 0.75 or at.y < screen.y * 0.55: buttons_right = false
	check("toggles_block_taps_and_buttons_bottom_right", stay_toggle.is_in_group("blocks_taps") and range_toggle.is_in_group("blocks_taps")
			and buttons_right, "buttons_right=%s" % buttons_right)

	print("DONE: %d failure(s)" % failures)
	quit(1 if failures else 0)
