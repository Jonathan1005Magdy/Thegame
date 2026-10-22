class_name Hitbox
extends Area2D

# Active attack hitbox. Enable for a frame window, then disable.
# Connects to Hurtbox components on the "hurtbox" group.

signal hit_connected(hurtbox: Hurtbox, hit_data: HitData)

@export var base_damage: int = 1
@export var base_knockback: Vector2 = Vector2(150.0, -120.0)
@export var base_hitstun: float = 0.25
@export var hit_id: int = 0  # Set by attacker to track multi-hit prevention
@export var can_guard: bool = false
@export var guard_damage: int = 0
@export var element: StringName = &"physical"

var _active: bool = false
var _owner: Node = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 6  # Layer 7 (index 6) = enemy hurtbox
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)


func setup(owner: Node) -> void:
	_owner = owner


func activate(hit_id_override: int = 0) -> void:
	if hit_id_override != 0:
		hit_id = hit_id_override
	_active = true
	monitoring = true


func deactivate() -> void:
	_active = false
	monitoring = false


func is_active() -> bool:
	return _active


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if not area.is_in_group(&"hurtbox"):
		return
	var hurtbox: Hurtbox = area
	if hurtbox == null:
		return

	var direction: int = 1
	if _owner != null and hurtbox.global_position.x < _owner.global_position.x:
		direction = -1

	var hit = HitData.new(
		base_damage,
		base_knockback,
		base_hitstun,
		_owner,
		direction,
		hit_id,
		can_guard,
		guard_damage,
		element
	)

	if hurtbox.receive_hit(hit):
		hit_connected.emit(hurtbox, hit)