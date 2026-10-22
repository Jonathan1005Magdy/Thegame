class_name HitData
extends RefCounted

# Immutable data packet sent from a Hitbox to a Hurtbox.
# All fields are set at construction; no setters.

var damage: int = 1
var knockback: Vector2 = Vector2.ZERO
var hitstun: float = 0.2
var source: Node = null
var hit_direction: int = 1  # 1 = right, -1 = left
var hit_id: int = 0  # Unique ID to prevent multi-hits from same attack
var can_guard: bool = false
var guard_damage: int = 0
var element: StringName = &"physical"  # For future elemental systems


func _init(
	p_damage: int = 1,
	p_knockback: Vector2 = Vector2.ZERO,
	p_hitstun: float = 0.2,
	p_source: Node = null,
	p_hit_direction: int = 1,
	p_hit_id: int = 0,
	p_can_guard: bool = false,
	p_guard_damage: int = 0,
	p_element: StringName = &"physical"
) -> void:
	damage = p_damage
	knockback = p_knockback
	hitstun = p_hitstun
	source = p_source
	hit_direction = p_hit_direction
	hit_id = p_hit_id
	can_guard = p_can_guard
	guard_damage = p_guard_damage
	element = p_element


func with_hit_id(new_id: int) -> HitData:
	return HitData.new(damage, knockback, hitstun, source, hit_direction, new_id, can_guard, guard_damage, element)


func with_source(new_source: Node) -> HitData:
	return HitData.new(damage, knockback, hitstun, new_source, hit_direction, hit_id, can_guard, guard_damage, element)