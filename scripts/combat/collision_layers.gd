# Combat layer definitions — single source of truth.
# Add these exact names to Project Settings → Layer Names → 2D Physics.
# Layers 1–20 are available. Keep this file in sync with the editor.

# Layer 1: World geometry (floors, walls, platforms)
# Layer 2: Player body
# Layer 3: Enemy body
# Layer 4: Player hitbox (attack)
# Layer 5: Enemy hitbox (attack)
# Layer 6: Player hurtbox (receives damage)
# Layer 7: Enemy hurtbox (receives damage)
# Layer 8: Pickups / interactables
# Layer 9: Projectiles (if separate from hitboxes)
# Layer 10: One-way platforms

# Mask conventions:
# - Player body (layer 2) collides with: 1 (world), 3 (enemy body)
# - Enemy body (layer 3) collides with: 1 (world), 2 (player body)
# - Player hitbox (layer 4) hits: 7 (enemy hurtbox)
# - Enemy hitbox (layer 5) hits: 6 (player hurtbox)
# - Player hurtbox (layer 6) monitors: 5 (enemy hitbox)
# - Enemy hurtbox (layer 7) monitors: 4 (player hitbox)
# - Projectiles (layer 9) hit: 6 (player hurtbox), 7 (enemy hurtbox)