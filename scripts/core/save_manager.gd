extends Node

# SaveManager reads/writes GameState to user://saves/ as JSON.

const SAVE_DIR := "user://saves/"
const EXTENSION := ".json"

var current_slot: int = 1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _get_path(slot: int) -> String:
	return SAVE_DIR + "slot_" + str(slot) + EXTENSION

func save_game(slot: int) -> bool:
	current_slot = slot
	var data: Dictionary = GameState.to_dict()
	var json: String = JSON.stringify(data)
	var file: FileAccess = FileAccess.open(_get_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not write " + _get_path(slot))
		return false
	file.store_string(json)
	file.close()
	return true

func load_game(slot: int) -> bool:
	var path: String = _get_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	var error := parser.parse(json)
	if error != OK:
		push_error("SaveManager: invalid JSON in " + path)
		return false
	if not parser.data is Dictionary:
		push_error("SaveManager: save data is not a dictionary in " + path)
		return false
	GameState.from_dict(parser.data)
	current_slot = slot
	return true

func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_path(slot))

func clear_save(slot: int) -> void:
	var path: String = _get_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
