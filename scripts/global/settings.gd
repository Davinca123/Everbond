# settings.gd
extends Node

# A játékos beállításai, a user://settings.cfg fájlban megőrizve.
# Egyelőre csak a nyelv: a szövegek a localization/texts.csv-ben vannak, kulcsokkal
# (pl. "UI_INTERACT_CHAT"); a kódban tr()-rel, a Label-ekben automatikusan fordulnak.

const SETTINGS_PATH: String = "user://settings.cfg"
## A választható nyelvek (a texts.csv oszlopai)
const LANGUAGES: Array[String] = ["en", "hu"]
const DEFAULT_LANGUAGE: String = "en"

var language: String = DEFAULT_LANGUAGE

func _ready() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	# Első indításkor a rendszer nyelve, ha van hozzá fordítás
	var system_language: String = OS.get_locale_language()
	var fallback: String = system_language if LANGUAGES.has(system_language) else DEFAULT_LANGUAGE
	set_language(config.get_value("general", "language", fallback), false)

func set_language(code: String, save: bool = true) -> void:
	if not LANGUAGES.has(code):
		push_warning("Ismeretlen nyelv: %s" % code)
		code = DEFAULT_LANGUAGE
	language = code
	TranslationServer.set_locale(code)
	if save:
		var config := ConfigFile.new()
		config.load(SETTINGS_PATH)
		config.set_value("general", "language", code)
		config.save(SETTINGS_PATH)
	SignalBus.language_changed.emit(code)
