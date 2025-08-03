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
	var is_boss = level % 5 == 0  # Var femte level (5, 10, 15, etc.)
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
	
	# Add some supporting blocks using weighted positioning
	#var support_blocks = 3 + (level / 10)
	#var support_enemies = 2 + (level / 10)
	
	#main_scene.spawn_blocks_weighted(support_blocks)
	#main_scene.spawn_enemies_weighted(support_enemies)
	
	# Maybe add a few special blocks for boss levels
	#if level >= 10:
		#main_scene.spawn_blue_blocks_weighted(2)
	#if level >= 20:
		#main_scene.spawn_laser_blocks_weighted(1)
		
func spawn_normal_level(level: int):
	"""Spawn a normal level using weighted positioning"""
	# Calculate entity counts based on level
	var base_blocks = 8
	var base_enemies = 3
	var base_block_dropper = 1
	var base_lazer = 1
	var base_thunder = 0
	var base_blue_blocks = 2
	
	# Increase difficulty each level
	var blocks_count = base_blocks + (level - 1) * 3
	var enemies_count = base_enemies + (level - 1) * 1
	var block_dropper_count = base_block_dropper + (level - 1) / 3
	var lazer_count = base_lazer + (level - 1) / 3
	var thunder_count = base_thunder + (level - 1) / 3
	var blue_blocks_count = base_blue_blocks + (level - 1) / 2
	
	# Apply maximum limits
	blocks_count = min(blocks_count, 20)
	enemies_count = min(enemies_count, 10)
	block_dropper_count = min(block_dropper_count, 5)
	lazer_count = min(lazer_count, 5)
	thunder_count = min(thunder_count, 1)
	blue_blocks_count = min(blue_blocks_count, 8)
	
	# SPAWN IN STRATEGIC ORDER (blocks first, then special blocks, enemies last)
	
	# 1. Spawn regular blocks first (they form the base defense)
	main_scene.spawn_blocks_weighted(blocks_count)
	
	# 2. Spawn special blocks in strategic positions
	main_scene.spawn_laser_blocks_weighted(lazer_count)
	main_scene.spawn_thunder_blocks_weighted(thunder_count)
	main_scene.spawn_blue_blocks_weighted(blue_blocks_count)
	main_scene.spawn_block_droppers_weighted(block_dropper_count)
	
	# 3. Spawn enemies last (they avoid block positions)
	main_scene.spawn_enemies_weighted(enemies_count)
	
	print("Level ", level, " spawned with weighted positioning:")
	print("  - ", blocks_count, " regular blocks")
	print("  - ", blue_blocks_count, " blue blocks") 
	print("  - ", lazer_count, " laser blocks")
	print("  - ", thunder_count, " thunder blocks")
	print("  - ", block_dropper_count, " block droppers")
	print("  - ", enemies_count, " enemies")
	
	# Optional: Debug spawn weights for this level
	if level <= 2:  # Only show for first few levels
		main_scene.debug_spawn_weights()
		
func spawn_boss(level: int):
	"""Spawn boss at center position"""
	var boss_scene = load(main_scene.BOSS_SCENE)
	if not boss_scene:
		print("ERROR: Could not load boss scene")
		return
	
	var boss = boss_scene.instantiate()
	
	# Place boss in center of play area
	boss.global_position = Vector2(576, 280)
	
	# Scale boss health for higher levels
	var boss_health_multiplier = level / 10
	if boss.has_method("set_health_multiplier"):
		boss.set_health_multiplier(boss_health_multiplier)
	
	# Connect boss signals WITH distortion effects
	var boss_position = boss.global_position
	boss.boss_died.connect(func(score_points): main_scene._on_boss_died_with_distortion(score_points, boss_position))
	boss.boss_hit.connect(main_scene._on_enemy_hit)
	
	main_scene.add_child(boss)
	main_scene.bosses.append(boss)
	main_scene.total_enemies += 1
	
	# FIX: Skapa en korrekt typed Array[Vector2] för boss position
	var boss_positions: Array[Vector2] = [boss_position]
	main_scene.spawn_manager.reserve_positions(boss_positions)
	
	print("Boss spawned for level ", level, " with health multiplier: ", boss_health_multiplier)
	
func _on_boss_died(score_points: int):
	# Boss ger mycket mer poäng
	var boss_bonus = current_level * 100  # Extra bonus baserat på level
	main_scene._on_enemy_died(score_points + boss_bonus)
	
	print("BOSS DEFEATED! Bonus points: ", boss_bonus)

func level_completed():
	if is_boss_level(current_level):
		print("BOSS LEVEL ", current_level, " COMPLETED!")
		await get_tree().create_timer(3.0).timeout
	else:
		print("Level ", current_level, " completed!")
		await get_tree().create_timer(2.0).timeout
	
	current_level += 1
	
	# FIX: Uppdatera UI omedelbart efter level ökning
	if main_scene and main_scene.has_method("update_ui"):
		main_scene.update_ui()
	
	start_level(current_level)
