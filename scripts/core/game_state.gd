class_name GameState
extends Node

# GameState holds runtime data that survives scene changes.
# Story / dialogue text is loaded as data from res://resources/story/ and never hard-coded here.

signal state_changed
signal flag_changed(flag_name: String, value: bool)

var current_scene: String = "res://scenes/test_room.tscn"
var player_position: Vector2 = Vector2(100, 300)
var player_health: int = 4
var player_max_health: int = 4
var coins: int = 0
var flags: Dictionary = {}  # e.g. {"door_a_opened": true}

func set_flag(flag_name: String, value: bool) -> void:
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)

func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name) and flags[flag_name]

func to_dict() -> Dictionary:
	return {
		"current_scene": current_scene,
		"player_position": player_position,
		"player_health": player_health,
		"player_max_health": player_max_health,
		"coins": coins,
		"flags": flags,
	}

func from_dict(data: Dictionary) -> void:
	current_scene = data.get("current_scene", current_scene)
	player_position = data.get("player_position", player_position)
	player_health = data.get("player_health", player_health)
	player_max_health = data.get("player_max_health", player_max_health)
	coins = data.get("coins", coins)
	flags = data.get("flags", {})
