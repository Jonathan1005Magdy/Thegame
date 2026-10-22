extends Node

# Camera shake and hit-stop (frame freeze) manager.
# Call CameraEffects.shake() and CameraEffects.hit_stop() from anywhere.
# Both effects are toggleable via settings.

signal shake_started(intensity: float, duration: float)
signal hit_stop_started(duration: float)

# Singleton instance
static var instance: Node = null

@export var shake_enabled: bool = true
@export var hit_stop_enabled: bool = true
@export var max_shake_intensity: float = 16.0
@export var default_shake_decay: float = 25.0

var _current_shake: float = 0.0
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_decay: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO

var _hit_stop_time: float = 0.0
var _hit_stop_duration: float = 0.0
var _was_processing: bool = false


func _ready() -> void:
	CameraEffects.instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS  # Run during hit-stop too


func _process(delta: float) -> void:
	# Hit-stop freezes everything except this node (PROCESS_MODE_ALWAYS)
	if _hit_stop_time > 0.0:
		_hit_stop_time -= delta
		if _hit_stop_time <= 0.0:
			_hit_stop_time = 0.0
			Engine.time_scale = 1.0
		return

	# Camera shake decay
	if _shake_time > 0.0:
		_shake_time -= delta
		_current_shake = lerpf(_current_shake, 0.0, _shake_decay * delta)
		if _shake_time <= 0.0:
			_shake_time = 0.0
			_current_shake = 0.0
			_shake_offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	# Apply shake offset to current camera
	if _current_shake > 0.1 and _shake_time > 0.0:
		var angle: float = randf_range(0.0, TAU)
		var radius: float = randf_range(0.0, _current_shake)
		_shake_offset = Vector2(cos(angle), sin(angle)) * radius


func get_shake_offset() -> Vector2:
	return _shake_offset


func shake(intensity: float, duration: float = 0.15, decay: float = -1.0) -> void:
	if not shake_enabled:
		return
	intensity = clampf(intensity, 0.0, max_shake_intensity)
	if intensity <= 0.0 or duration <= 0.0:
		return
	_current_shake = intensity
	_shake_time = duration
	_shake_duration = duration
	_shake_decay = decay if decay > 0.0 else default_shake_decay
	shake_started.emit(intensity, duration)


func hit_stop(duration: float = 0.05) -> void:
	if not hit_stop_enabled:
		return
	if duration <= 0.0:
		return
	_hit_stop_time = duration
	_hit_stop_duration = duration
	Engine.time_scale = 0.0
	hit_stop_started.emit(duration)


func set_shake_enabled(enabled: bool) -> void:
	shake_enabled = enabled


func set_hit_stop_enabled(enabled: bool) -> void:
	hit_stop_enabled = enabled
	if not enabled:
		Engine.time_scale = 1.0
		_hit_stop_time = 0.0


func is_shake_active() -> bool:
	return _shake_time > 0.0


func is_hit_stop_active() -> bool:
	return _hit_stop_time > 0.0