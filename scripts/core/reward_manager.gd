extends Node

# RewardManager tracks player inventory and granted items.

var inventory: Dictionary = {}  # item_id => amount

func grant_item(item_id: String, amount: int = 1) -> void:
	if not inventory.has(item_id):
		inventory[item_id] = 0
	inventory[item_id] += amount

func has_item(item_id: String, amount: int = 1) -> bool:
	return inventory.has(item_id) and inventory[item_id] >= amount

func get_item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)

func remove_item(item_id: String, amount: int = 1) -> bool:
	if not has_item(item_id, amount):
		return false
	inventory[item_id] -= amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	return true
