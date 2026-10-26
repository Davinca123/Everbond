extends CanvasLayer

# --- KOPPINTÁS FELISMERÉS ---
# Rövid, szinte mozdulatlan érintés = koppintás (pl. a lény elküldése egy pontra).
# A képernyő bal oldalán is működik: ott ugyanaz az érintés a joysticket is elindítja,
# de ha gyorsan elengedjük és alig mozdult, koppintásnak számít.
# A dialógus által lekezelt érintések (_unhandled_input) és a képernyő gombjait
# (TouchScreenButton) megnyomó érintések nem számítanak koppintásnak.

## Ennél tovább tartó érintés már nem koppintás (mp)
const TAP_MAX_DURATION: float = 0.3
## Ennél többet mozduló érintés már nem koppintás (képernyő pixel)
const TAP_MAX_DISTANCE: float = 20.0

# Érintésenként (ujjanként): { "position": Vector2, "time": int (ms), "moved": bool }
var touches: Dictionary = {}
# Melyik képkockában nyomtak meg utoljára egy képernyő gombot
var button_pressed_frame: int = -1

func _ready() -> void:
	# A TouchScreenButton nem jelöli lekezeltnek az érintést, ezért a gombok saját
	# pressed szignáljával jegyezzük meg, hogy ezt az érintést egy gomb kapta el.
	# (Hely alapján nem lehet nézni: pl. az interakció gomb a megnyomáskor el is tűnik.)
	for button in find_children("*", "TouchScreenButton", true, false):
		button.pressed.connect(func(): button_pressed_frame = Engine.get_process_frames())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not _is_button_press() and not _is_on_blocking_control(event.position):
				touches[event.index] = { "position": event.position, "time": Time.get_ticks_msec(), "moved": false }
		elif touches.has(event.index):
			_try_tap(touches[event.index], event.position)
			touches.erase(event.index)

	elif event is InputEventScreenDrag and touches.has(event.index):
		if event.position.distance_to(touches[event.index].position) > TAP_MAX_DISTANCE:
			touches[event.index].moved = true

	# Egérkattintás PC-s teszteléshez (az érintésből emulált egéreseményt kihagyjuk,
	# különben mobilon minden koppintás kétszer számítana)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed:
			touches[-1] = { "position": event.position, "time": Time.get_ticks_msec(), "moved": false }
		elif not event.pressed and touches.has(-1):
			_try_tap(touches[-1], event.position)
			touches.erase(-1)

func _try_tap(touch: Dictionary, release_position: Vector2) -> void:
	var duration: float = (Time.get_ticks_msec() - touch.time) / 1000.0
	if touch.moved or duration > TAP_MAX_DURATION:
		return
	if release_position.distance_to(touch.position) > TAP_MAX_DISTANCE:
		return
	SignalBus.screen_tapped.emit(touch.position)

# Az érintés egy olyan vezérlőn kezdődik (pl. a nyelvváltó gombon), amelyik nem enged koppintást
func _is_on_blocking_control(screen_position: Vector2) -> bool:
	for control in get_tree().get_nodes_in_group("blocks_taps"):
		if control.is_visible_in_tree() and control.get_global_rect().has_point(screen_position):
			return true
	return false

# Ugyanebben a képkockában egy gomb kapta el az érintést (a gombok _input-ja előbb fut)
func _is_button_press() -> bool:
	return button_pressed_frame == Engine.get_process_frames()
