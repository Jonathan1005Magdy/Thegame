class_name BaseEnemy
extends CharacterBody2D

# Base enemy with patrol, edge detection, player detection, attack, recovery, death.
# Extend this for specific enemy types.

signal state_changed(previous_state: StringName, new_state: StringName)
signal died
signal attacked
signal detected_player
signal lost_player

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	RECOVERY,
	HURT,
	DEATH,
}

const STATE_NAMES: Dictionary = {
	State.IDLE: &"idle",
	State.PATROL: &"patrol",
	State.CHASE: &"chase",
	State.ATTACK: &"attack",
	State.RECOVERY: &"recovery",
	State.HURT: &"hurt",
	State.DEATH: &"death",
}

@export_group("Stats")
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var move_speed: float = 60.0
@export var chase_speed: float = 90.0
@export var detection_range: float = 200.0
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.5
@export var recovery_time: float = 0.6
@export var hurt_time: float = 0.3
@export var knockback_resistance: float = 0.5

@export_group("Patrol")
@export var patrol_distance: float = 120.0
@export var patrol_pause_time: float = 1.0
@export var turn_at_edges: bool = true
@export var turn_at_walls: bool = true

@export_group("Rewards")
@export var reward_item_id: String = "coin"
@export var reward_amount: int = 1
@export var reward_drop_chance: float = 1.0

@export_group("Visuals")
@export var sprite_path: NodePath = ^"AnimatedSprite2D"

var current_state: int = State.IDLE
var facing_direction: int = 1
var _patrol_origin_x: float = 0.0
var _patrol_target_x: float = 0.0
var _patrol_timer: float = 0.0
var _chase_timer: float = 0.0
var _attack_timer: float = 0.0
var _recovery_timer: float = 0.0
var _hurt_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _can_see_player: bool = false
var _player: Node2D = null

@onready var sprite: AnimatedSprite2D = get_node_or_null(sprite_path)


func _ready() -> void:
	add_to_group(&"enemies")
	_patrol_origin_x = global_position.x
	_patrol_target_x = _patrol_origin_x + patrol_distance * float(facing_direction)
	_find_player()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_update_detection()

	if current_state == State.DEATH:
		return

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.RECOVERY:
			_process_recovery(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()
	_update_facing()
	_play_animation()


func _tick_timers(delta: float) -> void:
	_patrol_timer = maxf(_patrol_timer - delta, 0.0)
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_recovery_timer = maxf(_recovery_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)


func _update_detection() -> void:
	if _player == null or not is_instance_valid(_player):
		_find_player()
		return

	var distance: float = global_position.distance_to(_player.global_position)
	var was_seeing: bool = _can_see_player
	_can_see_player = distance <= detection_range

	if _can_see_player and not was_seeing:
		detected_player.emit()
		_chase_timer = 0.0
	elif not _can_see_player and was_seeing:
		lost_player.emit()


func _find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		_player = players[0] as Node2D


func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	if patrol_distance > 0.1:
		_change_state(State.PATROL)


func _process_patrol(delta: float) -> void:
	var target_speed: float = move_speed * float(facing_direction)

	if turn_at_edges and _is_at_edge():
		_turn_around()
		return

	if turn_at_walls and _is_at_wall():
		_turn_around()
		return

	var at_target: bool = absf(global_position.x - _patrol_target_x) < 8.0
	if at_target:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		if _patrol_timer <= 0.0:
			_turn_around()
			_patrol_timer = patrol_pause_time
	else:
		velocity.x = move_toward(velocity.x, target_speed, 800.0 * delta)

	if _can_see_player:
		_change_state(State.CHASE)


func _process_chase(delta: float) -> void:
	if _player == null:
		_change_state(State.PATROL)
		return

	var direction_to_player: int = 1 if _player.global_position.x > global_position.x else -1
	facing_direction = direction_to_player

	var distance: float = global_position.distance_to(_player.global_position)

	if distance <= attack_range and _attack_cooldown_timer <= 0.0:
		_change_state(State.ATTACK)
		return

	if not _can_see_player:
		_chase_timer += delta
		if _chase_timer > 3.0:
			_change_state(State.PATROL)
		return

	_chase_timer = 0.0
	var target_speed: float = chase_speed * float(facing_direction)
	velocity.x = move_toward(velocity.x, target_speed, 1000.0 * delta)


func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	if _attack_timer <= 0.0:
		_start_attack()


func _process_recovery(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)

	if _recovery_timer <= 0.0:
		_change_state(_can_see_player ? State.CHASE : State.PATROL)


func _process_hurt(delta: float) -> void:
	var drag: float = 600.0 if is_on_floor() else 200.0
	velocity.x = move_toward(velocity.x, 0.0, drag * delta)

	if _hurt_timer <= 0.0:
		_change_state(_can_see_player ? State.CHASE : State.PATROL)


func _change_state(new_state: int) -> void:
	if new_state == current_state:
		return

	var prev_name: StringName = STATE_NAMES[current_state]
	var new_name: StringName = STATE_NAMES[new_state]
	current_state = new_state

	match new_state:
		State.PATROL:
			_patrol_target_x = global_position.x + patrol_distance * float(facing_direction)
			_patrol_timer = 0.0
		State.ATTACK:
			_attack_timer = 0.3
			_attack_cooldown_timer = attack_cooldown
		State.RECOVERY:
			_recovery_timer = recovery_time
		State.HURT:
			_hurt_timer = hurt_time
		State.DEATH:
			collision_layer = 0
			collision_mask = 0

	state_changed.emit(prev_name, new_name)


func _on_health_changed(current: int, max_h: int) -> void:
	pass


func _on_damaged(damage: int, hit: Object) -> void:
	if current_state == State.DEATH:
		return
	_change_state(State.HURT)

	var kb: Vector2 = hit.knockback * knockback_resistance
	if hit.hit_direction != 0:
		kb.x *= float(hit.hit_direction)
	velocity = kb


func _on_death() -> void:
	_change_state(State.DEATH)
	_drop_reward()
	died.emit()


func _on_hit_connected(hurtbox: Area2D, hit: Object) -> void:
	attacked.emit()
	_change_state(State.RECOVERY)


func _drop_reward() -> void:
	if reward_item_id.is_empty():
		return
	if randf() > reward_drop_chance:
		return
	if is_instance_valid(RewardManager):
		RewardManager.grant_item(reward_item_id, reward_amount)


func _turn_around() -> void:
	facing_direction *= -1
	_patrol_target_x = global_position.x + patrol_distance * float(facing_direction)
	_patrol_timer = patrol_pause_time


func _is_at_edge() -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = global_position + Vector2(facing_direction * 20.0, 10.0)
	var to: Vector2 = from + Vector2(0.0, 30.0)
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	params.collision_mask = 1
	var result: Dictionary = space_state.intersect_ray(params)
	return result.is_empty()


func _is_at_wall() -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = global_position + Vector2(0.0, -10.0)
	var to: Vector2 = from + Vector2(facing_direction * 18.0, 0.0)
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	params.collision_mask = 1
	var result: Dictionary = space_state.intersect_ray(params)
	return not result.is_empty()


func _update_facing() -> void:
	if sprite != null:
		sprite.flip_h = facing_direction < 0


func _play_animation() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim_name: StringName = STATE_NAMES[current_state]
	if not sprite.sprite_frames.has_animation(anim_name):
		anim_name = &"idle"
	if sprite.animation != anim_name:
		sprite.play(anim_name)


func _start_attack() -> void:
	pass


func get_state_name() -> StringName:
	return STATE_NAMES[current_state]


func is_alive() -> bool:
	return current_state != State.DEATH