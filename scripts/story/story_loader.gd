class_name StoryLoader
extends Node

# StoryLoader reads your already-written story text as data.
# Not an autoload - call it from story scripts when you need a text file.

func load_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("StoryLoader: not found: " + path)
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text
