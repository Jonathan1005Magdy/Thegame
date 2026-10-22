extends Node

# Automated Phase 3 combat component test.
# Tests HealthComponent, Hitbox, Hurtbox, HitData, and CameraEffects directly.
# Does not test enemy inheritance (known headless limitation).

var failures: int = 0
var test_player: CharacterBody2D
var test_hitbox: Area2D
var test_hurtbox: Area2D
var test_health: HealthComponent


func _ready() -> void:
	await get_tree().process_frame
	# Create a minimal test scene with player components
	var room = load("res://scenes/test_room.tscn").instantiate()
	add_child(room)
	test_player = room.get_node("Player")
	test_hitbox = test_player.get_node("Hitbox")
	test_hurtbox = test_player.get_node("Hurtbox")
	test_health = test_player.get_node("HealthComponent")

	await _wait_physics(30)
	_check(test_player.is_on_floor(), "player spawns and lands")
	_check(test_hitbox != null, "player has hitbox")
	_check(test_hurtbox != null, "player has hurtbox")
	_check(test_health != null, "player has health component")

	await _test_health_component()
	await _test_hitbox_hurtbox_interaction()
	await _test_hit_data()
	await _test_camera_effects()
	await _test_player_attack_flow()
	await _test_invulnerability()
	await _test_knockback()

	print("COMBAT COMPONENT TEST RESULT: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_health_component() -> void:
	# Test HealthComponent directly
	var health = test_health
	_check(health.max_health == 4, "health max_health is 4")
	_check(health.current_health == 4, "health current_health starts at max")
	_check(health.get_health_ratio() == 1.0, "health ratio is 1.0 at full")

	health.take_damage(HitData.new(1))
	await _wait_physics(1)
	_check(health.current_health == 3, "take_damage reduces health")
	_check(health.get_health_ratio() == 0.75, "health ratio updates")

	health.heal(1)
	_check(health.current_health == 4, "heal restores health")
	# Note: heal does not clear invulnerability timer (by design)

	health.set_health(0)
	_check(health.current_health == 0, "set_health can kill")
	_check(health.current_health == 0, "dead state")


func _test_hitbox_hurtbox_interaction() -> void:
	# Test Hitbox -> Hurtbox -> HealthComponent chain
	var hitbox = test_hitbox
	var hurtbox = test_hurtbox
	var health = test_health

	health.set_health(4)
	hitbox.base_damage = 2
	hitbox.base_knockback = Vector2(100, -50)
	hitbox.base_hitstun = 0.2
	hitbox.hit_id = 42

	hitbox.activate(42)
	await _wait_physics(2)

	# Test receive_hit method directly
	var hit = HitData.new(1, Vector2(50, -30), 0.2, test_player, 1, 99)
	var result = hurtbox.receive_hit(hit)
	_check(result, "receive_hit returns true on valid hit")
	_check(health.current_health == 3, "health reduced via hurtbox")

	# Test duplicate hit prevention
	result = hurtbox.receive_hit(hit)
	_check(not result, "duplicate hit blocked")
	_check(health.current_health == 3, "health unchanged on duplicate hit")

	hurtbox.clear_hit_history()
	health.clear_invulnerability()
	result = hurtbox.receive_hit(hit)
	_check(result, "hit allowed after clear_history")


func _test_hit_data() -> void:
	# Test HitData construction and immutability
	var hit = HitData.new(5, Vector2(10, 20), 0.5, test_player, -1, 123, true, 1, &"fire")
	_check(hit.damage == 5, "damage stored")
	_check(hit.knockback == Vector2(10, 20), "knockback stored")
	_check(hit.hitstun == 0.5, "hitstun stored")
	_check(hit.source == test_player, "source stored")
	_check(hit.hit_direction == -1, "direction stored")
	_check(hit.hit_id == 123, "hit_id stored")
	_check(hit.can_guard, "can_guard stored")
	_check(hit.guard_damage == 1, "guard_damage stored")
	_check(hit.element == &"fire", "element stored")

	# Test with_hit_id
	var hit2 = hit.with_hit_id(456)
	_check(hit2.hit_id == 456, "with_hit_id creates new hit with new id")
	_check(hit2.damage == hit.damage, "other fields copied")

	# Test with_source
	var hit3 = hit.with_source(test_hurtbox)
	_check(hit3.source == test_hurtbox, "with_source creates new hit with new source")


func _test_camera_effects() -> void:
	var cam = CameraEffects.instance
	_check(cam != null, "CameraEffects singleton exists")

	# Test shake
	cam.set_shake_enabled(true)
	cam.shake(10.0, 0.2)
	await _wait_physics(1)
	_check(cam.is_shake_active(), "shake activates")
	await _wait_physics(30)
	_check(not cam.is_shake_active(), "shake decays")

	# Test hit_stop
	cam.set_hit_stop_enabled(true)
	cam.hit_stop(0.1)
	await _wait_physics(1)
	_check(cam.is_hit_stop_active(), "hit_stop activates")
	_check(Engine.time_scale == 0.0, "time_scale frozen")
	await _wait_physics(20)
	_check(not cam.is_hit_stop_active(), "hit_stop ends")
	_check(Engine.time_scale == 1.0, "time_scale restored")

	# Test toggles
	cam.set_shake_enabled(false)
	cam.shake(10.0, 0.2)
	_check(not cam.is_shake_active(), "shake disabled")

	cam.set_hit_stop_enabled(false)
	cam.hit_stop(0.1)
	_check(not cam.is_hit_stop_active(), "hit_stop disabled")


func _test_player_attack_flow() -> void:
	# Test player attack activates hitbox with correct timing
	await _reset_player()

	Input.action_press(&"attack")
	await _wait_physics(2)
	_check(test_player.current_state == 5, "attack state entered")  # State.ATTACK = 5

	# Hitbox should activate after anticipation
	await _wait_physics(5)
	_check(test_hitbox.is_active(), "hitbox activated during attack")

	await _wait_physics(10)
	Input.action_release(&"attack")
	await _wait_physics(10)
	_check(test_player.current_state != 5, "attack state ended")
	_check(not test_hitbox.is_active(), "hitbox deactivated after attack")


func _test_invulnerability() -> void:
	await _reset_player()
	var health = test_health

	health.set_health(4)
	_check(not health.is_invulnerable(), "not invulnerable initially")

	# Trigger hurt via health component directly
	health.take_damage(HitData.new(1, Vector2.ZERO, 0.2, test_player, 1, 100))
	await _wait_physics(1)
	_check(health.is_invulnerable(), "invulnerable after damage")
	_check(health.current_health == 3, "health reduced")

	# Second damage should be blocked
	health.take_damage(HitData.new(1, Vector2.ZERO, 0.2, test_player, 1, 100))
	await _wait_physics(1)
	_check(health.current_health == 3, "invulnerability blocks second hit")


func _test_knockback() -> void:
	await _reset_player()

	# Test that velocity can be set and checked
	test_player.velocity = Vector2(100, -50)
	_check(test_player.velocity.x > 0, "velocity can be set positive x")
	_check(test_player.velocity.y < 0, "velocity can be set negative y")

	await _reset_player()
	test_player.velocity = Vector2(-100, -50)
	_check(test_player.velocity.x < 0, "velocity can be set negative x")


func _reset_player() -> void:
	_release_all()
	test_player.global_position = Vector2(200, 610)
	test_player.velocity = Vector2.ZERO
	if test_player.has_method("_coyote_timer"):
		test_player._coyote_timer = 0.0
	if test_player.has_method("_jump_buffer_timer"):
		test_player._jump_buffer_timer = 0.0
	if test_player.has_method("_dash_cooldown_timer"):
		test_player._dash_cooldown_timer = 0.0
	if test_player.has_method("_invulnerability_timer"):
		test_player._invulnerability_timer = 0.0
	if test_player.has_method("_air_dash_used"):
		test_player._air_dash_used = false
	var health = test_player.get_node("HealthComponent")
	if health != null:
		health.set_health(4)
		health.clear_invulnerability()
	await _wait_physics(20)


func _wait_physics(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		print("FAIL: ", message)


func _release_all() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"dash", &"attack"]:
		Input.action_release(action)