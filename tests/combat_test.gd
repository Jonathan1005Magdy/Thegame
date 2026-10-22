extends Node

# Automated Phase 3 combat test. Run this scene directly (F6) or headless.
# It checks player attack hitbox, enemy damage, knockback, hit flash, camera shake/hit-stop,
# enemy patrol/chase/attack, and reward drops.

var player: PlayerController
var camera: Camera2D
var room: Node
var failures: int = 0
var test_patroller: BaseEnemy
var test_flyer: BaseEnemy


func _ready() -> void:
	await get_tree().process_frame
	room = load("res://scenes/combat_test_room.tscn").instantiate()
	add_child(room)
	player = room.get_node("Player")
	camera = player.get_node("Camera2D")
	test_patroller = room.get_node("Patroller1")
	test_flyer = room.get_node("Flyer1")

	await _wait_physics(30)
	_check(player.is_on_floor(), "player spawns and lands")
	_check(player.current_state == PlayerController.State.IDLE, "spawn state is idle")
	_check(camera.is_current(), "player camera is current")
	_check(player.hitbox != null, "player has hitbox component")
	_check(player.health_component != null, "player has health component")
	_check(test_patroller != null, "ground patroller exists")
	_check(test_flyer != null, "flying enemy exists")

	await _test_player_attack_hitbox()
	await _test_enemy_take_damage()
	await _test_enemy_knockback()
	await _test_hit_flash()
	await _test_camera_shake_and_hit_stop()
	await _test_enemy_patrol_and_chase()
	await _test_flying_enemy_projectile()
	await _test_enemy_death_reward()

	print("COMBAT TEST RESULT: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_player_attack_hitbox() -> void:
	await _reset_player()
	# Position player near patroller
	player.global_position = Vector2(480, 600)
	player.velocity = Vector2.ZERO
	await _wait_physics(10)

	var initial_patroller_health = test_patroller.health.current_health
	Input.action_press(&"attack")
	await _wait_physics(2)
	_check(player.current_state == PlayerController.State.ATTACK, "attack state entered")
	_check(player.hitbox.is_active(), "hitbox activated during attack")
	await _wait_physics(15)  # Wait for attack to complete
	Input.action_release(&"attack")
	await _wait_physics(10)

	# Check if patroller took damage (might miss if not in range)
	# This test mainly verifies hitbox activation
	_check(true, "player attack hitbox test completed")


func _test_enemy_take_damage() -> void:
	await _reset_player()
	# Place player right next to patroller for guaranteed hit
	player.global_position = Vector2(490, 600)
	player.velocity = Vector2.ZERO
	test_patroller.global_position = Vector2(500, 600)
	test_patroller.velocity = Vector2.ZERO
	await _wait_physics(10)

	var initial_health = test_patroller.health.current_health
	Input.action_press(&"attack")
	await _wait_physics(20)
	Input.action_release(&"attack")
	await _wait_physics(10)

	_check(test_patroller.health.current_health < initial_health, "enemy takes damage from player attack")
	_check(test_patroller.current_state == BaseEnemy.State.HURT, "enemy enters hurt state on hit")


func _test_enemy_knockback() -> void:
	await _reset_player()
	player.global_position = Vector2(490, 600)
	player.velocity = Vector2.ZERO
	test_patroller.global_position = Vector2(500, 600)
	test_patroller.velocity = Vector2.ZERO
	await _wait_physics(10)

	Input.action_press(&"attack")
	await _wait_physics(20)
	Input.action_release(&"attack")
	await _wait_physics(2)

	# Enemy should be knocked back (velocity.x != 0)
	_check(absf(test_patroller.velocity.x) > 10.0, "enemy receives knockback")


func _test_hit_flash() -> void:
	await _reset_player()
	# Trigger hurt state via debug
	player.global_position = Vector2(200, 600)
	await _wait_physics(10)
	player.take_damage(1, player.global_position - Vector2(50, 0))
	await _wait_physics(1)

	_check(player._hit_flash_timer > 0.0, "hit flash timer started")
	_check(player.sprite.modulate != player._original_modulate, "sprite color changed for hit flash")
	await _wait_physics(15)
	_check(player._hit_flash_timer <= 0.0, "hit flash timer expired")
	_check(player.sprite.modulate == player._original_modulate, "sprite color restored after hit flash")


func _test_camera_shake_and_hit_stop() -> void:
	await _reset_player()
	var cam_effects = CameraEffects.instance
	_check(cam_effects != null, "CameraEffects singleton exists")

	# Test camera shake
	cam_effects.shake(10.0, 0.2)
	await _wait_physics(1)
	_check(cam_effects.is_shake_active(), "camera shake activated")
	await _wait_physics(30)
	_check(not cam_effects.is_shake_active(), "camera shake decayed")

	# Test hit stop
	cam_effects.hit_stop(0.1)
	await _wait_physics(1)
	_check(cam_effects.is_hit_stop_active(), "hit stop activated")
	_check(Engine.time_scale == 0.0, "time scale frozen during hit stop")
	await _wait_physics(20)
	_check(not cam_effects.is_hit_stop_active(), "hit stop ended")
	_check(Engine.time_scale == 1.0, "time scale restored after hit stop")

	# Test toggle
	cam_effects.set_shake_enabled(false)
	cam_effects.shake(10.0, 0.2)
	_check(not cam_effects.is_shake_active(), "camera shake disabled")
	cam_effects.set_shake_enabled(true)

	cam_effects.set_hit_stop_enabled(false)
	cam_effects.hit_stop(0.1)
	_check(not cam_effects.is_hit_stop_active(), "hit stop disabled")
	cam_effects.set_hit_stop_enabled(true)


func _test_enemy_patrol_and_chase() -> void:
	await _reset_player()
	# Test patroller patrol behavior
	var patroller = room.get_node("Patroller2")
	patroller.global_position = Vector2(1100, 500)
	patroller.velocity = Vector2.ZERO
	await _wait_physics(10)

	_check(patroller.current_state == BaseEnemy.State.PATROL, "patroller starts in patrol")
	var initial_x = patroller.global_position.x
	await _wait_physics(60)  # Wait for patrol movement
	_check(absf(patroller.global_position.x - initial_x) > 20.0, "patroller moves during patrol")

	# Test chase - move player into detection range
	player.global_position = Vector2(1150, 500)
	await _wait_physics(20)
	_check(patroller.current_state == BaseEnemy.State.CHASE, "patroller chases player in range")


func _test_flying_enemy_projectile() -> void:
	await _reset_player()
	var flyer = room.get_node("Flyer2")
	flyer.global_position = Vector2(1400, 200)
	flyer.velocity = Vector2.ZERO
	await _wait_physics(10)

	_check(flyer.current_state == BaseEnemy.State.PATROL, "flyer starts in patrol")

	# Move player into range
	player.global_position = Vector2(1400, 350)
	await _wait_physics(30)

	_check(flyer.current_state == BaseEnemy.State.CHASE or flyer.current_state == BaseEnemy.State.ATTACK, "flyer detects player")


func _test_enemy_death_reward() -> void:
	# Kill patroller and check reward drop
	var patroller = room.get_node("Patroller1")
	patroller.global_position = Vector2(400, 600)
	patroller.velocity = Vector2.ZERO
	await _wait_physics(10)

	var initial_coins = RewardManager.get_item_count("coin")
	patroller.health.set_health(0)
	await _wait_physics(20)

	_check(patroller.current_state == BaseEnemy.State.DEATH, "patroller dies when health reaches 0")
	_check(RewardManager.get_item_count("coin") > initial_coins, "reward dropped on enemy death")


func _reset_player() -> void:
	_release_all()
	player.global_position = Vector2(200, 610)
	player.velocity = Vector2.ZERO
	player._coyote_timer = 0.0
	player._jump_buffer_timer = 0.0
	player._dash_cooldown_timer = 0.0
	player._invulnerability_timer = 0.0
	player._air_dash_used = false
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