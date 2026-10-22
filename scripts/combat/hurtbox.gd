class_name Hurtbox
extends Area2D

# Receives hits from Hitbox components. Forwards to HealthComponent.
# Add to "hurtbox" group so hitboxes can find it.

signal hit_received(hit_data: HitData)
signal hit_blocked(hit_data: HitData)  # For guard/parry systems later

@export var health_component_path: NodePath = ^"../HealthComponent"
@export var knockback_multiplier: float = 1.0

var _health_component: HealthComponent
var _hit_history: Array[int] = []  # Track recent hit IDs to prevent multi-hit
const MAX_HIT_HISTORY = 8


func _ready() -> void:
	collision_layer = 1 << 6  # Layer 7 (index 6) = enemy hurtbox
	collision_mask = 1 << 3   # Layer 4 (index 3) = player hitbox
	monitoring = true
	monitorable = false
	add_to_group(&"hurtbox")

	_health_component = get_node_or_null(health_component_path)
	if _health_component == null:
		push_error("Hurtbox: HealthComponent not found at path " + str(health_component_path))


func receive_hit(hit: HitData) -> bool:
	# Returns true if hit was processed, false if blocked/ignored.
	if _health_component == null:
		return false
	if not _health_component.is_instance_valid():
		return false

	# Prevent duplicate hits from same attack
	if hit.hit_id != 0 and hit.hit_id in _hit_history:
		return false

	# Try to apply damage
	if _health_component.take_damage(hit):
		_hit_history.append(hit.hit_id)
		if _hit_history.size() > MAX_HIT_HISTORY:
			_hit_history.pop_front()
		hit_received.emit(hit)
		return true
	else:
		hit_blocked.emit(hit)
		return false


func clear_hit_history() -> void:
	_hit_history.clear()