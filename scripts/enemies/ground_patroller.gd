extends BaseEnemy

# Ground enemy that patrols, chases, and does a simple melee swipe.

@export_group("Attack Override")
@export var swipe_range: float = 48.0
@export var swipe_damage: int = 1
@export var swipe_knockback: Vector2 = Vector2(200.0, -100.0)
@export var swipe_hitstun: float = 0.3
@export var anticipation_time: float = 0.25
@export var active_frames: float = 0.15


func _ready() -> void:
	super._ready()
	max_health = 3
	move_speed = 50.0
	chase_speed = 80.0
	detection_range = 180.0
	attack_range = swipe_range
	attack_cooldown = 1.8
	recovery_time = 0.5
	hurt_time = 0.35
	patrol_distance = 100.0
	patrol_pause_time = 1.2
	contact_damage = 1
	reward_item_id = "coin"
	reward_amount = 1


func _start_attack() -> void:
	# Called when entering ATTACK state, after anticipation_time
	# We use a timer to delay hitbox activation
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = anticipation_time
	timer.timeout.connect(_activate_swipe.bind())
	add_child(timer)
	timer.start()


func _activate_swipe() -> void:
	if current_state != State.ATTACK:
		return
	if hitbox != null:
		hitbox.base_damage = swipe_damage
		hitbox.base_knockback = swipe_knockback
		hitbox.base_hitstun = swipe_hitstun
		hitbox.activate()

	# Deactivate after active_frames
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = active_frames
	timer.timeout.connect(_deactivate_swipe.bind())
	add_child(timer)
	timer.start()


func _deactivate_swipe() -> void:
	if hitbox != null:
		hitbox.deactivate()