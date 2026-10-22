class_name PlayerController
extends CharacterBody2D

# Phase 2 player: movement, jump feel, dash, and a small explicit state machine.
# Story content is never stored here. This script only controls gameplay.

signal state_changed(previous_state: int, new_state: int)
signal health_changed(current_health: int, max_health: int)
signal attack_started
signal attack_finished
signal died

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	DASH,
	ATTACK,
	HURT,
	DEATH,
}

const STATE_NAMES := [
	&"idle",
	&"run",
	&"jump",
	&"fall",
	&"dash",
	&"attack",
	&"hurt",
	&"death",
]

# These states accept movement input and can start a new action.
const ACTIONABLE_STATES := [
	State.IDLE,
	State.RUN,
	State.JUMP,
	State.FALL,
]

@export_group("Movement")
@export var move_speed: float = 150.0
@export var ground_acceleration: float = 1400.0
@export var ground_friction: float = 1700.0
@export var air_acceleration: float = 850.0
@export var air_friction: float = 500.0
@export var gravity: float = 1100.0
@export var max_fall_speed: float = 520.0
@export var fall_gravity_multiplier: float = 1.35

@export_group("Jump")
@export var jump_velocity: float = 420.0
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12
@export var jump_cut_multiplier: float = 0.45

@export_group("Dash")
@export var dash_speed: float = 340.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.45
@export var air_dash_enabled: bool = true
@export var dash_gravity_scale: float = 0.15
@export var dash_end_speed_multiplier: float = 0.55

@export_group("Combat")
@export var max_health: int = 4
# The supplied spear-thrust clip has five frames at 20 fps.
@export var attack_duration: float = 0.25
@export var hurt_duration: float = 0.30
@export var hurt_knockback: Vector2 = Vector2(170.0, -170.0)
@export var invulnerability_time: float = 0.65

@export_group("Attack Hitbox")
@export var attack_damage: int = 1
@export var attack_knockback: Vector2 = Vector2(200.0, -100.0)
@export var attack_hitstun: float = 0.3
@export var attack_anticipation: float = 0.08  # Frames before hitbox activates
@export var attack_active_frames: float = 0.12  # How long hitbox stays active

@export_group("Hit Feedback")
@export var hit_flash_duration: float = 0.1
@export var hit_flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var enable_camera_shake: bool = true
@export var enable_hit_stop: bool = true
@export var hit_shake_intensity: float = 6.0
@export var hit_shake_duration: float = 0.1
@export var hit_stop_duration: float = 0.05

var current_state: int = State.IDLE
var facing_direction: int = 1
var current_health: int = 4

var _input_x: float = 0.0
var _jump_pressed: bool = false
var _jump_released: bool = false
var _dash_pressed: bool = false
var _attack_pressed: bool = false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _attack_timer: float = 0.0
var _hurt_timer: float = 0.0
var _invulnerability_timer: float = 0.0

var _dash_direction: int = 1
var _air_dash_used: bool = false
var _attack_origin_rest_x: float = 14.0

# Attack hitbox timing
var _attack_hitbox_timer: float = 0.0
var _attack_hitbox_active: bool = false
var _current_hit_id: int = 0

# Hit flash
var _hit_flash_timer: float = 0.0
var _original_modulate: Color = Color(1, 1, 1, 1)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_origin: Node2D = $AttackOrigin
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var health_component: HealthComponent = $HealthComponent


func _ready() -> void:
	add_to_group(&"player")
	_attack_origin_rest_x = absf(attack_origin.position.x)
	_original_modulate = sprite.modulate

	# Setup health component
	health_component.max_health = max_health
	health_component.invulnerability_time = invulnerability_time
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_death)
	health_component.damaged.connect(_on_damaged)

	# Sync with GameState autoload
	current_health = max_health
	if is_instance_valid(GameState):
		var saved_health: int = GameState.player_health
		current_health = saved_health if saved_health > 0 else max_health
		current_health = mini(current_health, max_health)
		GameState.player_max_health = max_health
		GameState.player_health = current_health
	health_component.current_health = current_health

	# Setup hitbox
	hitbox.setup(self)
	hitbox.base_damage = attack_damage
	hitbox.base_knockback = attack_knockback
	hitbox.base_hitstun = attack_hitstun
	hitbox.hit_connected.connect(_on_hit_connected)

	# Hurtbox already configured in scene, but ensure it's in hurtbox group
	hurtbox.add_to_group(&"hurtbox")

	_update_facing_visuals()
	_play_state_animation()
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_read_input()
	_update_floor_status(delta)

	# Handle hit flash timer
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			sprite.modulate = _original_modulate

	# Handle attack hitbox timing
	if _attack_hitbox_active:
		_attack_hitbox_timer -= delta
		if _attack_hitbox_timer <= 0.0:
			hitbox.deactivate()
			_attack_hitbox_active = false

	if current_state == State.DEATH:
		_process_death(delta)
		move_and_slide()
		return

	# Action priority: dash > attack > jump.
	# Hurt and death can only be entered through take_damage()/kill().
	if _can_act():
		if _dash_pressed and _try_start_dash():
			pass
		elif _attack_pressed:
			_start_attack()
		elif _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
			_start_jump()

	match current_state:
		State.DASH:
			_process_dash(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)
		_:
			_process_locomotion(delta)

	move_and_slide()

	_resolve_temporary_state_ends()
	_resolve_locomotion_state()
	_update_invulnerability_visual()


func _tick_timers(delta: float) -> void:
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_invulnerability_timer = maxf(_invulnerability_timer - delta, 0.0)
	# Hit flash timer handled in _physics_process for visual sync


func _read_input() -> void:
	_input_x = Input.get_axis(&"move_left", &"move_right")
	_jump_pressed = Input.is_action_just_pressed(&"jump")
	_jump_released = Input.is_action_just_released(&"jump")
	_dash_pressed = Input.is_action_just_pressed(&"dash")
	_attack_pressed = Input.is_action_just_pressed(&"attack")

	# Turning is locked during dash, attack, hurt, and death.
	if absf(_input_x) > 0.01 and _can_turn():
		facing_direction = 1 if _input_x > 0.0 else -1
		_update_facing_visuals()

	# Remember a jump pressed slightly before landing.
	if _jump_pressed and _can_act():
		_jump_buffer_timer = jump_buffer_time

	# Debug-only state tests. These actions are safe to leave out of a release build.
	if OS.is_debug_build():
		if InputMap.has_action(&"debug_hurt") and Input.is_action_just_pressed(&"debug_hurt"):
			take_damage(1, global_position - Vector2(float(facing_direction) * 80.0, 0.0))
		if InputMap.has_action(&"debug_kill") and Input.is_action_just_pressed(&"debug_kill"):
			kill()


func _update_floor_status(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		_air_dash_used = false
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)


func _can_act() -> bool:
	return current_state in ACTIONABLE_STATES


func _can_turn() -> bool:
	return current_state in ACTIONABLE_STATES


func _process_locomotion(delta: float) -> void:
	# Variable jump height: releasing jump early cuts the upward velocity once.
	if _jump_released and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	if is_on_floor():
		_move_horizontally(delta, ground_acceleration, ground_friction)
	else:
		_move_horizontally(delta, air_acceleration, air_friction)

	_apply_gravity(delta)


func _move_horizontally(delta: float, acceleration: float, friction: float) -> void:
	var target_speed: float = _input_x * move_speed
	var rate: float = acceleration if absf(_input_x) > 0.01 else friction
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)


func _apply_gravity(delta: float, scale: float = 1.0) -> void:
	var current_gravity: float = gravity
	if velocity.y > 0.0:
		current_gravity *= fall_gravity_multiplier
	velocity.y = minf(velocity.y + current_gravity * scale * delta, max_fall_speed)


# ---------------- Jump ----------------

func _start_jump() -> void:
	velocity.y = -jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_change_state(State.JUMP)


# ---------------- Dash ----------------

func _try_start_dash() -> bool:
	if _dash_cooldown_timer > 0.0:
		return false

	if not is_on_floor():
		if not air_dash_enabled or _air_dash_used:
			return false
		_air_dash_used = true

	# Dash toward held input, or straight ahead when no direction is held.
	_dash_direction = facing_direction
	if absf(_input_x) > 0.01:
		_dash_direction = 1 if _input_x > 0.0 else -1

	facing_direction = _dash_direction
	_update_facing_visuals()

	_dash_cooldown_timer = dash_cooldown
	velocity = Vector2(dash_speed * float(_dash_direction), 0.0)
	_change_state(State.DASH)
	return true


func _process_dash(delta: float) -> void:
	_dash_timer -= delta

	# DASH owns horizontal velocity until its timer expires.
	velocity.x = dash_speed * float(_dash_direction)
	_apply_gravity(delta, dash_gravity_scale)


func _end_dash() -> void:
	# Leaving the dash at full speed would feel slippery, so keep some momentum.
	velocity.x = dash_speed * float(_dash_direction) * dash_end_speed_multiplier
	_change_state(_ground_or_air_state())


# ---------------- Attack ----------------

func _start_attack() -> void:
	velocity.x = 0.0 if is_on_floor() else velocity.x * 0.85
	_change_state(State.ATTACK)
	# Generate new hit ID for this attack to prevent multi-hit
	_current_hit_id = randi()
	# Start anticipation timer before hitbox activates
	_attack_hitbox_timer = attack_anticipation
	_attack_hitbox_active = true


func _process_attack(delta: float) -> void:
	_attack_timer -= delta
	_apply_gravity(delta)

	var drag: float = ground_friction if is_on_floor() else air_friction * 0.35
	velocity.x = move_toward(velocity.x, 0.0, drag * delta)

	# Activate hitbox after anticipation
	if _attack_hitbox_active and _attack_hitbox_timer <= 0.0:
		_activate_attack_hitbox()


func _activate_attack_hitbox() -> void:
	if current_state != State.ATTACK:
		return
	hitbox.hit_id = _current_hit_id
	hitbox.base_damage = attack_damage
	hitbox.base_knockback = attack_knockback
	hitbox.base_hitstun = attack_hitstun
	hitbox.activate()
	_attack_hitbox_timer = attack_active_frames


func _end_attack() -> void:
	hitbox.deactivate()
	_attack_hitbox_active = false
	_change_state(_ground_or_air_state())


# ---------------- Hurt / death ----------------

func take_damage(amount: int, source_position: Vector2 = Vector2.INF) -> void:
	if current_state == State.DEATH:
		return
	if amount <= 0:
		return

	# Create hit data for health component
	var direction: int = 1 if source_position.x < global_position.x else -1
	var hit = HitData.new(amount, hurt_knockback, 0.2, null, direction, _current_hit_id)
	health_component.take_damage(hit)


func _on_health_changed(current: int, max_h: int) -> void:
	current_health = current
	_sync_health_to_game_state()
	health_changed.emit(current, max_h)


func _on_damaged(damage: int, hit: HitData) -> void:
	if current_state == State.DEATH:
		return

	# Hit flash
	_hit_flash_timer = hit_flash_duration
	sprite.modulate = hit_flash_color

	# Camera shake
	if enable_camera_shake and is_instance_valid(CameraEffects.instance):
		CameraEffects.instance.shake(hit_shake_intensity, hit_shake_duration)

	# Hit stop
	if enable_hit_stop and is_instance_valid(CameraEffects.instance):
		CameraEffects.instance.hit_stop(hit_stop_duration)

	# Apply knockback
	var knockback_direction: int = hit.hit_direction
	velocity = Vector2(hurt_knockback.x * float(knockback_direction), hurt_knockback.y)
	_change_state(State.HURT)


func _on_death() -> void:
	_start_death()


func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	_apply_gravity(delta)

	var drag: float = ground_friction if is_on_floor() else air_friction * 0.45
	velocity.x = move_toward(velocity.x, 0.0, drag * delta)


func _end_hurt() -> void:
	_change_state(_ground_or_air_state())


func _on_hit_connected(hurtbox: Hurtbox, hit: HitData) -> void:
	# Player attack connected with enemy
	attack_started.emit()


func kill() -> void:
	if current_state == State.DEATH:
		return
	health_component.set_health(0)


func _start_death() -> void:
	velocity = Vector2.ZERO
	_change_state(State.DEATH)


func _process_death(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	sprite.modulate.a = 1.0


# ---------------- State helpers ----------------

func _change_state(next_state: int) -> void:
	if next_state == current_state:
		return

	var previous_state: int = current_state
	current_state = next_state

	if previous_state == State.ATTACK:
		attack_finished.emit()
		hitbox.deactivate()
		_attack_hitbox_active = false

	match next_state:
		State.DASH:
			_dash_timer = dash_duration
		State.ATTACK:
			_attack_timer = attack_duration
			# Hitbox activation handled in _process_attack after anticipation
		State.HURT:
			_hurt_timer = hurt_duration
		State.DEATH:
			# Stop the hurtbox from receiving more damage after death.
			hurtbox.monitoring = false
			hurtbox.monitorable = false
			collision_layer = 0
			collision_mask = 0

	_play_state_animation()
	state_changed.emit(previous_state, next_state)


func _resolve_temporary_state_ends() -> void:
	if current_state == State.DASH and _dash_timer <= 0.0:
		_end_dash()
	elif current_state == State.ATTACK and _attack_timer <= 0.0:
		_end_attack()
	elif current_state == State.HURT and _hurt_timer <= 0.0:
		_end_hurt()


func _resolve_locomotion_state() -> void:
	# Never let normal movement overwrite dash, attack, hurt, or death.
	if current_state not in ACTIONABLE_STATES:
		return

	if is_on_floor():
		if absf(_input_x) > 0.01:
			_change_state(State.RUN)
		else:
			_change_state(State.IDLE)
	elif velocity.y < 0.0:
		_change_state(State.JUMP)
	else:
		_change_state(State.FALL)


func _ground_or_air_state() -> int:
	if is_on_floor():
		return State.IDLE
	return State.JUMP if velocity.y < 0.0 else State.FALL


func _update_facing_visuals() -> void:
	sprite.flip_h = facing_direction < 0
	attack_origin.position.x = _attack_origin_rest_x * float(facing_direction)
	attack_origin.scale.x = float(facing_direction)


func _update_invulnerability_visual() -> void:
	# Use health component's invulnerability timer
	if health_component != null and health_component.is_invulnerable():
		var blink_phase: int = int(health_component.get_invulnerability_timer() * 20.0)
		sprite.modulate.a = 0.35 if blink_phase % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0


func _sync_health_to_game_state() -> void:
	if is_instance_valid(GameState):
		GameState.player_health = current_health


# ---------------- Animation priority ----------------
# Highest priority first: death > hurt > attack > dash > jump > fall > run > idle.
# The state machine is exclusive, but this single function keeps the intended
# priority obvious if overlay animations are added later.

func _play_state_animation() -> void:
	if current_state == State.DEATH:
		_play_animation(&"death")
	elif current_state == State.HURT:
		_play_animation(&"hurt")
	elif current_state == State.ATTACK:
		_play_animation(&"attack")
	elif current_state == State.DASH:
		_play_animation(&"dash")
	elif current_state == State.JUMP:
		_play_animation(&"jump")
	elif current_state == State.FALL:
		_play_animation(&"fall")
	elif current_state == State.RUN:
		_play_animation(&"run")
	else:
		_play_animation(&"idle")


func _play_animation(animation_name: StringName) -> void:
	if sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	if sprite.animation == animation_name and sprite.is_playing():
		return
	sprite.play(animation_name)


# Public helpers for future systems (enemies, HUD, camera).
func get_state_name() -> StringName:
	return STATE_NAMES[current_state]


func is_alive() -> bool:
	return current_state != State.DEATH


func get_facing_direction() -> int:
	return facing_direction
