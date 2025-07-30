extends Node

var main_scene: Node2D
var current_level: int = 1

func start_level(level: int):
	current_level = level
	print("Starting level: ", level)
	
	# Rensa tidigare enemies/blocks
	clear_level()
	
	# Kolla om det är boss-level
	if is_boss_level(level):
		spawn_boss_level(level)
	else:
		spawn_normal_level(level)


func is_boss_level(level: int) -> bool:
	return level % 5 == 0  # Var tionde level (10, 20, 30, etc.)

func clear_level():
	# Ta bort alla befintliga enemies, blocks och bossar
	for enemy in main_scene.enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	for block in main_scene.blocks:
		if is_instance_valid(block):
			block.queue_free()
	
	for lazer_block in main_scene.lazer_blocks:
		if is_instance_valid(lazer_block):
			lazer_block.queue_free()
			
	for block_dropper in main_scene.block_droppers:
		if is_instance_valid(block_dropper):
			block_dropper.queue_free()
	
	for boss in main_scene.bosses:
		if is_instance_valid(boss):
			boss.queue_free()
	
	# Rensa arrays
	main_scene.enemies.clear()
	main_scene.blocks.clear()
	main_scene.lazer_blocks.clear()
	main_scene.block_droppers.clear()
	main_scene.bosses.clear()
	
	# Återställ räknare
	main_scene.enemies_killed = 0
	main_scene.total_enemies = 0

func spawn_boss_level(level: int):
	print("BOSS LEVEL ", level, "!")
	
	# Spawna boss
	spawn_boss(level)
	
	# Spawna några vanliga enemies också för att göra det svårare
	#var support_enemies = 3 + (level / 10)  # Fler support enemies för högre boss levels
	#spawn_enemies_for_level(support_enemies)

func spawn_normal_level(level: int):
	# Beräkna antal enemies baserat på level
	var base_blocks = 8
	var base_enemies = 3
	var base_block_dropper = 1
	var base_lazer = 1
	
	# Öka svårighetsgrad varje level
	var blocks_count = base_blocks + (level - 1) * 3  # +3 block per level
	var enemies_count = base_enemies + (level - 1) * 1  # +1 enemy per level  
	var block_dropper_count = base_block_dropper + (level - 1) / 3
	var lazer_count = base_lazer + (level - 1) / 3  # +1 lazer var 3:e level
	
	
	# Max gränser
	blocks_count = min(blocks_count, 20)
	enemies_count = min(enemies_count, 10)
	block_dropper_count = min(base_block_dropper, 5)
	lazer_count = min(lazer_count, 5)
	
	
	# Spawna innehåll
	spawn_blocks_for_level(blocks_count)
	spawn_lazer_for_level(lazer_count)  
	spawn_block_dropper_for_level(block_dropper_count)
	spawn_enemies_for_level(enemies_count)
	
	print("Level ", level, " spawned: ", blocks_count, " blocks, ", enemies_count, " enemies, ", lazer_count, " lazer", block_dropper_count, " dropper")

func spawn_boss(level: int):
	var boss_scene = load(main_scene.BOSS_SCENE)
	if not boss_scene:
		print("ERROR: Could not load boss scene")
		return
	
	var boss = boss_scene.instantiate()
	
	# Placera boss i mitten av spelområdet
	boss.global_position = Vector2(576, 200)  # Adjust based on your play area
	
	# Gör boss starkare för högre levels
	var boss_health_multiplier = level / 10
	if boss.has_method("set_health_multiplier"):
		boss.set_health_multiplier(boss_health_multiplier)
	
	# Connect boss signals
	boss.boss_died.connect(_on_boss_died)
	boss.boss_hit.connect(main_scene._on_enemy_hit)
	
	main_scene.add_child(boss)
	main_scene.bosses.append(boss)
	main_scene.total_enemies += 1
	
	print("Boss spawned for level ", level, " with health multiplier: ", boss_health_multiplier)

func _on_boss_died(score_points: int):
	# Boss ger mycket mer poäng
	var boss_bonus = current_level * 100  # Extra bonus baserat på level
	main_scene._on_enemy_died(score_points + boss_bonus)
	
	print("BOSS DEFEATED! Bonus points: ", boss_bonus)

func spawn_blocks_for_level(count: int):
	var selected_positions = main_scene.get_random_spawn_positions(count)
	for pos in selected_positions:
		main_scene.spawn_enemy_kvadrat_at_position(pos)

func spawn_lazer_for_level(count: int):
	# Hitta lediga positioner
	var used_positions: Array[Vector2] = []
	for block in main_scene.blocks:
		used_positions.append(block.global_position)
	
	var available_positions = main_scene.all_spawn_positions.filter(
		func(pos): return not pos in used_positions
	)
	
	available_positions.shuffle()
	var spawn_count = min(count, available_positions.size())
	
	for i in range(spawn_count):
		main_scene.spawn_enemy_lazer_at_position(available_positions[i])
		
func spawn_block_dropper_for_level(count: int):
	var selected_positions = main_scene.get_random_spawn_positions(count)
	for pos in selected_positions:
		main_scene.spawn_enemy_block_dropper_at_position(pos)

func spawn_enemies_for_level(count: int):
	# Samma logik som din befintliga spawn_enemies men med count parameter
	var used_positions: Array[Vector2] = []
	for block in main_scene.blocks:
		used_positions.append(block.global_position)
	for lazer_block in main_scene.lazer_blocks:
		used_positions.append(lazer_block.global_position)
	for block_dropper in main_scene.block_droppers:
		used_positions.append(block_dropper.global_position)
	for boss in main_scene.bosses:
		used_positions.append(boss.global_position)
	
	var available_positions = main_scene.all_spawn_positions.filter(
		func(pos): return not pos in used_positions
	)
	
	available_positions.shuffle()
	var spawn_count = min(count, available_positions.size())
	
	for i in range(spawn_count):
		main_scene.spawn_enemy_at_position(available_positions[i])

func level_completed():
	if is_boss_level(current_level):
		print("BOSS LEVEL ", current_level, " COMPLETED!")
		# Längre paus efter boss
		await get_tree().create_timer(3.0).timeout
	else:
		print("Level ", current_level, " completed!")
		await get_tree().create_timer(2.0).timeout
	
	current_level += 1
	start_level(current_level)
