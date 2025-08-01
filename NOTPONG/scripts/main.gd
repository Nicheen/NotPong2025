class_name GamePlay extends Node2D

const gameover_scene:PackedScene = preload("res://scenes/menus/game_over.tscn")
const pausemenu_scene:PackedScene = preload("res://scenes/menus/pause_menu.tscn")

# Game settings
@export var play_area_size: Vector2 = Vector2(1152, 648)  # Match your window size
@export var play_area_center: Vector2 = Vector2(576, 324)  # Half of window size
@onready var hud: HUD = %HUD as HUD
@onready var spawn_manager: SpawnManager = %Spawner as SpawnManager

# Hardcoded scene paths
const PLAYER_SCENE = "res://scenes/obj/Player.tscn"
const ENEMY_SCENE = "res://scenes/obj/Enemy.tscn"
const ENEMY_BLOCK_SCENE = "res://scenes/obj/blocks/block.tscn"
const ENEMY_BLOCK_BLUE_SCENE = "res://scenes/obj/blocks/block_blue.tscn"
const ENEMY_BLOCK_LASER_SCENE = "res://scenes/obj/blocks/block_laser.tscn"
const ENEMY_BLOCK_THUNDER_SCENE = "res://scenes/obj/blocks/block_thunder.tscn"
const ENEMY_BLOCK_DROPPER_SCENE = "res://scenes/obj/blocks/block_dropper.tscn"
const BOSS_SCENE = "res://scenes/obj/bosses/Boss1.tscn"
const PAUSE_MENU_SCENE = "res://scenes/menus/pause_menu.tscn" 
const DEATH_MENU_SCENE = "res://scenes/menus/death_menu.tscn"
const WIN_MENU_SCENE = "res://scenes/menus/win_menu.tscn"
const THUNDER = "res://effects/thunder.tscn"

# Game objects
var level_manager: Node
var player: CharacterBody2D
var pause_menu: Control
var death_menu: Control
var win_menu: Control
var enemies: Array[StaticBody2D] = []
var blocks: Array[StaticBody2D] = []
var blue_blocks: Array[StaticBody2D] = []
var lazer_blocks: Array[StaticBody2D] = []
var thunder_blocks: Array[StaticBody2D] = []
var block_droppers: Array[StaticBody2D] = []
var bosses: Array[StaticBody2D] = []
var all_spawn_positions: Array[Vector2] = []

# Game state
var current_level: int = 1
var current_score: int = 0
var enemies_killed: int = 0
var total_enemies: int = 0
var game_won: bool = false

# Screen distortion effect system
var distortion_overlay: Control
var distortion_material: ShaderMaterial
var active_distortions: Array[Dictionary] = []
var distortion_id_counter: int = 0
const MAX_DISTORTIONS = 5

# Distortion settings for more realistic explosion effects
var default_force: float = 15.0  # Reduced for more subtle effect
var default_radius: float = 400.0  # Larger radius for bigger explosions
var default_duration: float = 3.0  # Longer duration for better visual

func _ready():
	# Set up the game
	setup_play_area()
	generate_spawn_positions()
	setup_level_manager()
	level_manager.start_level(current_level)
	spawn_player()
	setup_pause_menu()
	setup_death_menu()
	setup_win_menu()
	setup_screen_distortion()
	
	print("Game scene ready!")
	print("Total enemies spawned: ", total_enemies)

func _process(delta):
	"""Update distortion effects each frame"""
	update_distortions(delta)
	update_distortion_shader()

func setup_play_area():
	# You can still keep the grid background if you want
	create_grid_background()

func setup_level_manager():
	level_manager = Node.new()
	level_manager.name = "LevelManager"
	level_manager.set_script(load("res://scripts/level_manager.gd"))
	add_child(level_manager)
	
	# Give level manager access to main scene
	level_manager.main_scene = self
	
	print("Level manager setup complete")

func setup_screen_distortion():
	"""Create a screen-space distortion overlay that affects everything"""
	# Create a ColorRect that covers the entire screen
	distortion_overlay = ColorRect.new()
	distortion_overlay.name = "DistortionOverlay"
	distortion_overlay.size = play_area_size
	distortion_overlay.position = Vector2.ZERO
	distortion_overlay.z_index = 100  # Render on top of everything
	distortion_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	
	# Create shader material for screen distortion
	distortion_material = ShaderMaterial.new()
	
	# Load the screen distortion shader
	var distortion_shader = load("res://shaders/screen_distortion.gdshader")
	if distortion_shader == null:
		print("ERROR: Could not load screen distortion shader")
		return
	
	distortion_material.shader = distortion_shader
	
	# Load distortion texture (create a simple gradient if none exists)
	var distortion_texture = load("res://images/textures/VFX_NOEL_CIRCLE.jpg")
	if distortion_texture == null:
		# Create a simple radial gradient texture as fallback
		distortion_texture = create_distortion_texture()  
	
	distortion_material.set_shader_parameter("distortionTexture", distortion_texture)
	
	# Initialize distortion parameters
	var empty_centers: Array[Vector2] = []
	var empty_forces: Array[float] = []
	var empty_radiuses: Array[float] = []
	var empty_times: Array[float] = []
	
	for i in range(MAX_DISTORTIONS):
		empty_centers.append(Vector2.ZERO)
		empty_forces.append(0.0)
		empty_radiuses.append(0.0)
		empty_times.append(0.0)
	
	distortion_material.set_shader_parameter("distortion_centers", empty_centers)
	distortion_material.set_shader_parameter("distortion_forces", empty_forces)
	distortion_material.set_shader_parameter("distortion_radiuses", empty_radiuses)
	distortion_material.set_shader_parameter("distortion_times", empty_times)
	distortion_material.set_shader_parameter("active_distortions", 0)
	
	# Apply material to overlay
	distortion_overlay.material = distortion_material
	
	# Add as last child so it renders on top
	add_child(distortion_overlay)
	
	print("Screen distortion overlay created successfully")

func create_distortion_texture() -> ImageTexture:
	"""Create a simple gradient texture for distortion if none exists"""
	var image = Image.create(256, 256, false, Image.FORMAT_RGB8)
	
	for x in range(256):
		for y in range(256):
			# Create a radial gradient from center
			var center = Vector2(128, 128)
			var distance = Vector2(x, y).distance_to(center) / 128.0
			distance = clamp(distance, 0.0, 1.0)
			
			# Smooth gradient that's stronger at the edge
			var intensity = 1.0 - smoothstep(0.0, 1.0, distance)
			var color = Color(intensity, intensity, intensity)
			image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func create_distortion_effect(center: Vector2, force: float = -1.0, radius: float = -1.0, duration: float = -1.0) -> int:
	"""Create a new distortion effect at the given position"""
	
	# Use defaults if not specified
	if force < 0:
		force = default_force
	if radius < 0:
		radius = default_radius
	if duration < 0:
		duration = default_duration
	
	# Create distortion data
	var distortion = {
		"id": distortion_id_counter,
		"center": center,
		"force": force,
		"radius": radius,
		"duration": duration,
		"current_time": 0.0,
		"active": true
	}
	
	distortion_id_counter += 1
	
	# Add to active distortions (remove oldest if at max capacity)
	if active_distortions.size() >= MAX_DISTORTIONS:
		active_distortions.pop_front()
	
	active_distortions.append(distortion)
	
	print("Created screen distortion effect at ", center, " with force ", force)
	return distortion.id

func update_distortions(delta: float):
	"""Update all active distortions"""
	var i = active_distortions.size() - 1
	
	while i >= 0:
		var distortion = active_distortions[i]
		distortion.current_time += delta
		
		# Remove expired distortions
		if distortion.current_time >= distortion.duration:
			active_distortions.remove_at(i)
			print("Screen distortion effect expired")
		
		i -= 1

func update_distortion_shader():
	"""Update shader uniforms with current distortion data"""
	if not distortion_material:
		return
	
	# Prepare arrays for shader uniforms
	var centers: Array[Vector2] = []
	var forces: Array[float] = []
	var radiuses: Array[float] = []
	var times: Array[float] = []
	
	# Fill arrays with active distortion data
	for distortion in active_distortions:
		centers.append(distortion.center)
		forces.append(distortion.force)
		radiuses.append(distortion.radius)
		times.append(distortion.current_time)
	
	# Pad arrays to MAX_DISTORTIONS length
	while centers.size() < MAX_DISTORTIONS:
		centers.append(Vector2.ZERO)
		forces.append(0.0)
		radiuses.append(0.0)
		times.append(0.0)
	
	# Update shader parameters
	distortion_material.set_shader_parameter("distortion_centers", centers)
	distortion_material.set_shader_parameter("distortion_forces", forces)
	distortion_material.set_shader_parameter("distortion_radiuses", radiuses)
	distortion_material.set_shader_parameter("distortion_times", times)
	distortion_material.set_shader_parameter("active_distortions", active_distortions.size())

func create_enemy_death_distortion(enemy_position: Vector2):
	"""Create a distortion effect specifically for enemy death"""
	var force = randf_range(12.0, 20.0)  # More controlled force
	var radius = randf_range(100.0, 100.0)  # Bigger explosion radius
	var duration = randf_range(2.5, 3.5)  # Longer lasting effect
	
	create_distortion_effect(enemy_position, force, radius, duration)

func create_boss_death_distortion(boss_position: Vector2):
	"""Create a stronger distortion effect for boss death"""
	var force = randf_range(25.0, 35.0)  # Much stronger for bosses
	var radius = randf_range(200.0, 200.0)  # Massive explosion radius
	var duration = randf_range(4.0, 5.0)  # Long lasting boss explosion
	
	create_distortion_effect(boss_position, force, radius, duration)

# High Score Functions
func check_and_update_high_score():
	"""Check if current score is a new high score and update if needed"""
	if current_score > Global.save_data.high_score:
		Global.save_data.high_score = current_score
		Global.save_data.save()  # Save to disk
		print("NEW HIGH SCORE: ", current_score)
		
		# Update HUD to show new high score
		if hud:
			hud.high_score.text = "High Score: " + str(Global.save_data.high_score)
		
		if death_menu:
			death_menu.show_new_highscore_label()

func spawn_enemies():
	# Samla alla använda positioner från kvadrater
	var used_positions: Array[Vector2] = []
	for block in blocks:
		used_positions.append(block.global_position)
	
	# Skapa en set av använda positioner som strängar för exakt jämförelse
	var used_position_strings: Array[String] = []
	for pos in used_positions:
		used_position_strings.append(str(pos.x) + "," + str(pos.y))
	
	# Hitta lediga positioner
	var available_positions: Array[Vector2] = []
	for pos in all_spawn_positions:
		var pos_string = str(pos.x) + "," + str(pos.y)
		
		if not pos_string in used_position_strings:
			available_positions.append(pos)
	
	print("Blocks spawned at: ", used_positions.size(), " positions")
	print("Available positions: ", available_positions.size())
	
	# Spawna enemies
	available_positions.shuffle()
	var enemy_count = min(5, available_positions.size())
	
	for i in range(enemy_count):
		spawn_enemy_at_position(available_positions[i])
# In main.gd, update the spawn_enemy_at_position function:

func spawn_enemy_at_position(position: Vector2):
	var enemy_scene = load(ENEMY_SCENE)
	if not enemy_scene:
		print("ERROR: Could not load enemy scene at: ", ENEMY_SCENE)
		return
	
	var enemy = enemy_scene.instantiate()
	enemy.global_position = position
	
	# Connect enemy signals
	enemy.enemy_died.connect(_on_enemy_died_with_distortion)
	enemy.enemy_hit.connect(_on_enemy_hit)
	
	add_child(enemy)
	enemies.append(enemy)
	total_enemies += 1
	
	# FIX: Använd typed array
	var positions: Array[Vector2] = [position]
	spawn_manager.reserve_positions(positions)
	
	print("Spawned enemy at: ", position)
	
func generate_spawn_positions():
	# Rensa eventuella befintliga positioner
	all_spawn_positions.clear()
	
	# X-positioner (15 kolumner)
	var x_positions = [926, 876, 826, 776, 726, 676, 626, 576, 526, 476, 426, 376, 326, 276, 226]
	
	# Y-positioner (9 rader: 4 ovanför, mitten, 4 nedanför)
	var y_positions = [124, 174, 224, 274, 324, 374, 424, 474, 524]
	
	# Skapa alla kombinationer
	for x in x_positions:
		for y in y_positions:
			all_spawn_positions.append(Vector2(x, y))
	
	print("Generated ", all_spawn_positions.size(), " spawn positions")

func get_random_spawn_positions(count: int) -> Array[Vector2]:
	"""Fallback random spawn positions that avoids overlaps"""
	return spawn_manager.get_random_available_positions(count)

func get_all_spawn_positions() -> Array[Vector2]:
	# Returnera alla spawn-positioner
	return all_spawn_positions.duplicate()

func spawn_enemy_kvadrat():
	# Använd den nya funktionen
	var selected_positions = get_random_spawn_positions(20)
	
	for pos in selected_positions:
		spawn_enemy_kvadrat_at_position(pos)
		
func spawn_enemy_block_dropper():
	# Använd den nya funktionen
	var selected_positions = get_random_spawn_positions(20)
	
	for pos in selected_positions:
		spawn_enemy_block_dropper_at_position(pos)

func spawn_blue_block_at_position(position: Vector2):
	var block_scene = load(ENEMY_BLOCK_BLUE_SCENE)
	if not block_scene:
		print("ERROR: Could not load blue block scene at: ", ENEMY_BLOCK_BLUE_SCENE)
		return
	
	var block = block_scene.instantiate()
	block.global_position = position
	
	# Connect signals
	block.block_died.connect(_on_block_died)
	block.block_hit.connect(_on_enemy_hit)
	
	add_child(block)
	blue_blocks.append(block)
	total_enemies += 1
	
	# FIX: Använd typed array
	var positions: Array[Vector2] = [position]
	spawn_manager.reserve_positions(positions)
	
	print("Spawned blue block at: ", position)
	
func spawn_random_enemies(count: int):
	# Förenklad version
	var selected_positions = get_random_spawn_positions(count)
	
	for pos in selected_positions:
		spawn_enemy_kvadrat_at_position(pos)

func spawn_boss_at_center():
	# Hitta center-positioner
	var center_positions = all_spawn_positions.filter(func(pos): return pos.y == 324)
	var boss_pos = center_positions[center_positions.size() / 2]  # Mitten av center-raden
	
	# Spawna boss här...
	print("Spawning boss at: ", boss_pos)

func spawn_enemy_block_dropper_at_position(position: Vector2):
	var block_scene = load(ENEMY_BLOCK_DROPPER_SCENE)
	if not block_scene:
		print("ERROR: Could not load block dropper scene at: ", ENEMY_BLOCK_DROPPER_SCENE)
		return
	
	var block = block_scene.instantiate()
	block.global_position = position
	
	# Connect signals
	block.block_dropper_died.connect(_on_block_died)
	block.block_dropper_hit.connect(_on_enemy_hit)
	
	add_child(block)
	block_droppers.append(block)
	total_enemies += 1
	
	# FIX: Använd typed array
	var positions: Array[Vector2] = [position]
	spawn_manager.reserve_positions(positions)
	
	print("Spawned block dropper at: ", position)
	
func spawn_blue_blocks(count: int):
	var selected_positions = get_random_spawn_positions(count)
	
	for pos in selected_positions:
		spawn_blue_block_at_position(pos)
		
func spawn_enemy_kvadrat_at_position(position: Vector2):
	var block_scene = load(ENEMY_BLOCK_SCENE)
	if not block_scene:
		print("ERROR: Could not load enemy block scene at: ", ENEMY_BLOCK_SCENE)
		return
	
	var block = block_scene.instantiate()
	block.global_position = position
	
	# Connect signals
	block.block_died.connect(_on_block_died)
	block.block_hit.connect(_on_enemy_hit)
	
	add_child(block)
	blocks.append(block)
	total_enemies += 1
	
	# FIX: Använd typed array
	var positions: Array[Vector2] = [position]
	spawn_manager.reserve_positions(positions)
	
	print("Spawned block at: ", position)
	
func spawn_enemy_lazer():
	# Samla alla använda positioner från block och lazer-block
	var used_positions: Array[Vector2] = []
	for block in blocks:
		used_positions.append(block.global_position)
	for lazer_block in lazer_blocks:
		used_positions.append(lazer_block.global_position)
	
	# Skapa set av använda positioner
	var used_position_strings: Array[String] = []
	for pos in used_positions:
		used_position_strings.append(str(pos.x) + "," + str(pos.y))
	
	# Hitta lediga positioner
	var available_positions: Array[Vector2] = []
	for pos in all_spawn_positions:
		var pos_string = str(pos.x) + "," + str(pos.y)
		if not pos_string in used_position_strings:
			available_positions.append(pos)
	
	# Spawna lazer-block
	available_positions.shuffle()
	var lazer_count = min(2, available_positions.size())
	
	for i in range(lazer_count):
		spawn_enemy_lazer_at_position(available_positions[i])

func spawn_enemy_lazer_at_position(position: Vector2):
	var lazer_scene = load(ENEMY_BLOCK_LASER_SCENE)
	if not lazer_scene:
		print("ERROR: Could not load laser block scene at: ", ENEMY_BLOCK_LASER_SCENE)
		return
	
	var lazer_block = lazer_scene.instantiate()
	lazer_block.global_position = position
	
	# Connect signals
	lazer_block.block_died.connect(_on_block_died)
	lazer_block.block_hit.connect(_on_enemy_hit)
	
	add_child(lazer_block)
	lazer_blocks.append(lazer_block)
	total_enemies += 1
	
	# FIX: Använd typed array
	var positions: Array[Vector2] = [position]
	spawn_manager.reserve_positions(positions)
	
	print("Spawned laser block at: ", position)
	
func spawn_player():
	# Load and instantiate the player scene
	var player_scene = load(PLAYER_SCENE)
	player = player_scene.instantiate()
	add_child(player)
	move_child(player, 1)
	
	# Set player position to center bottom
	var bottom_y = play_area_center.y + (play_area_size.y * 0.5) - 50  # 50px från botten
	player.global_position = Vector2(play_area_center.x, bottom_y)
	
	# Set up the player
	if player.has_method("set_play_area"):
		player.set_play_area(play_area_center, play_area_size)
		print("Set player play area")
	
	# Connect player signals
	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)

func setup_pause_menu():
	# Load and instantiate the pause menu
	var pause_menu_scene = load(PAUSE_MENU_SCENE)
	pause_menu = pause_menu_scene.instantiate()
	add_child(pause_menu)
	
	print("Pause menu setup complete")

func setup_death_menu():
	# Load and instantiate the death menu
	var death_menu_scene = load(DEATH_MENU_SCENE)
	death_menu = death_menu_scene.instantiate()
	add_child(death_menu)
	
	print("Death menu setup complete")

func setup_win_menu():
	# Load and instantiate the win menu
	var win_menu_scene = load(WIN_MENU_SCENE)
	win_menu = win_menu_scene.instantiate()
	add_child(win_menu)
	
	print("Win menu setup complete")
	
func _on_player_died():
	print("Player died! Final score: ", current_score)
	
	# Check and update high score before showing death menu
	check_and_update_high_score()
	
	# Show death menu with score
	if death_menu and death_menu.has_method("show_death_menu"):
		# Update score display in death menu
		update_death_menu_score()
		death_menu.show_death_menu()

func spawn_thunder_block_at_position(position: Vector2):
	"""Spawn a single thunder block at the specified position"""
	var block_scene = load(ENEMY_BLOCK_THUNDER_SCENE)
	if not block_scene:
		print("ERROR: Could not load thunder block scene at: ", ENEMY_BLOCK_THUNDER_SCENE)
		return
	
	var block = block_scene.instantiate()
	block.global_position = position + Vector2(-25, -25)
	
	# Connect signals - use the correct signal name from the thunder block
	block.block_destroyed.connect(_on_thunder_block_died)
	
	add_child(block)
	thunder_blocks.append(block)
	total_enemies += 1
	
	# Reserve 2x2 area (4 positions) in spawn manager
	var positions_to_reserve = get_2x2_positions(position)
	spawn_manager.reserve_positions(positions_to_reserve)
	
	print("Spawned 2x2 thunder block at: ", position)

func get_2x2_positions(center_pos: Vector2) -> Array[Vector2]:
	"""Get all 4 positions that a 2x2 block occupies"""
	var positions: Array[Vector2] = []
	
	# Find the center position indices in the grid
	var x_positions = spawn_manager.x_positions
	var y_positions = spawn_manager.y_positions
	
	var center_x_idx = x_positions.find(int(center_pos.x))
	var center_y_idx = y_positions.find(int(center_pos.y))
	
	if center_x_idx == -1 or center_y_idx == -1:
		print("ERROR: Center position not found in grid")
		return positions
	
	# Add all 4 positions (2x2 grid)
	for x_offset in [-1, 0]:
		for y_offset in [-1, 0]:
			var x_idx = center_x_idx + x_offset
			var y_idx = center_y_idx + y_offset
			
			# Check bounds
			if x_idx >= 0 and x_idx < x_positions.size() and y_idx >= 0 and y_idx < y_positions.size():
				positions.append(Vector2(x_positions[x_idx], y_positions[y_idx]))
	
	return positions

func spawn_thunder_blocks(count: int):
	"""Spawn multiple thunder blocks at random valid positions"""
	var placed_count = 0
	var attempts = 0
	var max_attempts = count * 10  # Avoid infinite loops
	
	while placed_count < count and attempts < max_attempts:
		attempts += 1
		
		# Get a random position that could fit a 2x2 block
		var potential_center = get_random_2x2_center_position()
		
		if potential_center != Vector2.ZERO:
			spawn_thunder_block_at_position(potential_center)
			placed_count += 1
		
	print("Placed ", placed_count, " thunder blocks out of ", count, " requested")

func get_random_2x2_center_position() -> Vector2:
	"""Get a random position that can accommodate a 2x2 block"""
	var x_positions = spawn_manager.x_positions
	var y_positions = spawn_manager.y_positions
	
	# Thunder blocks need space for 2x2, so avoid edges
	var valid_x_indices = range(1, x_positions.size() - 1)  # Exclude first and last
	var valid_y_indices = range(1, y_positions.size() - 1)  # Exclude first and last
	
	# Shuffle for randomness
	valid_x_indices.shuffle()
	valid_y_indices.shuffle()
	
	# Try to find a valid center position
	for x_idx in valid_x_indices:
		for y_idx in valid_y_indices:
			var center_pos = Vector2(x_positions[x_idx], y_positions[y_idx])
			
			if can_place_2x2_block(center_pos):
				return center_pos
	
	print("WARNING: No valid 2x2 position found for thunder block")
	return Vector2.ZERO

func can_place_2x2_block(center_position: Vector2) -> bool:
	"""Check if a 2x2 block can be placed at the given center position"""
	var required_positions = get_2x2_positions(center_position)
	
	# Need exactly 4 positions for a 2x2 block
	if required_positions.size() != 4:
		return false
	
	# Check if all positions are available
	for pos in required_positions:
		if pos in spawn_manager.occupied_positions:
			return false
	
	return true

func spawn_thunder_blocks_weighted(count: int):
	"""Spawn thunder blocks using weighted positioning (avoiding edges due to 2x2 size)"""
	var placed_count = 0
	var attempts = 0
	var max_attempts = count * 15
	
	while placed_count < count and attempts < max_attempts:
		attempts += 1
		
		# Get weighted positions but filter for 2x2 compatibility
		var potential_positions = spawn_manager.get_weighted_spawn_positions("thunder_blocks", count * 3)
		
		for pos in potential_positions:
			if can_place_2x2_block(pos):
				spawn_thunder_block_at_position(pos)
				placed_count += 1
				break
		
		if placed_count >= count:
			break
	
	print("Placed ", placed_count, " weighted thunder blocks out of ", count, " requested")

func _on_thunder_block_died(score_points: int):
	"""Handle thunder block death"""
	current_score += score_points
	enemies_killed += 1
	
	# Update HUD
	if hud:
		hud.update_score(current_score)

	print("Thunder block destroyed! Score: ", score_points)
	
	# Check win condition
	if enemies_killed >= total_enemies:
		if level_manager and level_manager.has_method("level_completed"):
			level_manager.level_completed()
		else:
			player_wins()

func _on_enemy_died(score_points: int):
	enemies_killed += 1
	current_score += score_points
	
	print("Enemy killed! Score: ", current_score, " Enemies remaining: ", (total_enemies - enemies_killed))
	
	# Update UI (this will also check for high score updates in real-time)
	update_ui()
	
	# Check win condition
	if enemies_killed >= total_enemies:
		if level_manager and level_manager.has_method("level_completed"):
			# Remove this line: current_level += 1
			level_manager.level_completed()
		else:
			player_wins()  # Fallbackback
			
# Replace the damage_adjacent_blocks function in main.gd with this improved version:

# Replace the damage_adjacent_blocks function in main.gd with this version that uses the SpawnManager's arrays:

func damage_adjacent_blocks(enemy_position: Vector2, damage: int = 10):
	"""Damage all blocks in adjacent tiles (8 surrounding tiles)"""
	
	# Use the spawn manager's coordinate arrays instead of hardcoded ones
	if not spawn_manager:
		print("ERROR: No spawn manager available for damage calculation")
		return
	
	var x_positions = spawn_manager.x_positions
	var y_positions = spawn_manager.y_positions
	
	print("DEBUG: Enemy position = ", enemy_position)
	print("DEBUG: Enemy position x type = ", typeof(enemy_position.x))
	print("DEBUG: Enemy position y type = ", typeof(enemy_position.y))
	print("DEBUG: First x_position = ", x_positions[0], " type = ", typeof(x_positions[0]))
	print("DEBUG: First y_position = ", y_positions[0], " type = ", typeof(y_positions[0]))
	
	# Convert enemy position to integers to match array values
	var enemy_x = int(enemy_position.x)
	var enemy_y = int(enemy_position.y)
	
	print("DEBUG: Converted enemy_x = ", enemy_x, " enemy_y = ", enemy_y)
	
	# Find the grid index of the enemy position
	var enemy_x_idx = x_positions.find(enemy_x)
	var enemy_y_idx = y_positions.find(enemy_y)
	
	print("DEBUG: enemy_x_idx = ", enemy_x_idx, " enemy_y_idx = ", enemy_y_idx)
	
	if enemy_x_idx == -1 or enemy_y_idx == -1:
		print("Enemy position still not found after conversion: (", enemy_x, ", ", enemy_y, ")")
		
		# Manual search with debug info
		print("Manual search for x = ", enemy_x)
		for i in range(x_positions.size()):
			print("  x_positions[", i, "] = ", x_positions[i], " match = ", (x_positions[i] == enemy_x))
			if x_positions[i] == enemy_x:
				enemy_x_idx = i
				break
		
		print("Manual search for y = ", enemy_y)
		for i in range(y_positions.size()):
			print("  y_positions[", i, "] = ", y_positions[i], " match = ", (y_positions[i] == enemy_y))
			if y_positions[i] == enemy_y:
				enemy_y_idx = i
				break
		
		if enemy_x_idx == -1 or enemy_y_idx == -1:
			print("Manual search also failed. Aborting damage calculation.")
			return
	
	print("Enemy died at grid position [", enemy_x_idx, ", ", enemy_y_idx, "] = (", enemy_x, ", ", enemy_y, ")")
	
	# Check all 8 adjacent positions (including diagonals)
	var adjacent_offsets = [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),  # Top row
		Vector2(-1,  0),                 Vector2(1,  0),  # Middle row (skip center)
		Vector2(-1,  1), Vector2(0,  1), Vector2(1,  1)   # Bottom row
	]
	
	var blocks_damaged = 0
	
	for offset in adjacent_offsets:
		var check_x_idx = enemy_x_idx + offset.x
		var check_y_idx = enemy_y_idx + offset.y
		
		# Make sure we're within grid bounds
		if check_x_idx < 0 or check_x_idx >= x_positions.size():
			print("Adjacent position out of bounds X: ", check_x_idx)
			continue
		if check_y_idx < 0 or check_y_idx >= y_positions.size():
			print("Adjacent position out of bounds Y: ", check_y_idx)
			continue
		
		# Get the world position to check
		var check_position = Vector2(x_positions[check_x_idx], y_positions[check_y_idx])
		print("Checking adjacent position: ", check_position, " (grid [", check_x_idx, ", ", check_y_idx, "])")
		
		# Find any block at this position and damage it
		var block_to_damage = find_block_at_position(check_position)
		if block_to_damage and block_to_damage.has_method("take_damage"):
			block_to_damage.take_damage(damage)
			blocks_damaged += 1
			print("✓ Enemy death damaged adjacent block at: ", check_position, " for ", damage, " damage")
		else:
			print("✗ No block found at adjacent position: ", check_position)
	
	print("Total blocks damaged by explosion: ", blocks_damaged)
	
func find_closest_grid_position(position: Vector2, x_positions: Array, y_positions: Array) -> Vector2:
	"""Find the closest valid grid position to the given position"""
	var closest_x = x_positions[0]
	var closest_y = y_positions[0]
	var min_distance = 999999.0
	
	for x in x_positions:
		for y in y_positions:
			var grid_pos = Vector2(x, y)
			var distance = position.distance_to(grid_pos)
			if distance < min_distance:
				min_distance = distance
				closest_x = x
				closest_y = y
	
	# Only return if the closest position is reasonably close (within 100 pixels)
	if min_distance <= 100.0:
		return Vector2(closest_x, closest_y)
	else:
		return Vector2.ZERO

# Keep the improved find_block_at_position function:
func find_block_at_position(position: Vector2):
	"""Find any block (of any type) at the given position"""
	var tolerance = 10.0  # Large tolerance for testing
	var closest_block = null
	var closest_distance = 999999.0
	
	print("=== SEARCHING FOR BLOCKS NEAR ", position, " ===")
	print("Block array sizes:")
	print("  blocks: ", blocks.size())
	print("  blue_blocks: ", blue_blocks.size())
	print("  lazer_blocks: ", lazer_blocks.size())
	print("  block_droppers: ", block_droppers.size())
	
	# Check blocks array
	print("Checking blocks array:")
	for i in range(blocks.size()):
		var block = blocks[i]
		if is_instance_valid(block):
			var distance = position.distance_to(block.global_position)
			print("  blocks[", i, "]: ", block.global_position, " distance: ", distance)
			if distance <= tolerance and distance < closest_distance:
				closest_block = block
				closest_distance = distance
				print("    ^ NEW CLOSEST BLOCK!")
		else:
			print("  blocks[", i, "]: INVALID")
	
	# Check blue_blocks array
	print("Checking blue_blocks array:")
	for i in range(blue_blocks.size()):
		var block = blue_blocks[i]
		if is_instance_valid(block):
			var distance = position.distance_to(block.global_position)
			print("  blue_blocks[", i, "]: ", block.global_position, " distance: ", distance)
			if distance <= tolerance and distance < closest_distance:
				closest_block = block
				closest_distance = distance
				print("    ^ NEW CLOSEST BLOCK!")
		else:
			print("  blue_blocks[", i, "]: INVALID")
	
	# Check lazer_blocks array
	print("Checking lazer_blocks array:")
	for i in range(lazer_blocks.size()):
		var block = lazer_blocks[i]
		if is_instance_valid(block):
			var distance = position.distance_to(block.global_position)
			print("  lazer_blocks[", i, "]: ", block.global_position, " distance: ", distance)
			if distance <= tolerance and distance < closest_distance:
				closest_block = block
				closest_distance = distance
				print("    ^ NEW CLOSEST BLOCK!")
		else:
			print("  lazer_blocks[", i, "]: INVALID")
	
	# Check block_droppers array
	print("Checking block_droppers array:")
	for i in range(block_droppers.size()):
		var block = block_droppers[i]
		if is_instance_valid(block):
			var distance = position.distance_to(block.global_position)
			print("  block_droppers[", i, "]: ", block.global_position, " distance: ", distance)
			if distance <= tolerance and distance < closest_distance:
				closest_block = block
				closest_distance = distance
				print("    ^ NEW CLOSEST BLOCK!")
		else:
			print("  block_droppers[", i, "]: INVALID"
			)
	# Check block_droppers array
	print("Checking enemies array (bombs):")
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if is_instance_valid(enemy):
			var distance = position.distance_to(enemy.global_position)
			print("  bomb[", i, "]: ", enemy.global_position, " distance: ", distance)
			if distance <= tolerance and distance < closest_distance:
				closest_block = enemy
				closest_distance = distance
				print("    ^ NEW CLOSEST BOMB!")
		else:
			print("  bombs[", i, "]: INVALID")
			
	if closest_block:
		print("RESULT: Found closest block at distance ", closest_distance, " from ", position)
		print("        Block position: ", closest_block.global_position)
	else:
		print("RESULT: No blocks found within ", tolerance, " pixels of ", position)
	
	print("=== END BLOCK SEARCH ===")
	return closest_block
	
func debug_game_state():
	"""Print comprehensive game state for debugging"""
	print("\n=== GAME STATE DEBUG ===")
	print("Total enemies spawned: ", total_enemies)
	print("Enemies killed: ", enemies_killed)
	print("Current level: ", current_level)
	
	print("\nEntity counts:")
	print("  enemies array: ", enemies.size())
	print("  blocks array: ", blocks.size())
	print("  blue_blocks array: ", blue_blocks.size())
	print("  lazer_blocks array: ", lazer_blocks.size())
	print("  block_droppers array: ", block_droppers.size())
	print("  bosses array: ", bosses.size())
	
	print("\nSpawn manager state:")
	if spawn_manager:
		print("  Occupied positions: ", spawn_manager.occupied_positions.size())
		print("  X positions: ", spawn_manager.x_positions.size())
		print("  Y positions: ", spawn_manager.y_positions.size())
	else:
		print("  ERROR: No spawn manager!")
	
	print("\nAll spawn positions: ", all_spawn_positions.size())
	print("=== END GAME STATE DEBUG ===\n")
	
func _on_enemy_died_with_distortion(score_points: int, death_position: Vector2):
	"""Handle enemy death with distortion effect"""
	print("\n🔥 ENEMY DIED AT: ", death_position, " 🔥")
	
	# Debug the game state first
	debug_game_state()
	
	create_enemy_death_distortion(death_position)
	damage_adjacent_blocks(death_position, 10)
	_on_enemy_died(score_points)

func _on_boss_died_with_distortion(score_points: int, death_position: Vector2):
	"""Handle boss death with stronger distortion effect"""
	create_boss_death_distortion(death_position)
	_on_enemy_died(score_points)

func _on_block_died(score_points: int):
	current_score += score_points
	enemies_killed += 1
	
	# Find and free the position of the destroyed block
	cleanup_destroyed_entity_position()
	
	# Check win condition
	if enemies_killed >= total_enemies:
		if level_manager and level_manager.has_method("level_completed"):
			# VIKTIG FIX: Ta bort denna rad som orsakar dubbel ökning
			# current_level += 1  <-- RADERA DENNA RAD!
			level_manager.level_completed()
		else:
			player_wins()

func cleanup_destroyed_entity_position():
	"""Clean up positions of destroyed entities"""
	# This is called when entities die - you might want to track specific positions
	# For now, we'll rely on the level clearing to reset positions
	pass

func _on_enemy_hit(damage: int):
	# Optional: Add score for hitting enemies
	current_score += damage
	update_ui()
	
func _on_player_health_changed(new_health: int):
	print("Player health: ", new_health)

func player_wins():
	game_won = true
	print("PLAYER WINS! Final score: ", current_score)
	
	# Check and update high score before showing win menu
	check_and_update_high_score()
	
	# Show win menu with score
	if win_menu and win_menu.has_method("show_win_menu"):
		win_menu.show_win_menu(current_score)

func update_death_menu_score():
	# Update the score label in death menu
	var score_label_in_death_menu = death_menu.get_node_or_null("Panel/VBoxContainer/ScoreLabel")
	if score_label_in_death_menu:
		score_label_in_death_menu.text = "Final Score: " + str(current_score)
			
func update_ui():
	# FIX: Använd level_manager.current_level istället för lokal current_level
	if level_manager:
		hud.update_level(level_manager.current_level)
	hud.update_score(current_score)
	
	# Check for high score updates in real-time and update HUD
	if current_score > Global.save_data.high_score:
		check_and_update_high_score()

func create_grid_background():
	# You can keep the original grid background if you want
	# It won't have distortion anymore, but will provide the grid visual
	pass

func spawn_blocks_weighted(count: int):
	"""Spawn regular blocks using weighted positioning"""
	var positions = spawn_manager.get_weighted_spawn_positions("blocks", count)
	
	for pos in positions:
		spawn_enemy_kvadrat_at_position(pos)

func spawn_blue_blocks_weighted(count: int):
	"""Spawn blue blocks using weighted positioning"""
	var positions = spawn_manager.get_weighted_spawn_positions("blue_blocks", count)
	
	for pos in positions:
		spawn_blue_block_at_position(pos)

func spawn_laser_blocks_weighted(count: int):
	"""Spawn laser blocks using weighted positioning"""
	var positions = spawn_manager.get_weighted_spawn_positions("laser_blocks", count)
	
	for pos in positions:
		spawn_enemy_lazer_at_position(pos)

func spawn_block_droppers_weighted(count: int):
	"""Spawn block droppers using weighted positioning"""
	var positions = spawn_manager.get_weighted_spawn_positions("block_droppers", count)
	
	for pos in positions:
		spawn_enemy_block_dropper_at_position(pos)

func spawn_enemies_weighted(count: int):
	"""Spawn enemies using weighted positioning, avoiding all block positions"""
	var positions = spawn_manager.get_weighted_spawn_positions("enemies", count)
	
	for pos in positions:
		spawn_enemy_at_position(pos)

func clear_level_entities():
	"""Clear all entities and reset spawn positions"""
	# Clear all entities (your existing code)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	for block in blocks:
		if is_instance_valid(block):
			block.queue_free()
	
	for lazer_block in lazer_blocks:
		if is_instance_valid(lazer_block):
			lazer_block.queue_free()
	
	for thunder_block in thunder_blocks:
		if is_instance_valid(thunder_block):
			thunder_block.queue_free()
			
	for block_dropper in block_droppers:
		if is_instance_valid(block_dropper):
			block_dropper.queue_free()
	
	for blue_block in blue_blocks:
		if is_instance_valid(blue_block):
			blue_block.queue_free()
	
	for boss in bosses:
		if is_instance_valid(boss):
			boss.queue_free()
	
	# Clear arrays
	enemies.clear()
	blocks.clear()
	lazer_blocks.clear()
	thunder_blocks.clear()
	block_droppers.clear()
	blue_blocks.clear()
	bosses.clear()
	
	# Reset spawn manager positions
	spawn_manager.clear_all_positions()
	
	# Reset counters
	enemies_killed = 0
	total_enemies = 0

# Debug function to visualize spawn weights
func debug_spawn_weights():
	"""Print spawn weight visualizations for debugging"""
	print("=== SPAWN WEIGHT DEBUG ===")
	spawn_manager.print_spawn_heatmap("blocks")
	print()
	spawn_manager.print_spawn_heatmap("enemies")
	print()
	spawn_manager.print_spawn_heatmap("blue_blocks")
	print()
	spawn_manager.print_spawn_heatmap("laser_blocks")
	print()
	spawn_manager.print_spawn_heatmap("thunder_blocks")
	print()
	spawn_manager.print_spawn_heatmap("block_droppers")
