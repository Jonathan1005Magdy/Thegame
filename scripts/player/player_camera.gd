class_name PlayerCamera
extends Camera2D

# Camera2D child of the player. The camera position is smoothed by Camera2D,
# while this script smoothly shifts its offset toward the direction the player faces.
# Also applies camera shake from CameraEffects.

@export var target_path: NodePath = ^".."
@export var look_ahead_enabled: bool = true
@export var look_ahead_distance: float = 38.0
@export var look_ahead_smoothing: float = 3.0
@export var smoothing_speed: float = 7.0

var _target: Node2D
var _look_ahead_x: float = 0.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed

	if _target is PlayerController and look_ahead_enabled:
		_look_ahead_x = float(_target.facing_direction) * look_ahead_distance
	offset.x = _look_ahead_x


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = get_node_or_null(target_path) as Node2D
		return

	var desired_x: float = 0.0
	if look_ahead_enabled and _target is PlayerController:
		desired_x = float(_target.facing_direction) * look_ahead_distance

	# Exponential smoothing is frame-rate independent.
	# A value of 0 means "snap immediately".
	var weight: float = 1.0
	if look_ahead_smoothing > 0.0:
		weight = 1.0 - exp(-look_ahead_smoothing * delta)
	_look_ahead_x = lerpf(_look_ahead_x, desired_x, weight)
	offset.x = _look_ahead_x

	# Apply camera shake offset
	if is_instance_valid(CameraEffects.instance):
		offset += CameraEffects.instance.get_shake_offset()
