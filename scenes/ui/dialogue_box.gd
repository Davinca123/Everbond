extends Control

# Az egyedi nevek (% ikon) segítségével érjük el a szövegmezőket és a Timert
@onready var name_label: Label = %NameLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var timer: Timer = $Timer

var dialog_lines: Array[String] = []
var current_line_index: int = 0
var npc_name: String = ""
var is_typing: bool = false

func _ready() -> void:
	hide() # A játék kezdetén elrejtjük a teljes ablakot
	
	# Feliratkozunk a globális SignalBus-ra
	SignalBus.connect("dialogue_started", _on_dialogue_started)
		

func _on_dialogue_started(speaker_name: String, lines: Array[String]) -> void:
	npc_name = speaker_name
	dialog_lines = lines
	current_line_index = 0
	show()          # Megjelenítjük a panelt
	display_line()  # Elindítjuk az első sor gépelését

func display_line() -> void:
	if current_line_index >= dialog_lines.size():
		finish_dialogue()
		return
		
	is_typing = true
	name_label.text = npc_name
	
	# Tisztítjuk a szöveget és nullára állítjuk a látható karaktereket
	text_label.text = dialog_lines[current_line_index]
	text_label.visible_characters = 0
	
	timer.start() # Elindítjuk a timert a gépeléshez

func _on_timer_timeout() -> void:
	if text_label.visible_characters < text_label.text.length():
		text_label.visible_characters += 1
		timer.start() # Újraindítjuk a következő betűhöz
	else:
		is_typing = false # Vége a gépelésnek, a következő kattintás már az else ágba megy!


func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	# Csak akkor lépünk be, ha az ujjunk LEÉR (pressed),
	if event is InputEventScreenTouch and event.pressed:
		# Letiltjuk, hogy a Godot továbbküldje ezt az érintést a háttérben lévő elemeknek
		get_viewport().set_input_as_handled()
		
		if is_typing:
			# 1. KATTINTÁS: Azonnal kirakja a teljes szöveget
			is_typing = false
			timer.stop()
			text_label.visible_characters = -1
		else:
			# 2. KATTINTÁS: Következő sor
			current_line_index += 1
			display_line()


func finish_dialogue() -> void:
	hide() # Elrejtjük az ablakot
	SignalBus.dialogue_finished.emit() # Jelezzük a világnak, hogy a hős újra mozoghat
