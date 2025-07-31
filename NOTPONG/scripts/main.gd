class_name GamePlay extends Node2D

const gameover_scene:PackedScene = preload("res://scenes/menus/game_over.tscn")
const pausemenu_scene:PackedScene = preload("res://scenes/menus/pause_menu.tscn")

# Game settings
@export var play_area_size: Vector2 = Vector2(1152, 648)  # Match your window size
@export var play_area_center: Vector2 = Vector2(576, 324)  # Half of window size
@onready var hud: HUD = %HUD as HUD

# Hardcoded scene paths
const PLAYER_SCENE = "res://scenes/obj/Player.tscn"
const ENEMY_SCENE = "res://scenes/obj/Enemy.tscn"
const ENEMY_BLOCK_SCENE = "res://scenes/obj/blocks/block.tscn"
const ENEMY_BLOCK_BLUE_SCENE = "res://scenes/obj/blocks/block_blue.tscn"
const ENEMY_BLOCK_LASER_SCENE = "res://scenes/obj/blocks/block_laser.tscn"
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
var enemies: Array[CharacterBody2D] = []
var blocks: Array[CharacterBody2D] = []
var blue_blocks: Array[CharacterBody2D] = []
var lazer_blocks: Array[CharacterBody2D] = []
var block_droppers: Array[CharacterBody2D] = []
var bosses: Array[CharacterBody2D] = []
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
	add_child(level_manager)
	level_manager.set_script(load("res://scripts/level_manager.gd"))
	
	# Give level manager access to main scene
	level_manager.main_scene = self

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

# ... (keep all your existing spawn functions unchanged)

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

func spawn_enemy_at_position(position: Vector2):
	var enemy_scene = load(ENEMY_SCENE)
	if not enemy_scene:
		print("ERROR: Could not load enemy scene at: ", ENEMY_SCENE)
		return
	
	var enemy = enemy_scene.instantiate()
	enemy.global_position = position
	
	# Connect enemy signals with distortion effects - pass position in closure
	enemy.enemy_died.connect(func(score_points): _on_enemy_died_with_distortion(score_points, position))
	enemy.enemy_hit.connect(_on_enemy_hit)
	
	add_child(enemy)
	enemies.append(enemy)
	total_enemies += 1
	
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
	# Returnera random urval av spawn-positioner
	var available_positions = all_spawn_positions.duplicate()
	available_positions.shuffle()
	
	var selected_count = min(count, available_positions.size())
	return available_positions.slice(0, selected_count)

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
	
	# Connect signals WITHOUT distortion effects for blocks
	block.block_died.connect(_on_block_died)
	block.block_hit.connect(_on_enemy_hit)
	
	add_child(block)
	blue_blocks.append(block)
	total_enemies += 1
	
	print("Spawned blue block at: ", position)

func spawn_random_enemies(count: int):
	# Förenklad version
	var selected_positions = get_random_spawn_positions(count)
	
	for pos in selected_positions:
		spawn_enemy_kvadrat_at_position(pos)

# Exempel: Spawna bossar på specifika positioner
func spawn_boss_at_center():
	# Hitta center-positioner
	var center_positions = all_spawn_positions.filter(func(pos): return pos.y == 324)
	var boss_pos = center_positions[center_positions.size() / 2]  # Mitten av center-raden
	
	# Spawna boss här...
	print("Spawning boss at: ", boss_pos)

func spawn_enemy_block_dropper_at_position(position: Vector2):
	var block_scene = load(ENEMY_BLOCK_DROPPER_SCENE)  # Ladda kvadrat-scenen
	if not block_scene:
		print("ERROR: Could not load enemy kvadrat scene at: ", ENEMY_BLOCK_DROPPER_SCENE)
		return
	
	var block = block_scene.instantiate()
	block.global_position = position
	
	# Connect signals WITHOUT distortion effects for blocks
	block.block_dropper_died.connect(_on_block_died)
	block.block_dropper_hit.connect(_on_enemy_hit)
	
	add_child(block)
	blocks.append(block)
	total_enemies += 1
	
	print("Spawned kvadrat enemy at: ", position)

func spawn_blue_blocks(count: int):
	var selected_positions = get_random_spawn_positions(count)
	
	for pos in selected_positions:
		spawn_blue_block_at_position(pos)
		
func spawn_enemy_kvadrat_at_position(position: Vector2):
	var block_scene = load(ENEMY_BLOCK_SCENE)  # Ladda kvadrat-scenen
	if not block_scene:
		print("ERROR: Could not load enemy kvadrat scene at: ", ENEMY_BLOCK_SCENE)
		return
	
	var block = block_scene.instantiate()
	block.global_position = position
	
	# Connect signals WITHOUT distortion effects for blocks
	block.block_died.connect(_on_block_died)
	block.block_hit.connect(_on_enemy_hit)
	
	add_child(block)
	blocks.append(block)
	total_enemies += 1
	
	print("Spawned kvadrat enemy at: ", position)
	
	# Lägg till spawn-funktioner:
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
	var thunder_scene = load(THUNDER)
	if not lazer_scene:
		print("ERROR: Could not load enemy lazer scene at: ", ENEMY_BLOCK_LASER_SCENE)
		return
		
	if not thunder_scene:
		print("ERROR: Could not load thunder effect scene at: ", THUNDER)
		return
		
	var lazer_block = lazer_scene.instantiate()

	lazer_block.global_position = position
	
	# Connect signals WITHOUT distortion effects for laser blocks
	lazer_block.block_died.connect(_on_block_died)
	lazer_block.block_hit.connect(_on_enemy_hit)
	
	add_child(lazer_block)

	lazer_blocks.append(lazer_block)
	total_enemies += 1
	
	print("Spawned lazer block at: ", position)
	
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

# Updated functions with separate handling for enemies vs blocks
func _on_enemy_died(score_points: int):
	enemies_killed += 1
	current_score += score_points
	
	print("Enemy killed! Score: ", current_score, " Enemies remaining: ", (total_enemies - enemies_killed))
	
	# Update UI (this will also check for high score updates in real-time)
	update_ui()
	
	# Check win condition
	if enemies_killed >= total_enemies:
		if level_manager and level_manager.has_method("level_completed"):
			current_level += 1
			level_manager.level_completed()
		else:
			player_wins()  # Fallback

func _on_enemy_died_with_distortion(score_points: int, death_position: Vector2):
	"""Handle enemy death with distortion effect"""
	create_enemy_death_distortion(death_position)
	_on_enemy_died(score_points)

func _on_boss_died_with_distortion(score_points: int, death_position: Vector2):
	"""Handle boss death with stronger distortion effect"""
	create_boss_death_distortion(death_position)
	_on_enemy_died(score_points)

func _on_block_died(score_points: int):
	"""Handle block death WITHOUT distortion effect"""
	_on_enemy_died(score_points)
		
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
	hud.update_level(current_level)
	hud.update_score(current_score)
	
	# Check for high score updates in real-time and update HUD
	if current_score > Global.save_data.high_score:
		check_and_update_high_score()

func create_grid_background():
	# You can keep the original grid background if you want
	# It won't have distortion anymore, but will provide the grid visual
	pass
