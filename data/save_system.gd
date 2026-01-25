extends Node
class_name SaveSystem
# Este script se encarga exclusivamente de
# escribir y leer el estado de la run desde disco


const SAVE_PATH := "user://save_run.json"
# Ruta del archivo de guardado (carpeta segura de usuario)


# =========================
# API PÚBLICA
# =========================

static func save_run(collection: PlayerCollection) -> void:
	# Guarda la run actual en disco
	var data := Serialization.player_collection_to_dict(collection)
	# Convierte la colección del jugador a datos planos

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	# Abre (o crea) el archivo de guardado en modo escritura

	if file == null:
		# Maneja error si no se pudo abrir el archivo
		push_error("No se pudo abrir archivo de guardado")
		return

	file.store_string(JSON.stringify(data))
	# Escribe el JSON convertido a string en el archivo

	file.close()
	# Cierra el archivo correctamente


static func load_run() -> PlayerCollection:
	# Carga una run guardada desde disco

	if not FileAccess.file_exists(SAVE_PATH):
		# Si no existe archivo de guardado, no hay run previa
		push_warning("No existe save, creando run nueva")
		return null

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	# Abre el archivo en modo lectura

	if file == null:
		# Maneja error si no se pudo abrir
		push_error("No se pudo abrir archivo de guardado")
		return null

	var content := file.get_as_text()
	# Lee todo el contenido del archivo como texto

	file.close()
	# Cierra el archivo

	var json := JSON.new()
	# Crea un parser JSON

	var err := json.parse(content)
	# Intenta parsear el texto a datos JSON

	if err != OK:
		# Maneja error si el JSON está corrupto
		push_error("Error parseando JSON")
		return null

	return Serialization.player_collection_from_dict(json.data)
	# Reconstruye y devuelve la PlayerCollection desde los datos
