extends Node

var main_scene: Node2D
var current_level: int = 1

func start_level(level: int):
	current_level = level
	print("Starting level: ", level)
	
	# FIX: Uppdatera UI när nivå startar
	if main_scene and main_scene.has_method("update_ui"):
		main_scene.update_ui()
	
	# Rensa tidigare enemies/blocks
	clear_level()
	
	# Kolla om det är boss-level
	if is_boss_level(level):
		spawn_boss_level(level)
	else:
		spawn_normal_level(level)

func is_boss_level(level: int) -> bool:
	# Only level 5 and 10 are boss levels
	var is_boss = (level == 10 or level == 5)
	print("Level ", level, " is boss level: ", is_boss)
	return is_boss

func clear_level():
	"""Clear level using the main scene's improved clear function"""
	main_scene.clear_level_entities()
	
func spawn_boss_level(level: int):
	"""Spawn a boss level with supporting entities"""
	print("BOSS LEVEL ", level, "!")
	
	# Spawn boss first
	spawn_boss(level)
		
func spawn_normal_level(level: int):
	"""Spawn a normal level using weighted positioning"""
	# Calculate entity counts based on level
	var base_blocks = 7
	var base_enemies = 3
	var base_block_dropper = 1
	var base_lazer = 1
	var base_blue_blocks = 2
	var base_iron_blocks = 1
	var base_cloud_blocks = 1
	
	# Increase difficulty each level
	var blocks_count = base_blocks + (level - 1) * 3
	var enemies_count = base_enemies + (level - 1) * 1
	var block_dropper_count = base_block_dropper + (level - 1) / 3
	var lazer_count = base_lazer + (level - 1) / 3
	var blue_blocks_count = base_blue_blocks + (level - 1) / 2
	var iron_blocks_count = base_iron_blocks + max(0, (level - 3) / 2)
	var cloud_blocks_count = base_cloud_blocks + max(0, (level - 3) / 2)
	
	# Apply maximum limits
	blocks_count = min(blocks_count, 20)
	enemies_count = min(enemies_count, 10)
	block_dropper_count = min(block_dropper_count, 5)
	lazer_count = min(lazer_count, 5)
	blue_blocks_count = min(blue_blocks_count, 8)
	iron_blocks_count = min(iron_blocks_count, 6)
	cloud_blocks_count = min(cloud_blocks_count, 6)
	
	# SPAWN IN STRATEGIC ORDER (blocks first, then special blocks, enemies last)
	
	# 1. Spawn regular blocks first (they form the base defense)
	main_scene.spawn_blocks_weighted(blocks_count)
	
	# 2. Spawn special blocks in strategic positions
	main_scene.spawn_laser_blocks_weighted(lazer_count)
	main_scene.spawn_blue_blocks_weighted(blue_blocks_count)
	main_scene.spawn_iron_blocks_weighted(iron_blocks_count)
	main_scene.spawn_block_droppers_weighted(block_dropper_count)
	main_scene.spawn_cloud_blocks_weighted(cloud_blocks_count)
	
	# 3. Spawn enemies last (they avoid block positions)
	main_scene.spawn_enemies_weighted(enemies_count)
	
	print("Level ", level, " spawned with weighted positioning:")
	print("  - ", blocks_count, " regular blocks")
	print("  - ", blue_blocks_count, " blue blocks") 
	print("  - ", iron_blocks_count, " iron blocks")
	print("  - ", lazer_count, " laser blocks")
	print("  - ", cloud_blocks_count, " cloud blocks")
	print("  - ", block_dropper_count, " block droppers")
	print("  - ", enemies_count, " enemies")
		
func spawn_boss(level: int):
	"""Spawn the correct boss based on level"""
	var boss_scene_path: String
	var boss_name: String
	
	# Choose which boss to spawn
	if level == 10:
		boss_scene_path = main_scene.BOSS_SCENE  # Boss1
		boss_name = "Boss1"
		spawn_single_boss(boss_scene_path, boss_name, level, Vector2(576, 280))
	elif level == 5:
		boss_scene_path = main_scene.BOSS_THUNDER_SCENE  # Boss_Thunder  
		boss_name = "Boss_Thunder"
		# Spawn 3 thunder bosses: center, left, right
		var center_pos = Vector2(576, 280)
		var left_pos = Vector2(576 - 150, 280)
		var right_pos = Vector2(576 + 150, 280)
		
		spawn_single_boss(boss_scene_path, boss_name + "_Center", level, center_pos)
		spawn_single_boss(boss_scene_path, boss_name + "_Left", level, left_pos)
		spawn_single_boss(boss_scene_path, boss_name + "_Right", level, right_pos)
	else:
		print("ERROR: No boss defined for level ", level)
		return

func spawn_single_boss(boss_scene_path: String, boss_name: String, level: int, position: Vector2):
	"""Spawn a single boss at the specified position"""
	# Load and spawn the boss
	var boss_scene = load(boss_scene_path)
	if not boss_scene:
		print("ERROR: Could not load boss scene: ", boss_scene_path)
		return
	
	var boss = boss_scene.instantiate()
	
	# Place boss at specified position
	boss.global_position = position
	
	# Scale boss health for higher levels (optional)
	var boss_health_multiplier = 1.0 + (level - 5) * 0.2
	if boss.has_method("set_health_multiplier"):
		boss.set_health_multiplier(boss_health_multiplier)
	
	# Connect boss signals WITH distortion effects
	var boss_position = boss.global_position
	
	# Connect the appropriate signals based on boss type
	if boss.has_signal("boss_died"):
		boss.boss_died.connect(func(score_points): main_scene._on_boss_died_with_distortion(score_points, boss_position))
	elif boss.has_signal("block_destroyed"):
		# For Boss_Thunder which uses block_destroyed signal
		boss.block_destroyed.connect(func(score_points): main_scene._on_boss_died_with_distortion(score_points, boss_position))
	
	if boss.has_signal("boss_hit"):
		boss.boss_hit.connect(main_scene._on_enemy_hit)
	elif boss.has_signal("block_hit"):
		boss.block_hit.connect(main_scene._on_enemy_hit)
	
	main_scene.add_child(boss)
	main_scene.bosses.append(boss)
	main_scene.total_enemies += 1
	
	# Reserve boss position
	var boss_positions: Array[Vector2] = [boss_position]
	main_scene.spawn_manager.reserve_positions(boss_positions)
	
	print(boss_name, " spawned for level ", level, " at position ", position, " with health multiplier: ", boss_health_multiplier)
	
func _on_boss_died(score_points: int):
	# Boss ger mycket mer poäng
	var boss_bonus = current_level * 100  # Extra bonus baserat på level
	main_scene._on_enemy_died(score_points + boss_bonus)
	
	print("BOSS DEFEATED! Bonus points: ", boss_bonus)

func level_completed():
	if is_boss_level(current_level):
		print("BOSS LEVEL ", current_level, " COMPLETED!")
		await get_tree().create_timer(2.0).timeout
	else:
		print("Level ", current_level, " completed!")
		await get_tree().create_timer(1.0).timeout
	
	current_level += 1
	
	# FIX: Uppdatera UI omedelbart efter level ökning
	if main_scene and main_scene.has_method("update_ui"):
		main_scene.update_ui()
	
	start_level(current_level)
