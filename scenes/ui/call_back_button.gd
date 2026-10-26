extends TouchScreenButton

# Visszahívó gomb: csak addig látszik, amíg a lény egy koppintott pont felé tart vagy ott
# vár. Megnyomva (vagy PC-n a Q, "call_back" billentyűvel) a lény visszajön a hőshöz.

func _ready() -> void:
	hide()
	SignalBus.companion_sent.connect(func(_target): show())
	SignalBus.companion_stay_finished.connect(func(_full): hide())
	SignalBus.companion_recalled.connect(hide)
	SignalBus.companion_returned.connect(hide)
	pressed.connect(_on_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("call_back"):
		get_viewport().set_input_as_handled()
		_on_pressed()

func _on_pressed() -> void:
	SignalBus.companion_recalled.emit()
