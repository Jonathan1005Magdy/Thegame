extends Node

# Automated Phase 2 smoke test. Run this scene directly (F6) or headless.
# It checks movement, jump feel, coyote/buffer, dash rules, hurt, death, and camera.

var player: CharacterBody2D
var sprite: AnimatedSprite2D
var camera: Camera2D
var failures: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var room: Node = load("res://scenes/test_room.tscn").instantiate()
	add_child(room)
	player = room.get_node("Player")
	sprite = player.get_node("AnimatedSprite2D")
	camera = room.get_node("Player/Camera2D")

	await _wait_physics(30)
	_check(player.is_on_floor(), "player spawns and lands")
	_check(player.current_state == 0, "spawn state is idle")
	_check(camera.is_current(), "player camera is current")
	_check(_has_all_animations(), "all state animations exist")

	await _test_run()
	await _test_jumps()
	await _test_coyote()
	await _test_jump_buffer()
	await _test_attack()
	await _test_dash()
	await _test_air_dash()
	await _test_fall_state()
	await _test_hurt()
	await _test_camera_look_ahead()
	await _test_death()

	print("SMOKE RESULT: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_run() -> void:
	await _reset_player()
	Input.action_press(&"move_right")
	await _wait_physics(20)
	_check(player.current_state == 1, "holding right enters run")
	_check(player.velocity.x > 0.0, "run moves right")
	_check(player.facing_direction == 1, "run faces right")
	_check(sprite.flip_h == false, "right-facing sprite is not flipped")
	Input.action_release(&"move_right")
	await _wait_physics(25)
	_check(player.current_state == 0, "releasing input returns to idle")
	_check(absf(player.velocity.x) < 1.0, "ground friction stops the player")


func _test_jumps() -> void:
	await _reset_player()
	var short_peak := await _measure_jump(1)
	await _wait_for_floor()
	await _reset_player()
	var tall_peak := await _measure_jump(24)
	await _wait_for_floor()

	# In this coordinate system, a smaller y is a higher jump.
	_check(tall_peak < short_peak - 15.0, "holding jump gives a taller jump")
	_check(player.get_state_name() != &"death", "jump test leaves player alive")


func _measure_jump(hold_frames: int) -> float:
	var start_y: float = player.global_position.y
	var peak_y: float = start_y
	Input.action_press(&"jump")
	for i in range(55):
		await get_tree().physics_frame
		peak_y = minf(peak_y, player.global_position.y)
		if i == hold_frames:
			Input.action_release(&"jump")
	Input.action_release(&"jump")
	return peak_y


func _test_coyote() -> void:
	await _reset_player()
	player.global_position = Vector2(520, 540)
	player.velocity = Vector2.ZERO
	await _wait_physics(15)
	_check(player.is_on_floor(), "coyote setup lands on platform")

	Input.action_press(&"move_right")
	var left_ground := false
	for i in range(60):
		await get_tree().physics_frame
		if not player.is_on_floor():
			left_ground = true
			break
	Input.action_release(&"move_right")
	Input.action_press(&"jump")
	await _wait_physics(2)
	Input.action_release(&"jump")
	_check(left_ground, "player walks off platform")
	_check(player.current_state == 2, "coyote jump starts in jump state")
	_check(player.velocity.y < 0.0, "coyote jump moves upward")
	await _wait_for_floor()


func _test_jump_buffer() -> void:
	await _reset_player()
	player.global_position = Vector2(250, 588)
	player.velocity = Vector2(0, 260)
	await _wait_physics(2)
	player._coyote_timer = 0.0
	Input.action_press(&"jump")
	await _wait_physics(1)
	Input.action_release(&"jump")
	await _wait_physics(14)
	_check(player.current_state == 2, "buffered jump fires after landing")
	await _wait_for_floor()


func _test_attack() -> void:
	await _reset_player()
	Input.action_press(&"attack")
	await _wait_physics(2)
	_check(player.current_state == 5, "attack enters attack state")
	_check(sprite.animation == &"attack", "attack animation is playing")
	Input.action_release(&"attack")
	await _wait_physics(20)
	_check(player.current_state != 5, "attack state ends by itself")


func _test_dash() -> void:
	await _reset_player()
	Input.action_press(&"move_left")
	await _wait_physics(2)
	Input.action_press(&"dash")
	await _wait_physics(2)
	_check(player.current_state == 4, "dash enters dash state")
	_check(player.velocity.x < 0.0, "dash follows held direction")
	_check(sprite.animation == &"dash", "dash animation is playing")
	Input.action_release(&"move_left")

	# Normal movement input must not break out of the dash.
	Input.action_press(&"move_right")
	await _wait_physics(3)
	_check(player.current_state == 4, "movement cannot overwrite dash")
	_check(player.velocity.x < 0.0, "dash keeps its direction")
	Input.action_release(&"move_right")
	await _wait_physics(12)
	_check(player.current_state != 4, "dash ends after its duration")

	Input.action_press(&"dash")
	await _wait_physics(2)
	_check(player.current_state != 4, "dash cooldown blocks a second dash")
	Input.action_release(&"dash")
	await _wait_physics(30)


func _test_air_dash() -> void:
	await _reset_player()
	player.global_position = Vector2(280, 280)
	player.velocity = Vector2.ZERO
	player._air_dash_used = false
	player._dash_cooldown_timer = 0.0
	await _wait_physics(2)

	Input.action_press(&"dash")
	await _wait_physics(2)
	_check(player.current_state == 4, "air dash enters dash state")
	Input.action_release(&"dash")
	await _wait_physics(12)

	# The cooldown is cleared manually so this specifically checks the one-air-dash rule.
	player._dash_cooldown_timer = 0.0
	Input.action_press(&"dash")
	await _wait_physics(2)
	Input.action_release(&"dash")
	_check(player.current_state != 4, "second air dash is blocked until landing")
	await _wait_for_floor()


func _test_fall_state() -> void:
	await _reset_player()
	player.global_position = Vector2(260, 360)
	player.velocity = Vector2.ZERO
	await _wait_physics(10)
	_check(player.current_state == 3, "airborne descent enters fall state")
	_check(sprite.animation == &"fall", "fall animation is playing")
	await _wait_for_floor()


func _test_hurt() -> void:
	await _wait_for_floor()
	await _reset_player()
	player.take_damage(1, player.global_position - Vector2(50, 0))
	await _wait_physics(1)
	_check(player.current_state == 6, "damage enters hurt state")
	_check(player.current_health == 3, "damage reduces health")
	_check(player.velocity.x > 0.0, "knockback pushes away from source")
	player.take_damage(1, player.global_position - Vector2(50, 0))
	_check(player.current_health == 3, "invulnerability blocks repeated damage")
	await _wait_physics(30)


func _test_camera_look_ahead() -> void:
	await _reset_player()
	Input.action_press(&"move_left")
	await _wait_physics(20)
	Input.action_release(&"move_left")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_check(player.facing_direction == -1, "player faces left after moving left")
	_check(camera.offset.x < -5.0, "camera look-ahead leads to the left")


func _test_death() -> void:
	player.kill()
	await _wait_physics(3)
	_check(player.current_state == 7, "kill enters death state")
	_check(player.current_health == 0, "kill sets health to zero")
	_check(sprite.animation == &"death", "death animation is playing")
	_check(not player.hurtbox.monitorable, "death disables the hurtbox")
	_check(GameState.player_health == 0, "death updates GameState health")
	Input.action_press(&"move_right")
	await _wait_physics(10)
	Input.action_release(&"move_right")
	_check(player.current_state == 7, "death ignores movement input")


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


func _wait_for_floor() -> void:
	_release_all()
	for i in range(120):
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	await _wait_physics(2)


func _wait_physics(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame


func _has_all_animations() -> bool:
	var required := [&"idle", &"run", &"jump", &"fall", &"dash", &"attack", &"hurt", &"death"]
	for animation_name in required:
		if not sprite.sprite_frames.has_animation(animation_name):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		print("FAIL: ", message)


func _release_all() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"dash", &"attack"]:
		Input.action_release(action)
