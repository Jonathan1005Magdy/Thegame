extends Node

# SceneManager loads and unloads scenes by file path.

var current_scene_path: String = ""

func change_scene(path: String) -> void:
	current_scene_path = path
	get_tree().change_scene_to_file(path)

func reload_current_scene() -> void:
	if current_scene_path != "":
		get_tree().change_scene_to_file(current_scene_path)

func get_current_scene_path() -> String:
	return current_scene_path
