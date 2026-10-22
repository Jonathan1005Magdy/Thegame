class_name HealthComponent
extends Node

# Reusable health component. Attach to any entity that can take damage.
# Does not assume CharacterBody2D or any specific movement.

signal health_changed(current_health: int, max_health: int)
signal died
signal damaged(damage: int, hit_data: HitData)
signal healed(amount: int)

@export var max_health: int = 3
@export var invulnerability_time: float = 0.5

var current_health: int = 3

var _invulnerability_timer: float = 0.0
var _last_hit_id: int = -1


func _ready() -> void:
	current_health = max_health


func _process(delta: float) -> void:
	if _invulnerability_timer > 0.0:
		_invulnerability_timer -= delta


func take_damage(hit: HitData) -> bool:
	# Returns true if damage was applied, false if blocked (invulnerable, dead, duplicate hit).
	if current_health <= 0:
		return false
	if _invulnerability_timer > 0.0:
		return false
	if hit.hit_id == _last_hit_id and hit.hit_id != 0:
		return false

	_last_hit_id = hit.hit_id
	current_health = maxi(current_health - hit.damage, 0)
	_invulnerability_timer = invulnerability_time

	damaged.emit(hit.damage, hit)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		died.emit()
	return true


func heal(amount: int) -> void:
	if current_health <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)


func set_health(new_health: int) -> void:
	current_health = clampi(new_health, 0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		died.emit()
	# Reset invulnerability when health is explicitly set (e.g., respawning)
	if current_health > 0:
		_invulnerability_timer = 0.0
		_last_hit_id = -1


func is_invulnerable() -> bool:
	return _invulnerability_timer > 0.0


func get_invulnerability_timer() -> float:
	return _invulnerability_timer


func get_health_ratio() -> float:
	return float(current_health) / float(max_health)


func clear_invulnerability() -> void:
	_invulnerability_timer = 0.0
	_last_hit_id = -1