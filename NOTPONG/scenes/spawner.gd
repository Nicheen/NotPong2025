# Add this new class to your main.gd or create a separate SpawnManager.gd
class_name SpawnManager extends Node

# 2D Gradient spawn system
@export var spawn_gradient_texture: GradientTexture2D
@export var use_gradient_spawning: bool = true

# Grid dimensions (15 columns x 9 rows based on your coordinates)
const GRID_WIDTH = 15
const GRID_HEIGHT = 9

# Your existing coordinate arrays
var x_positions = [926, 876, 826, 776, 726, 676, 626, 576, 526, 476, 426, 376, 326, 276, 226]
var y_positions = [124, 174, 224, 274, 324, 374, 424, 474, 524]

# Position tracking
var occupied_positions: Array[Vector2] = []
var position_to_grid_index: Dictionary = {}

# Spawn weights for different entity types
var spawn_weights: Dictionary = {
	"blocks": create_default_gradient(),
	"enemies": create_enemy_gradient(), 
	"blue_blocks": create_blue_block_gradient(),
	"laser_blocks": create_laser_gradient(),
	"block_droppers": create_dropper_gradient(),
	"iron_blocks": create_iron_block_gradient(),
	"cloud_blocks": create_cloud_block_gradient()
}

func _ready():
	setup_position_mapping()
	if spawn_gradient_texture == null:
		create_default_gradient()

func setup_position_mapping():
	"""Map each world position to its grid index for easy lookup"""
	position_to_grid_index.clear()
	
	for x_idx in range(x_positions.size()):
		for y_idx in range(y_positions.size()):
			var world_pos = Vector2(x_positions[x_idx], y_positions[y_idx])
			var grid_idx = Vector2(x_idx, y_idx)
			position_to_grid_index[world_pos] = grid_idx

func create_default_gradient() -> Array[float]:
	"""Create a default gradient that favors center-top positions"""
	var weights: Array[float] = []
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			# Higher weight for center columns and upper rows
			var center_distance = abs(x - GRID_WIDTH/2) / float(GRID_WIDTH/2)
			var height_factor = (GRID_HEIGHT - y) / float(GRID_HEIGHT)
			
			var weight = (1.0 - center_distance * 0.7) * height_factor
			weights.append(max(0.1, weight))  # Minimum weight of 0.1
	
	return weights

func create_iron_block_gradient() -> Array[float]:
	"""Create gradient for iron blocks - prefer center positions and avoid edges"""
	var weights: Array[float] = []
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			# Strong preference for center positions
			var center_distance = abs(x - GRID_WIDTH/2) / float(GRID_WIDTH/2)
			var edge_penalty = 1.0
			
			# Avoid edges completely
			if x == 0 or x == GRID_WIDTH-1 or y == 0 or y == GRID_HEIGHT-1:
				edge_penalty = 0.1
			
			# Prefer middle rows (not too high, not too low)
			var height_factor = 1.0 - abs(y - GRID_HEIGHT/2) / float(GRID_HEIGHT/2)
			
			var weight = (1.0 - center_distance * 0.5) * height_factor * edge_penalty
			weights.append(max(0.05, weight))  # Very low minimum weight
	
	return weights
	
func create_cloud_block_gradient() -> Array[float]:
	"""Cloud blocks prefer strategic middle positions"""
	var weights: Array[float] = []
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			# Prefer center-middle positions (like blue blocks but more centered)
			var center_distance = abs(x - GRID_WIDTH/2) / float(GRID_WIDTH/2)
			var center_factor = 1.0 - center_distance * 0.8  # Strong center preference
			
			# Prefer middle rows (rows 3-5) - higher than blue blocks
			var middle_factor = 1.0
			if y >= 2 and y <= 5:
				middle_factor = 1.8  # High preference for middle area
			elif y <= 1 or y >= 7:
				middle_factor = 0.2  # Avoid edges
			
			weights.append(center_factor * middle_factor)
	
	return weights
	
func create_enemy_gradient() -> Array[float]:
	"""Enemies prefer to spawn in upper areas, spread out"""
	var weights: Array[float] = []
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			# Strong preference for upper 3 rows
			var height_factor = 1.0
			if y <= 2:
				height_factor = 2.0  # Double weight for top rows
			elif y >= 6:
				height_factor = 0.3  # Low weight for bottom rows
			
			# Slight preference for sides (enemies flanking)
			var side_factor = 1.0
			if x <= 2 or x >= 12:
				side_factor = 1.3
			
			weights.append(height_factor * side_factor)
	
	return weights

func create_blue_block_gradient() -> Array[float]:
	"""Blue blocks prefer center-middle positions (strategic placement)"""
	var weights: Array[float] = []
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			# Prefer center columns
			var center_distance = abs(x - GRID_WIDTH/2) / float(GRID_WIDTH/2)
			var center_factor = 1.0 - center_distance * 0.6
			
			# Prefer middle rows (rows 3-6)
			var middle_factor = 1.0
			if y >= 3 and y <= 6:
				middle_factor = 1.5
			elif y <= 1 or y >= 8:
				middle_factor = 0.4
			
			weights.append(center_factor * middle_factor)
	
	return weights

func create_laser_gradient() -> Array[float]:
	"""Laser blocks prefer strategic positions - corners and key lanes"""
	var weights: Array[float] = []
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var weight = 0.5  # Base weight
			
			# Higher weight for corners
			if (x <= 1 or x >= 13) and (y <= 1 or y >= 7):
				weight = 2.0
			# Higher weight for center column (vertical laser lane)
			elif x == 7:  # Center column
				weight = 1.5
			# Higher weight for center row (horizontal laser lane)
			elif y == 4:  # Center row
				weight = 1.5
			
			weights.append(weight)
	
	return weights

func create_dropper_gradient() -> Array[float]:
	"""Block droppers prefer upper positions to drop down"""
	var weights: Array[float] = []
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			# Strong preference for top 4 rows
			var height_factor = max(0.2, (GRID_HEIGHT - y) / float(GRID_HEIGHT))
			
			# Slight preference for outer columns (avoid center congestion)
			var spread_factor = 1.0
			if x >= 3 and x <= 11:
				spread_factor = 0.8
			
			weights.append(height_factor * spread_factor * 1.5)
	
	return weights
func create_thunder_gradient() -> Array[float]:
	"""Thunder blocks prefer strategic positions - corners and middle areas"""
	var weights: Array[float] = []
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var weight = 0.1  # Base weight
			
			# Higher weight for corners
			if (x == 0 or x == GRID_WIDTH-1) and (y == 0 or y == GRID_HEIGHT-1):
				weight = 0.9
			# Medium weight for edges
			elif x == 0 or x == GRID_WIDTH-1 or y == 0 or y == GRID_HEIGHT-1:
				weight = 0.6
			# Medium weight for center area
			elif abs(x - GRID_WIDTH/2) <= 2 and abs(y - GRID_HEIGHT/2) <= 1:
				weight = 0.7
			# Lower weight for middle areas (not too clustered)
			else:
				weight = 0.3
			
			weights.append(weight)
	
	return weights

# Update your spawn_weights dictionary in SpawnManager._ready() to include:
# "thunder_blocks": create_thunder_gradient(),

		
func get_weighted_spawn_positions(entity_type: String, count: int, avoid_positions: Array[Vector2] = []) -> Array[Vector2]:
	"""Get spawn positions using weighted probability based on entity type"""
	
	if not spawn_weights.has(entity_type):
		print("Warning: No spawn weights defined for entity type: ", entity_type)
		return get_random_available_positions(count, avoid_positions)
	
	var weights = spawn_weights[entity_type]
	var available_positions: Array[Vector2] = []
	var available_weights: Array[float] = []
	
	# Collect available positions and their weights
	for x_idx in range(x_positions.size()):
		for y_idx in range(y_positions.size()):
			var world_pos = Vector2(x_positions[x_idx], y_positions[y_idx])
			
			# Skip if position is occupied or should be avoided
			if world_pos in occupied_positions or world_pos in avoid_positions:
				continue
			
			var grid_index = y_idx * GRID_WIDTH + x_idx
			if grid_index < weights.size():
				available_positions.append(world_pos)
				available_weights.append(weights[grid_index])
	
	# If no positions available, return empty array
	if available_positions.size() == 0:
		print("Warning: No available positions for entity type: ", entity_type)
		return []
	
	# Select positions using weighted random selection
	var selected_positions: Array[Vector2] = []
	var positions_copy = available_positions.duplicate()
	var weights_copy = available_weights.duplicate()
	
	for i in range(min(count, available_positions.size())):
		var selected_index = weighted_random_selection(weights_copy)
		selected_positions.append(positions_copy[selected_index])
		
		# Remove selected position from available lists
		positions_copy.remove_at(selected_index)
		weights_copy.remove_at(selected_index)
	
	print("Selected ", selected_positions.size(), " weighted positions for ", entity_type)
	return selected_positions

func weighted_random_selection(weights: Array[float]) -> int:
	"""Select an index based on weighted probabilities"""
	if weights.size() == 0:
		return 0
	
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	if total_weight <= 0.0:
		return randi() % weights.size()  # Fallback to random if no valid weights
	
	var random_value = randf() * total_weight
	var cumulative_weight = 0.0
	
	for i in range(weights.size()):
		cumulative_weight += weights[i]
		if random_value <= cumulative_weight:
			return i
	
	return weights.size() - 1  # Fallback

func get_random_available_positions(count: int, avoid_positions: Array[Vector2] = []) -> Array[Vector2]:
	"""Fallback method for random selection when gradients aren't used"""
	var available_positions: Array[Vector2] = []
	
	for x in x_positions:
		for y in y_positions:
			var pos = Vector2(x, y)
			if not pos in occupied_positions and not pos in avoid_positions:
				available_positions.append(pos)
	
	available_positions.shuffle()
	var selected_count = min(count, available_positions.size())
	return available_positions.slice(0, selected_count)

func reserve_positions(positions: Array[Vector2]):
	"""Mark positions as occupied"""
	for pos in positions:
		if not pos in occupied_positions:
			occupied_positions.append(pos)

func free_position(position: Vector2):
	"""Mark a position as available again"""
	var index = occupied_positions.find(position)
	if index != -1:
		occupied_positions.remove_at(index)

func clear_all_positions():
	"""Clear all position reservations (use when starting new level)"""
	occupied_positions.clear()

func get_all_occupied_positions() -> Array[Vector2]:
	"""Get all currently occupied positions"""
	return occupied_positions.duplicate()

func print_spawn_heatmap(entity_type: String):
	"""Debug function to visualize spawn weights"""
	if not spawn_weights.has(entity_type):
		print("No weights for entity type: ", entity_type)
		return
	
	var weights = spawn_weights[entity_type]
	print("Spawn heatmap for ", entity_type, ":")
	
	for y in range(GRID_HEIGHT):
		var row_string = ""
		for x in range(GRID_WIDTH):
			var index = y * GRID_WIDTH + x
			if index < weights.size():
				var weight_str = str(weights[index]).pad_decimals(1)
				row_string += weight_str + " "
		print(row_string)

# Visualization function for debugging
func create_debug_visualization() -> Control:
	"""Create a visual representation of spawn weights (for debugging)"""
	var control = Control.new()
	control.size = Vector2(300, 180)  # 15x9 grid scaled up
	
	# This would create colored rectangles showing spawn probabilities
	# Implementation would depend on your UI setup
	return control
