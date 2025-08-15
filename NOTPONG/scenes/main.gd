class_name GamePlay extends Node2D

const gameover_scene:PackedScene = preload("res://scenes/menus/game_over.tscn")
const pausemenu_scene:PackedScene = preload("res://scenes/menus/pause_menu.tscn")

# Game settingsd
@export var play_area_size: Vector2 = Vector2(1152, 648)  # Match your window size
@export var play_area_center: Vector2 = Vector2(576, 324)  # Half of window size
@onready var hud: HUD = %HUD as HUD
@onready var spawn_manager: SpawnManager = %Spawner as SpawnManager

const HURT_COLOR = Color.RED
const KILL_COLOR = Color.GOLD
const HURT_FONT_SIZE = 15
const KILL_FONT_SIZE = 28

# Hardcoded scene paths
const PLAYER_SCENE = "res://scenes/obj/Player.tscn"
const ENEMY_SCENE = "res://scenes/obj/Enemy.tscn"
const ENEMY_BLOCK_SCENE = "res://scenes/obj/blocks/block_red.tscn"
const ENEMY_BLOCK_BLUE_SCENE = "res://scenes/obj/blocks/block_blue.tscn"
const ENEMY_BLOCK_LASER_SCENE = "res://scenes/obj/blocks/block_laser.tscn"
const ENEMY_BLOCK_DROPPER_SCENE = "res://scenes/obj/blocks/block_dropper.tscn"
const ENEMY_BLOCK_IRON_SCENE = "res://scenes/obj/blocks/block_iron.tscn"
const ENEMY_BLOCK_CLOUD_SCENE = "res://scenes/obj/blocks/block_cloud.tscn"

const BOSS_SCENE = "res://scenes/obj/bosses/Boss1.tscn"
const BOSS_THUNDER_SCENE = "res://scenes/obj/bosses/Boss_Thunder.tscn"

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
var iron_blocks: Array = []
var cloud_blocks: Array[StaticBody2D] = []


# Game state
var current_level: int = 1
var current_score: int = 0
var enemies_killed: int = 0
var total_enemies: int = 0
var game_timer: float = 0.0
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
	generate_spawn_positions()
	setup_level_manager()
	level_manager.start_level(current_level)
	spawn_player()
	setup_pause_menu()
	setup_death_menu()
	setup_win_menu()
	setup_screen_distortion()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	print("Game scene ready!")
	print("Total enemies spawned: ", total_enemies)

func _process(delta):
	"""Update distortion effects each frame"""
	game_timer += delta
	hud.update_timer(game_timer)
	update_distortions(delta)
	update_distortion_shader()

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
	var radius = randf_range(150.0, 150.0)  # Bigger explosion radius
	var duration = randf_range(2.5, 3.5)  # Longer lasting effect
	
	create_distortion_effect(enemy_position, force, radius, duration)

func create_boss_death_distortion(boss_position: Vector2):
	"""Create a stronger distortion effect for boss death"""
	var force = randf_range(25.0, 35.0)  # Much stronger for bosses
	var radius = randf_range(200.0, 200.0)  # Massive explosion radius
	var duration = randf_range(4.0, 5.0)  # Long lasting boss explosion
	
	create_distortion_effect(boss_position, force, radius, duration)

func spawn_iron_block_at_position(position: Vector2):
	var block_scene = load(ENEMY_BLOCK_IRON_SCENE)
	if not block_scene:
		print("ERROR: Could not load iron block scene at: ", ENEMY_BLOCK_IRON_SCENE)
		return
	
	var block = block_scene.instantiate()
	block.global_position = position
	
	# Connect signals with position awareness
	block.block_died.connect(func(score): 
		create_floating_score_text(block.global_position, score, true)
		_on_block_died(score)
	)
	block.block_hit.connect(func(damage): 
		create_floating_score_text(block.global_position, damage, false)
		_on_enemy_hit(damage)
	)
	
	add_child(block)
	iron_blocks.append(block)
	total_enemies += 1
	
	# Reserve position
	var positions: Array[Vector2] = [position]
	spawn_manager.reserve_positions(positions)
	
	print("Spawned iron block at: ", position)
	

func spawn_cloud_block_at_position(position: Vector2):
	var block_scene = load(ENEMY_BLOCK_CLOUD_SCENE)
	if not block_scene:
		print("ERROR: Could not load cloud block scene at: ", ENEMY_BLOCK_CLOUD_SCENE)
		return
	
	var block = block_scene.instantiate()
	block.global_position = position
	
	# Connect signals with position awareness
	block.block_died.connect(func(score): 
		create_floating_score_text(block.global_position, score, true)
		_on_block_died(score)
	)
	block.block_hit.connect(func(damage): 
		create_floating_score_text(block.global_position, damage, false)
		_on_enemy_hit(damage)
	)
	
	add_child(block)
	cloud_blocks.append(block)
	total_enemies += 1
	
	# Reserve position
	var positions: Array[Vector2] = [position]
	spawn_manager.reserve_positions(positions)
	
	print("Spawned cloud block at: ", position)

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
	
	# Connect signals with position awareness
	enemy.enemy_died.connect(_on_enemy_died_with_distortion)
	
	enemy.enemy_hit.connect(func(damage): 
		create_floating_score_text(enemy.global_position, damage, false)
		_on_enemy_hit(damage)
	)
	
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
	
	# Connect signals with position awareness
	block.block_died.connect(func(score): 
		create_floating_score_text(block.global_position, score, true)
		_on_block_died(score)
	)
	block.block_hit.connect(func(damage): 
		create_floating_score_text(block.global_position, damage, false)
		_on_enemy_hit(damage)
	)
	
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
	
	# Connect signals with position awareness
	block.block_dropper_died.connect(func(score): 
		create_floating_score_text(block.global_position, score, true)
		_on_block_died(score)
	)
	block.block_dropper_hit.connect(func(damage): 
		create_floating_score_text(block.global_position, damage, false)
		_on_enemy_hit(damage)
	)
	
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
	
	# Connect signals with position awareness
	block.block_died.connect(func(score): 
		create_floating_score_text(block.global_position, score, true)
		_on_block_died(score)
	)
	block.block_hit.connect(func(damage): 
		create_floating_score_text(block.global_position, damage, false)
		_on_enemy_hit(damage)
	)
	
	add_child(block)
	blocks.append(block)
	total_enemies += 1
	
	# FIX: Använd typed array
	var positions: Array[Vector2] = [position]
	spawn_manager.reserve_positions(positions)
	
	print("Spawned block at: ", position)
	

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
	
	var highscore: float = Global.save_data.high_score
	var player_name: String = Global.save_data.player_name
	
	if current_score > highscore:
		SilentWolf.Scores.save_score(player_name, current_score)
		
	# Check and update high score before showing death menu
	check_and_update_high_score()
	
	# Show death menu with score
	if death_menu and death_menu.has_method("show_death_menu"):
		# Update score display in death menu
		update_death_menu_score()
		death_menu.show_death_menu(current_score)
# Add this function to your main.gd file (you already have spawn_enemy_lazer_at_position, this is the simple version)

func spawn_laser_block_at_position(position: Vector2):
	var laser_scene = load(ENEMY_BLOCK_LASER_SCENE)
	if not laser_scene:
		print("ERROR: Could not load laser block scene at: ", ENEMY_BLOCK_LASER_SCENE)
		return
	
	var laser_block = laser_scene.instantiate()
	laser_block.global_position = position

	# Connect signals with position awareness
	laser_block.block_died.connect(func(score): 
		create_floating_score_text(laser_block.global_position, score, true)
		_on_block_died(score)
	)
	laser_block.block_hit.connect(func(damage): 
		create_floating_score_text(laser_block.global_position, damage, false)
		_on_enemy_hit(damage)
	)
	
	add_child(laser_block)
	lazer_blocks.append(laser_block)
	total_enemies += 1
	
	# Reserve position
	var positions: Array[Vector2] = [position]
	spawn_manager.reserve_positions(positions)
	
	print("Spawned laser block at: ", position)
	
func spawn_thunder_block_at_position(position: Vector2):
	"""Spawn a single thunder block at the specified position"""
	var block_scene = load(BOSS_THUNDER_SCENE)
	if not block_scene:
		print("ERROR: Could not load thunder block scene at: ", BOSS_THUNDER_SCENE)
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
		
		var block_to_damage = find_block_at_position(check_position)
		if block_to_damage and block_to_damage.has_method("take_damage"):
			var method_info = block_to_damage.get_method_list().filter(func(m): return m.name == "take_damage")
			if method_info.size() > 0 and method_info[0].args.size() == 2:
				block_to_damage.take_damage(damage, true)
			elif method_info.size() > 0 and method_info[0].args.size() == 1:
				block_to_damage.take_damage(damage)
			else:
				print("✗ take_damage has unexpected number of arguments for block at: ", check_position)
			
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
	print("Checking iron_blocks array:")
	
	for i in range(iron_blocks.size()):
		var block = iron_blocks[i]
		if is_instance_valid(block):
			var distance = position.distance_to(block.global_position)
			print("  iron_blocks[", i, "]: ", block.global_position, " distance: ", distance)
			if distance <= tolerance and distance < closest_distance:
				closest_block = block
				closest_distance = distance
				print("    ^ NEW CLOSEST BLOCK!")
		else:
			print("  iron_blocks[", i, "]: INVALID")
					
	if closest_block:
		print("RESULT: Found closest block at distance ", closest_distance, " from ", position)
		print("        Block position: ", closest_block.global_position)
	else:
		print("RESULT: No blocks found within ", tolerance, " pixels of ", position)
	
	print("=== END BLOCK SEARCH ===")
	return closest_block
	

func _on_enemy_died_with_distortion(score_points: int, death_position: Vector2):
	"""Handle enemy death with distortion effect"""
	print("\n🔥 ENEMY DIED AT: ", death_position, " 🔥")
	create_floating_score_text(death_position, score_points, true)
	create_enemy_death_distortion(death_position)
	damage_adjacent_blocks(death_position, 10)
	_on_enemy_died(score_points)

func _on_boss_died_with_distortion(score_points: int, death_position: Vector2):
	"""Handle boss death with stronger distortion effect"""
	create_floating_score_text(death_position, score_points, true)
	create_boss_death_distortion(death_position)
	_on_enemy_died(score_points)

func _on_block_died(score_points: int):
	current_score += score_points
	enemies_killed += 1
	
	# Check win condition
	if enemies_killed >= total_enemies:
		if level_manager and level_manager.has_method("level_completed"):
			level_manager.level_completed()
		else:
			player_wins()

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

# Debug function to visualize spawn weights
func spawn_bombs_simple(count: int):
	var min_row = 0    # Top of screen
	var max_row = 3    # Only top 4 rows
	var min_col = 2    # Avoid left edge
	var max_col = 12   # Avoid right edge
	var positions = spawn_manager.get_spawn_positions_in_area(count, min_row, max_row, min_col, max_col)
	for pos in positions: spawn_enemy_at_position(pos)

func spawn_blocks_simple(count: int):
	var min_row = 1    # Skip very top
	var max_row = 6    # Middle area
	var min_col = 0    # Any column
	var max_col = 14   # Full width
	var positions = spawn_manager.get_spawn_positions_in_area(count, min_row, max_row, min_col, max_col)
	for pos in positions: spawn_enemy_kvadrat_at_position(pos)

func spawn_blue_blocks_simple(count: int):
	var min_row = 2    # Center area
	var max_row = 5    # Center area
	var min_col = 4    # Center columns
	var max_col = 10   # Center columns
	var positions = spawn_manager.get_spawn_positions_in_area(count, min_row, max_row, min_col, max_col)
	for pos in positions: spawn_blue_block_at_position(pos)

func spawn_laser_blocks_simple(count: int):
	var min_row = 0    # Very top
	var max_row = 2    # Top 3 rows only
	var min_col = 0    # Any column
	var max_col = 14   # Full width
	var positions = spawn_manager.get_spawn_positions_in_area(count, min_row, max_row, min_col, max_col)
	for pos in positions: spawn_laser_block_at_position(pos)

func spawn_iron_blocks_simple(count: int):
	var min_row = 3    # Lower middle
	var max_row = 7    # Lower middle
	var min_col = 5    # Very center
	var max_col = 9    # Very center
	var positions = spawn_manager.get_spawn_positions_in_area(count, min_row, max_row, min_col, max_col)
	for pos in positions: spawn_iron_block_at_position(pos)

func spawn_cloud_blocks_simple(count: int):
	var min_row = 1    # Upper middle
	var max_row = 4    # Upper middle
	var min_col = 3    # Wide center
	var max_col = 11   # Wide center
	var positions = spawn_manager.get_spawn_positions_in_area(count, min_row, max_row, min_col, max_col)
	for pos in positions: spawn_cloud_block_at_position(pos)

func spawn_block_droppers_simple(count: int):
	var min_row = 0    # Top area
	var max_row = 3    # Top area
	var min_col = 1    # Avoid far edges
	var max_col = 13   # Avoid far edges
	var positions = spawn_manager.get_spawn_positions_in_area(count, min_row, max_row, min_col, max_col)
	for pos in positions: spawn_enemy_block_dropper_at_position(pos)

func clear_level_entities():
	"""Clear all entities and reset spawner for new level"""
	# Clear all your existing arrays
	for enemy in enemies: if is_instance_valid(enemy): enemy.queue_free()
	for block in blocks: if is_instance_valid(block): block.queue_free()
	for block in blue_blocks: if is_instance_valid(block): block.queue_free()
	for block in lazer_blocks: if is_instance_valid(block): block.queue_free()
	for block in iron_blocks: if is_instance_valid(block): block.queue_free()
	for block in cloud_blocks: if is_instance_valid(block): block.queue_free()
	for dropper in block_droppers: if is_instance_valid(dropper): dropper.queue_free()
	for boss in bosses: if is_instance_valid(boss): boss.queue_free()
	
	# Clear arrays
	enemies.clear()
	blocks.clear()
	blue_blocks.clear()
	lazer_blocks.clear()
	iron_blocks.clear()
	cloud_blocks.clear()
	block_droppers.clear()
	bosses.clear()
	
	# Reset counters
	total_enemies = 0
	enemies_killed = 0
	
	# Clear spawner positions
	spawn_manager.clear_occupied_positions()
	
	print("Level cleared and spawner reset")

func create_floating_score_text(position: Vector2, score: int, is_kill: bool = false):
	"""Create floating score text that explodes from enemy position"""
	
	var label = Label.new()
	label.text = "+" + str(score)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Set color and size based on type
	if is_kill:
		label.add_theme_color_override("font_color", KILL_COLOR)
		label.add_theme_font_size_override("font_size", KILL_FONT_SIZE)
		label.text += "!"  # Add exclamation for kills
	else:
		label.add_theme_color_override("font_color", HURT_COLOR)
		label.add_theme_font_size_override("font_size", HURT_FONT_SIZE)
	
	# Add outline for better visibility
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	
	# Position the label
	get_tree().current_scene.add_child(label)
	label.global_position = position  # Center on enemy

	label.scale = Vector2(0.3, 0.3)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.2)
	tween.tween_property(label, "global_position", position + Vector2(0, -60), 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.7)
