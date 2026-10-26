extends TouchScreenButton

# Ha raktál alá egy Label-t a feliratnak, így éred el:
@onready var label: Label = $Label 

func _ready() -> void:
	hide() # Alapból elrejtjük magunkat
	
	# Maga a gomb iratkozik fel a globális eseményekre
	SignalBus.show_interaction_button.connect(_on_show_interaction)
	SignalBus.hide_interaction_button.connect(_on_hide_interaction)
	
	# Magához köti a saját megnyomását
	pressed.connect(_on_pressed)

func _on_show_interaction(type: String) -> void:
	show()
	print("gomb")
	
	# Dinamikusan átírja a saját feliratát
	match type:
		"chat":
			label.text = "Beszéd"
		"loot":
			label.text = "Felvesz"
		"chest":
			label.text = "Kinyit"
		"door_enter":
			label.text = "Belép"
		_:
			label.text = "Interakció"

func _on_hide_interaction() -> void:
	hide()

# PC-n az "interact" billentyű (E, szóköz, Enter) is megnyomja a gombot, amíg látszik.
# Az _unhandled_input-ban: ha épp dialógus van, azt a dialógus ablak már lekezelte.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_on_pressed()

func _on_pressed() -> void:
	# Ha megnyomtak, jelzi a SignalBus-on az NPC-nek
	SignalBus.interaction_pressed.emit()
