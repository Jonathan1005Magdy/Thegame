extends Node

# AudioManager plays one music stream and one SFX stream at a time.

const MUSIC_BUS := "Bus/Music"
const SFX_BUS := "Bus/Sfx"

var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
var sfx_player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()

var music_volume: float = 0.7
var sfx_volume: float = 0.8

func _ready() -> void:
	add_child(music_player)
	add_child(sfx_player)
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)

func _set_bus_volume(bus_name: String, volume: float) -> void:
	var bus: int = AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(volume))

func play_music(path: String, loop: bool = true) -> void:
	var stream: AudioStream = load(path)
	if stream == null:
		push_error("AudioManager: music not found: " + path)
		return
	music_player.stream = stream
	music_player.loop = loop
	music_player.play()

func stop_music(fade_sec: float = 0.0) -> void:
	music_player.stop()

func play_sfx(path: String, position: Vector2 = Vector2.ZERO) -> void:
	var stream: AudioStream = load(path)
	if stream == null:
		push_error("AudioManager: sfx not found: " + path)
		return
	sfx_player.position = position
	sfx_player.stream = stream
	sfx_player.play()
