class_name EnemyProjectile
extends Area2D

# Simple enemy projectile. Launched by FlyingEnemy.

signal hit_something(hit_data: HitData)

@export var lifetime: float = 4.0
@export var pierce: bool = false

var _velocity: Vector2 = Vector2.ZERO
var _damage: int = 1
var _knockback: Vector2 = Vector2.ZERO
var _owner = null
var _hit_id: int = 0
var _life_timer: float = 0.0


func _ready() -> void:
	collision_layer = 1 << 8  # Layer 9 = projectiles
	collision_mask = 1 << 5   # Layer 6 = player hurtbox
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)


func launch(velocity: Vector2, damage: int, knockback: Vector2, owner) -> void:
	_velocity = velocity
	_damage = damage
	_knockback = knockback
	_owner = owner
	_hit_id = randi()
	_life_timer = lifetime

	# Face movement direction
	rotation = _velocity.angle()


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group(&"hurtbox"):
		return
	var hurtbox: Hurtbox = area
	if hurtbox == null:
		return

	var direction: int = 1 if _velocity.x >= 0 else -1
	var hit: HitData = HitData.new(
		_damage,
		_knockback,
		0.25,
		_owner,
		direction,
		_hit_id,
		false,
		0,
		&"physical"
	)

	if hurtbox.receive_hit(hit):
		hit_something.emit(hit)
		if not pierce:
			queue_free()