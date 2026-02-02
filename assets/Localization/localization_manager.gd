extends Node

signal language_changed(lang: String)

var languages = ["en", "es"]
var current_language_index = 1

func _ready() -> void:
	_apply_language()

func next_language() -> void:
	current_language_index = (current_language_index + 1) % languages.size()
	_apply_language()

func _apply_language() -> void:
	var lang = languages[current_language_index]
	TranslationServer.set_locale(lang)
	language_changed.emit(lang)
	print("[LocalizationManager] Idioma cambiado a:", lang)

func get_text(key: String) -> String:
	return tr(key)
