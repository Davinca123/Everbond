extends Node

# --- DIALÓGUS JELZÉSEK ---
signal dialogue_started(speaker_name: String, lines: Array[String])
signal dialogue_finished

# --- IRÁNYÍTÁS JELZÉSEK ---
signal joystick_moved(direction: Vector2)
signal interaction_pressed

# Ez a két szignál kezeli az UI gomb megjelenítését és elrejtését
signal show_interaction_button(interaction_type: String)
signal hide_interaction_button

# --- KÍSÉRŐ / SZIMBIÓZIS JELZÉSEK ---
signal companion_obedience_changed(new_level: int)
signal companion_leveled_up(new_form: String)

# --- HARC ÉS ÉLET JELZÉSEK ---
signal player_health_changed(current_health: int, max_health: int)
signal player_died
