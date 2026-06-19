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
	
	# Dinamikusan átírja a saját feliratát
	match type:
		"chat":
			label.text = "Beszéd"
		"loot":
			label.text = "Felvesz"
		"chest":
			label.text = "Kinyit"
		_:
			label.text = "Interakció"

func _on_hide_interaction() -> void:
	hide()

func _on_pressed() -> void:
	# Ha megnyomtak, jelzi a SignalBus-on az NPC-nek
	SignalBus.interaction_pressed.emit()
