# Phase 3 Combat System

This document describes the combat system implementation for the Metroidvania project.

## Files Created/Modified

| File | Purpose |
|------|---------|
| `res://scripts/combat/collision_layers.gd` | Layer/mask definitions (reference only) |
| `res://scripts/combat/hit_data.gd` | Immutable hit data packet (`HitData` class) |
| `res://scripts/combat/health_component.gd` | Reusable health component with invulnerability |
| `res://scripts/combat/hitbox.gd` | Attack hitbox with frame-window activation |
| `res://scripts/combat/hurtbox.gd` | Hurtbox that forwards hits to HealthComponent |
| `res://scripts/core/camera_effects.gd` | Camera shake & hit-stop manager (autoload) |
| `res://scripts/enemies/base_enemy.gd` | Base enemy AI: patrol, chase, attack, recovery, death |
| `res://scripts/enemies/ground_patroller.gd` | Melee enemy extending BaseEnemy |
| `res://scripts/enemies/flying_enemy.gd` | Ranged/flying enemy extending BaseEnemy |
| `res://scripts/enemies/enemy_projectile.gd` | Projectile for flying enemy |
| `res://scenes/enemies/ground_patroller.tscn` | Ground patroller scene |
| `res://scenes/enemies/flying_enemy.tscn` | Flying enemy scene |
| `res://scenes/enemies/enemy_projectile.tscn` | Projectile scene |
| `res://scenes/combat_test_room.tscn` | Test room with enemies |
| `res://scripts/player/player_controller.gd` | Updated with hitbox, hit flash, knockback |
| `res://scripts/player/player_camera.gd` | Updated with camera shake integration |
| `res://scenes/player.tscn` | Added Hitbox, HealthComponent, updated Hurtbox |
| `res://project.godot` | Added CameraEffects autoload |
| `res://tests/combat_component_test.gd` | Automated combat component tests |
| `res://tests/combat_component_test.tscn` | Test scene |

## Collision Layers & Masks

Add these exact names to **Project Settings → Layer Names → 2D Physics**:

| Layer | Name | Used By |
|-------|------|---------|
| 1 | `world` | Floors, walls, platforms |
| 2 | `player_body` | Player CharacterBody2D |
| 3 | `enemy_body` | Enemy CharacterBody2D |
| 4 | `player_hitbox` | Player attack hitbox |
| 5 | `enemy_hitbox` | Enemy attack hitbox |
| 6 | `player_hurtbox` | Player hurtbox (receives damage) |
| 7 | `enemy_hurtbox` | Enemy hurtbox (receives damage) |
| 8 | `pickups` | Items, interactables |
| 9 | `projectiles` | Enemy projectiles |
| 10 | `one_way` | One-way platforms |

**Mask Conventions:**
- Player body (layer 2): collides with world (1), enemy_body (3)
- Enemy body (layer 3): collides with world (1), player_body (2)
- Player hitbox (layer 4): hits enemy_hurtbox (7)
- Enemy hitbox (layer 5): hits player_hurtbox (6)
- Player hurtbox (layer 6): monitors enemy_hitbox (5)
- Enemy hurtbox (layer 7): monitors player_hitbox (4)
- Projectiles (layer 9): hit player_hurtbox (6), enemy_hurtbox (7)

## Component Architecture

### HitData (res://scripts/combat/hit_data.gd)
Immutable data packet sent from Hitbox → Hurtbox → HealthComponent.

```gdscript
HitData.new(
    damage: int = 1,
    knockback: Vector2 = Vector2.ZERO,
    hitstun: float = 0.2,
    source: Node = null,
    hit_direction: int = 1,   # 1 = right, -1 = left
    hit_id: int = 0,          # Unique ID prevents multi-hit
    can_guard: bool = false,
    guard_damage: int = 0,
    element: StringName = &"physical"
)
```

**Key feature:** `hit_id` prevents multi-hit from same attack. Both Hitbox and Hurtbox track recent hit IDs.

### HealthComponent (res://scripts/combat/health_component.gd)
Attach to any damageable entity. Handles health, invulnerability, and signals.

**Exported:**
- `max_health: int`
- `invulnerability_time: float`

**Signals:**
- `health_changed(current, max)`
- `died`
- `damaged(damage, hit_data)`
- `healed(amount)`

**Methods:**
- `take_damage(hit: HitData) -> bool` — returns false if blocked (invulnerable, dead, duplicate hit)
- `heal(amount: int)`
- `set_health(new_health: int)` — clears invulnerability when health > 0
- `clear_invulnerability()` — for testing/respawning
- `is_invulnerable() -> bool`
- `get_health_ratio() -> float`

### Hitbox (res://scripts/combat/hitbox.gd)
Area2D activated for a frame window. Emits `hit_connected(hurtbox, hit_data)`.

**Exported:**
- `base_damage`, `base_knockback`, `base_hitstun`
- `hit_id` (set by attacker)
- `can_guard`, `guard_damage`, `element`

**Methods:**
- `setup(owner: Node)` — sets reference for knockback direction
- `activate(hit_id_override: int = 0)`
- `deactivate()`
- `is_active() -> bool`

### Hurtbox (res://scripts/combat/hurtbox.gd)
Area2D that receives hits and forwards to HealthComponent. Add to "hurtbox" group.

**Exported:**
- `health_component_path: NodePath`
- `knockback_multiplier: float`

**Methods:**
- `receive_hit(hit: HitData) -> bool` — returns true if damage applied
- `clear_hit_history()`

### CameraEffects (res://scripts/core/camera_effects.gd) — Autoload
Global camera shake and hit-stop manager.

**Signals:** `shake_started(intensity, duration)`, `hit_stop_started(duration)`

**Methods:**
- `shake(intensity, duration=0.15, decay=-1)`
- `hit_stop(duration=0.05)`
- `set_shake_enabled(bool)`, `set_hit_stop_enabled(bool)`
- `get_shake_offset() -> Vector2` — apply to Camera2D offset

**Integration:** PlayerCamera adds `CameraEffects.instance.get_shake_offset()` to its offset in `_process`.

## Player Integration

The player scene (`res://scenes/player.tscn`) now includes:
- **HealthComponent** child node
- **Hitbox** child of player (positioned at attack origin)
- **Hurtbox** child node (replaces old Area2D)

**PlayerController exports:**
```gdscript
@export_group("Attack Hitbox")
@export var attack_damage: int = 1
@export var attack_knockback: Vector2 = Vector2(200, -100)
@export var attack_hitstun: float = 0.3
@export var attack_anticipation: float = 0.08
@export var attack_active_frames: float = 0.12

@export_group("Hit Feedback")
@export var hit_flash_duration: float = 0.1
@export var hit_flash_color: Color = Color(1, 1, 1, 1)
@export var enable_camera_shake: bool = true
@export var enable_hit_stop: bool = true
@export var hit_shake_intensity: float = 6.0
@export var hit_shake_duration: float = 0.1
@export var hit_stop_duration: float = 0.05
```

**Attack flow:**
1. Press attack → `_start_attack()` generates new `_current_hit_id = randi()`
2. After `attack_anticipation` seconds → hitbox activates with `_current_hit_id`
3. After `attack_active_frames` → hitbox deactivates
4. On hit → `_on_hit_connected` emits `attack_started`
4. On damage taken → `take_damage()` creates HitData, calls health component
5. HealthComponent emits `damaged` → `_on_damaged` applies hit flash, camera shake, hit-stop, knockback, enters HURT state

## Enemy System

### BaseEnemy (res://scripts/enemies/base_enemy.gd)
State machine: IDLE → PATROL → CHASE → ATTACK → RECOVERY → HURT → DEATH

**Key features:**
- Patrol with edge/wall detection (RayCast2D)
- Player detection by distance
- Attack with cooldown
- Recovery after attack
- Hurt with knockback resistance
- Death with reward drop (via RewardManager)
- Configurable stats, patrol, rewards, visuals

**Exported groups:**
- Stats: health, damage, speeds, ranges, cooldowns, knockback resistance
- Patrol: distance, pause time, edge/wall turning
- Rewards: item ID, amount, drop chance
- Visuals: node paths for sprite, hitbox, hurtbox, health

### GroundPatroller (res://scripts/enemies/ground_patroller.gd)
Melee swipe attack with anticipation/active frames.

### FlyingEnemy (res://scripts/enemies/flying_enemy.gd)
Floating patrol (gravity_scale = 0), shoots projectiles.

### EnemyProjectile (res://scripts/enemies/enemy_projectile.gd)
Area2D projectile with lifetime, pierce option, launches toward player.

## Signals Connecting Everything

```
Player Attack:
  PlayerController.attack_started → (UI, combo system)
  Hitbox.hit_connected(hurtbox, hit_data) → Hurtbox.receive_hit()
  Hurtbox.receive_hit() → HealthComponent.take_damage()
  HealthComponent.damaged(damage, hit) → PlayerController._on_damaged()
  PlayerController._on_damaged() → hit flash, camera shake, hit-stop, knockback, state=HURT
  HealthComponent.died → PlayerController._on_death() → state=DEATH

Enemy Attack:
  Enemy hitbox → Player hurtbox → Player HealthComponent.take_damage()
  Player HealthComponent.damaged → PlayerController._on_damaged() → knockback, HURT
  Enemy hitbox.hit_connected → Enemy._on_hit_connected() → state=RECOVERY

Enemy Death:
  Enemy HealthComponent.died → Enemy._on_death() → _drop_reward() → RewardManager.grant_item()
  Enemy.died → (quest system, door unlocks, etc.)

Camera:
  CameraEffects.shake() / hit_stop() → PlayerCamera._process() adds shake offset
  CameraEffects.set_shake_enabled(bool) / set_hit_stop_enabled(bool) for options menu
```

## Double-Hit Prevention

Two-layer protection:
1. **Hitbox level:** Each attack generates unique `hit_id = randi()`. Hitbox passes this to HitData.
2. **Hurtbox level:** Tracks recent hit_ids in array (max 8). Ignores duplicates.
3. **HealthComponent level:** Tracks `_last_hit_id`. Blocks if same non-zero hit_id received while invulnerable.

This ensures:
- Single attack with multiple frames only hits once
- Rapid attacks with different hit_ids each hit once
- Invulnerability frames block all damage regardless of hit_id

## Editor Setup Checklist

1. **Project Settings → Layer Names → 2D Physics:** Add the 10 layers listed above
2. **Autoloads:** Verify CameraEffects is in autoload list (added to project.godot)
3. **Player scene:** Open `res://scenes/player.tscn`, verify Hitbox, HealthComponent, Hurtbox children exist
3. **Enemy scenes:** Open ground_patroller.tscn and flying_enemy.tscn, verify all components
4. **Test room:** Open combat_test_room.tscn, verify Patroller1, Patroller2, Flyer1, Flyer2 instances
5. **Run tests:** 
   - Player: `res://tests/player_smoke_test.tscn` (F6)
   - Combat components: `res://tests/combat_component_test.tscn` (F6)

## Test Checklist

### Player Smoke Test (`res://tests/player_smoke_test.tscn`)
- [ ] Player spawns and lands on floor
- [ ] Spawn state is IDLE
- [ ] Camera follows player
- [ ] All animations exist (idle, run, jump, fall, dash, attack, hurt, death)
- [ ] Run: input moves player, faces correct direction, friction stops
- [ ] Jump: variable height (tap vs hold), coyote time, jump buffer
- [ ] Dash: ground/air, direction follows input, cooldown, cannot be interrupted
- [ ] Attack: enters state, plays animation, hitbox activates
- [ ] Hurt: takes damage, knockback, invulnerability blocks repeat
- [ ] Death: enters state, disables hurtbox, updates GameState
- [ ] Camera look-ahead works

### Combat Component Test (`res://tests/combat_component_test.tscn`)
- [ ] HealthComponent: max/current health, take_damage, heal, set_health, invulnerability
- [ ] Hitbox/Hurtbox: activation, receive_hit, duplicate prevention, clear_history
- [ ] HitData: construction, immutability, with_hit_id, with_source
- [ ] CameraEffects: shake, hit_stop, toggles, decay
- [ ] Player attack: state entry, hitbox timing, deactivation
- [ ] Invulnerability: frames after damage, blocks repeat
- [ ] Knockback: direction based on hit source

### In-Editor Manual Verification
1. Open `res://scenes/main.tscn` and run (F5)
2. Move with A/D, jump Space, dash Shift, attack J
3. Verify hit flash on damage, camera shake on hit, hit-stop on impact
4. Walk to enemies (Patroller1 at x=500, Flyer1 at x=800)
5. Attack enemies - they should take damage, flash, knock back, die and drop coins
6. Take damage from enemies - player should flash, shake, knock back, gain invulnerability
6. Open `res://scenes/combat_test_room.tscn` and run directly for enemy-only testing

## Known Limitations (Headless Mode)

- Enemy inheritance (`extends BaseEnemy`) works in editor but fails in headless due to Godot 4.x global class registration timing. Works correctly when running in editor (F5/F6).
- CameraEffects shake decay and hit-stop timing may vary slightly in headless vs editor.
- Enemy AI tests require editor run; headless only validates component logic.

## Tuning Guidance

| Feel | Parameters |
|------|------------|
| Attack speed | `attack_anticipation`, `attack_active_frames`, `attack_duration` |
| Hit impact | `hit_flash_duration`, `hit_flash_color`, `hit_shake_intensity`, `hit_stop_duration` |
| Knockback | `hurt_knockback` (player), `swipe_knockback` / `contact_damage` (enemies) |
| Invulnerability | `invulnerability_time` (health component), `hurt_duration` (player state) |
| Enemy aggression | `detection_range`, `attack_range`, `attack_cooldown`, `chase_speed` |
| Camera feel | `look_ahead_distance`, `look_ahead_smoothing`, `position_smoothing_speed` |

## Art Swap Notes

- Player hitbox size: `RectangleShape2D` (48×28) at `Hitbox` position (38, -26)
- Enemy hurtbox/hitbox sizes defined in their .tscn files
- All collision shapes are capsules (bodies) or rectangles (hurtboxes/hitboxes)
- Pivot at feet (y=0), hitboxes positioned relative to sprite origin

No story content was added or modified. All systems load data; no hardcoded narrative.