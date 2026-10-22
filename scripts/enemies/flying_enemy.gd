extends BaseEnemy

# Flying enemy that patrols in air, shoots projectiles at player.
# Uses gravity_scale = 0 for floating.

@export_group("Flight")
@export var float_height: float = 200.0  # Target height above ground
@export var float_speed: float = 60.0
@export var vertical_bob: float = 15.0
@export var bob_speed: float = 1.5

@export_group("Ranged Attack")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
@export var projectile_damage: int = 1
@export var projectile_knockback: Vector2 = Vector2(120.0, -80.0)
@export var shoot_cooldown: float = 2.5
@export var shoot_range: float = 280.0
@export var aim_height_offset: float = -10.0  # Aim slightly down at player


var _float_timer: float = 0.0
var _shoot_timer: float = 0.0
var _ground_y: float = 0.0


func _ready() -> void:
	# Flying enemies don't use gravity
	gravity_scale = 0.0
	_patrol_origin_x = global_position.x
	# Find ground level below spawn
	_ground_y = _find_ground_y()
	super._ready()

	max_health = 2
	move_speed = 40.0
	chase_speed = 60.0
	detection_range = 300.0
	attack_range = shoot_range
	attack_cooldown = shoot_cooldown
	recovery_time = 0.4
	hurt_time = 0.3
	patrol_distance = 150.0
	patrol_pause_time = 1.5
	contact_damage = 1
	reward_item_id = "coin"
	reward_amount = 2


func _find_ground_y() -> float:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = global_position
	var to: Vector2 = from + Vector2(0.0, 1000.0)
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	params.collision_mask = 1  # World layer
	var result: Dictionary = space_state.intersect_ray(params)
	if not result.is_empty():
		return (result.position as Vector2).y
	return global_position.y + 200.0


func _physics_process(delta: float) -> void:
	_float_timer += delta
	_shoot_timer = maxf(_shoot_timer - delta, 0.0)

	# Apply floating motion
	var target_y: float = _ground_y - float_height + sin(_float_timer * bob_speed) * vertical_bob
	velocity.y = (target_y - global_position.y) * 5.0
	velocity.y = clampf(velocity.y, -float_speed, float_speed)

	super._physics_process(delta)


func _process_patrol(delta: float) -> void:
	# Air patrol: move horizontally, bounce at bounds
	var target_speed: float = move_speed * float(facing_direction)
	velocity.x = move_toward(velocity.x, target_speed, 400.0 * delta)

	var at_target: bool = absf(global_position.x - _patrol_target_x) < 12.0
	if at_target:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if _patrol_timer <= 0.0:
			_turn_around()
			_patrol_timer = patrol_pause_time

	if _can_see_player:
		_change_state(State.CHASE)


func _process_chase(delta: float) -> void:
	if _player == null:
		_change_state(State.PATROL)
		return

	var direction_to_player: int = 1 if _player.global_position.x > global_position.x else -1
	facing_direction = direction_to_player

	var distance: float = global_position.distance_to(_player.global_position)

	if distance <= attack_range and _shoot_timer <= 0.0:
		_change_state(State.ATTACK)
		return

	if not _can_see_player:
		_chase_timer += delta
		if _chase_timer > 4.0:
			_change_state(State.PATROL)
		return

	_chase_timer = 0.0
	var target_speed: float = chase_speed * float(facing_direction)
	velocity.x = move_toward(velocity.x, target_speed, 500.0 * delta)


func _start_attack() -> void:
	# Shoot a projectile toward player
	_shoot_timer = shoot_cooldown
	_shoot_projectile()


func _shoot_projectile() -> void:
	if projectile_scene == null:
		push_error("FlyingEnemy: projectile_scene not assigned")
		return
	if _player == null:
		return

	var proj: Area2D = projectile_scene.instantiate()
	if proj == null:
		return

	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector2(facing_direction * 20.0, aim_height_offset)

	var direction: Vector2 = (_player.global_position - proj.global_position).normalized()
	if proj.has_method("launch"):
		proj.launch(direction * projectile_speed, projectile_damage, projectile_knockback, self)