# Add this new class to your main.gd or create a separate SpawnManager.gd
class_name SpawnManager extends Node

# Your existing coordinate arrays
var x_positions = [926, 876, 826, 776, 726, 676, 626, 576, 526, 476, 426, 376, 326, 276, 226]
var y_positions = [124, 174, 224, 274, 324, 374, 424, 474, 524]

# Position tracking
var occupied_positions: Array[Vector2] = []

# Simple spawn function - just 2 lines per item type!
func get_spawn_positions_in_area(count: int, min_row: int, max_row: int, min_col: int, max_col: int) -> Array[Vector2]:
	var available_positions: Array[Vector2] = []
	
	# Get all positions within the specified area
	for row in range(min_row, min(max_row + 1, y_positions.size())):
		for col in range(min_col, min(max_col + 1, x_positions.size())):
			var pos = Vector2(x_positions[col], y_positions[row])
			if not pos in occupied_positions:
				available_positions.append(pos)
	
	# Shuffle and return requested amount
	available_positions.shuffle()
	var spawn_count = min(count, available_positions.size())
	var selected_positions = available_positions.slice(0, spawn_count)
	
	# Mark positions as occupied
	for pos in selected_positions:
		occupied_positions.append(pos)
	
	return selected_positions

# Call this when starting a new level
func clear_occupied_positions():
	occupied_positions.clear()

# Helper to remove position when entity dies
func free_position(position: Vector2):
	var index = occupied_positions.find(position)
	if index != -1:
		occupied_positions.remove_at(index)
		
# Reserve positions (needed by main.gd)
func reserve_positions(positions: Array[Vector2]):
	for pos in positions:
		if not pos in occupied_positions:
			occupied_positions.append(pos)

# Get random available positions (fallback method)
func get_random_available_positions(count: int, avoid_positions: Array[Vector2] = []) -> Array[Vector2]:
	var available_positions: Array[Vector2] = []
	
	for x in x_positions:
		for y in y_positions:
			var pos = Vector2(x, y)
			if not pos in occupied_positions and not pos in avoid_positions:
				available_positions.append(pos)
	
	available_positions.shuffle()
	var selected_count = min(count, available_positions.size())
	return available_positions.slice(0, selected_count)
