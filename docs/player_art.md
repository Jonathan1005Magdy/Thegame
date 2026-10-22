# Player art integration

This document records how the supplied character frames were turned into the
player's in-game animation set. It contains no story text.

## Files

| Purpose | Path |
| --- | --- |
| Normalized sprite atlas | `res://assets/player/hero/player_hero_sheet.png` |
| Animation definitions | `res://resources/player/player_sprite_frames.tres` |
| Player scene | `res://scenes/player.tscn` |
| Player logic | `res://scripts/player/player_controller.gd` |

The original frame files are not copied into the project. The atlas contains
only the cleaned, aligned frames used at runtime.

## Atlas layout and pivot

- Each frame cell is **360 x 240** pixels.
- Atlas grid: **10 columns x 5 rows** (44 unique frames).
- Character pivot inside every cell: **x = 180**, **feet y = 220**.
- The source art was reduced to **40%** before being placed in a cell.
- `AnimatedSprite2D` uses `position = (0, -37.5)` and `scale = (0.375, 0.375)`.
  This makes the character about **53 px tall** at the default 640 x 360 viewport.

The player scene origin stays at the character's feet, so the feet meet the
floor at y = 0 and the collider does not move.

## Animation clips

| Clip | Source frames | FPS | Loops | Used by |
| --- | --- | --- | --- | --- |
| `idle` | `idle_0` to `idle_3` | 6 | yes | `IDLE` state |
| `run` | `run2_0` to `run2_5` | 12 | yes | `RUN` state |
| `jump` | `jump_0` to `jump_3` | 10 | no | `JUMP` state |
| `fall` | `fall_0` to `fall_2` | 8 | yes | `FALL` state |
| `attack` | `attack_1` to `attack_5` | 20 | no | `ATTACK` state |
| `dash` | `run1_1` to `run1_3` | 20 | yes | `DASH` state, temporary |
| `hurt` | `fall_0` | 8 | no | `HURT` state, temporary |
| `death` | `crouch_1` to `crouch_3` | 5 | no | `DEATH` state, temporary |
| `walk` | `walk_1` to `walk_5` | 10 | yes | Not bound yet |
| `crouch` | `crouch_1` to `crouch_3` | 8 | yes | Not bound yet |
| `defend` | `defend_0`, `defend_2`, `defend_3` | 8 | yes | Not bound yet |
| `defend_attack` | `defend_attack_2` to `defend_attack_9` | 18 | no | Not bound yet |
| `run_spear` | `run1_1` to `run1_3` | 12 | yes | Not bound yet |

### Temporary mappings

The supplied set did not include dedicated dash, hurt, or death drawings:

- `dash` reuses the spear-forward running frames.
- `hurt` reuses the recoiling fall pose.
- `death` reuses the crouch sequence as a collapse placeholder.

These clips can be replaced independently later without changing any player
logic or scene wiring.

## Frames that were deliberately excluded

These source images contain captions or show multiple poses in one image, so
they were not placed in the runtime atlas:

- `attack_0`
- `run1_0`
- `walk_0`
- `crouch_0`
- `defend_1`
- `defend_attack_0`
- `defend_attack_1`

The clean frames from those animations were used instead.

## Replacing the art

### Replace a single animation

Keep the atlas layout and pivot, then paint the replacement frame into the same
360 x 240 cell with the feet at `y = 220`. No scene or resource changes are
needed as long as the clip name and cell position stay the same.

### Use a new full frame set

For each frame:

1. Remove any caption or checkerboard that is part of the image.
2. Trim the transparent background.
3. Scale the character to the same relative size as the current frames.
4. Place the character with a shared vertical body axis at `x = 180` and the
   lowest foot at `y = 220`.
5. Rebuild the atlas and update the `AtlasTexture` regions in
   `player_sprite_frames.tres`.

If the atlas cells change size, also update the `AnimatedSprite2D` position and
scale in `scenes/player.tscn` so the feet remain at the player origin.

## Adding crouch or defend gameplay

The `crouch`, `defend`, and `defend_attack` clips are already imported, but the
current Phase 2 state machine only owns idle, run, jump, fall, dash, attack,
hurt, and death. Adding crouch/defend states is a gameplay decision for a later
phase, not part of the art swap.
