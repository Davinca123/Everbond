extends Node

# --- DIALÓGUS JELZÉSEK ---
signal dialogue_started(speaker_name: String, lines: Array[String])
signal dialogue_finished

# --- IRÁNYÍTÁS JELZÉSEK ---
signal joystick_moved(direction: Vector2)

# --- KÍSÉRŐ / SZIMBIÓZIS JELZÉSEK ---
signal companion_obedience_changed(new_level: int)
signal companion_leveled_up(new_form: String)

# --- HARC ÉS ÉLET JELZÉSEK ---
signal player_health_changed(current_health: int, max_health: int)
signal player_died

