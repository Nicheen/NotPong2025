extends Node

var main_scene: Node2D
var current_level: int = 1

# Level konfigurationer - här definierar vi exakt vad varje level ska ha
var level_configs = {
	1: {
		"block_red": 2,
		"block_blue": 1,
		"enemy": 1
	},
	2: {
		"block_red": 3,
		"block_blue": 2,
		"enemy": 3,
		"block_dropper": 1
	},
	3: {
		"block_red": 4,
		"block_blue": 2,
		"block_laser": 1,
		"enemy": 2,
		"block_dropper": 1
	},
	4: {
		"block_red": 5,
		"block_blue": 3,
		"block_laser": 2,
		"block_iron": 5,
		"enemy": 4,
	},
	5: {
		# Boss level
		"boss": "Boss1"
	},
	6: {
		"block_red": 5,
		"block_blue": 3,
		"block_laser": 2,
		"block_iron": 4,
		"enemy": 3,
		"block_dropper_fireball": 1
	},
	7: {
		"block_red": 30,
		"block_blue": 12,
		"enemy": 20,
	},
	8: {
		"block_red": 8,
		"block_blue": 4,
		"block_cloud": 1,
		"enemy": 2,
		"block_dropper": 1,
		"block_dropper_fireball": 1
	},
	9: {
		"block_red": 20,
		"block_blue": 10,
		"block_laser": 2,
		"block_cloud": 5,
	},
	10: {
		# Boss level
		"boss": "Boss_Thunder"
	}
}

func start_level(level: int):
	current_level = level
	print("Starting level: ", level)
	
	# Uppdatera UI när nivå startar
	if main_scene and main_scene.has_method("update_ui"):
		main_scene.update_ui()
	
	# Rensa tidigare enemies/blocks
	clear_level()
	
	# Spawna level baserat på konfiguration
	spawn_level(level)

func clear_level():
	"""Clear level using the main scene's improved clear function"""
	main_scene.clear_level_entities()

func spawn_level(level: int):
	"""Spawna en level baserat på dess konfiguration"""
	if not level_configs.has(level):
		print("ERROR: No configuration found for level ", level)
		return
	
	var config = level_configs[level]
	
	# Kolla om det är en boss level
	if config.has("boss"):
		spawn_boss_level(level, config["boss"])
		return
	
	# Spawna vanlig level
	spawn_normal_level(level, config)

func spawn_normal_level(level: int, config: Dictionary):
	"""Spawna en vanlig level med given konfiguration"""
	print("Spawning level ", level, " with config: ", config)
	
	# Spawna varje typ av entity baserat på konfigurationen
	for entity_type in config.keys():
		var count = config[entity_type]
		spawn_entity_type(entity_type, count)
	
	# Skriv ut vad som spawnades
	print_level_summary(level, config)

func spawn_entity_type(entity_type: String, count: int):
	"""Spawna en specifik typ av entity"""
	match entity_type:
		"block_red":
			main_scene.spawn_blocks_simple(count)
		"block_blue":
			main_scene.spawn_blue_blocks_simple(count)
		"block_laser":
			main_scene.spawn_laser_blocks_simple(count)
		"block_iron":
			main_scene.spawn_iron_blocks_simple(count)
		"block_cloud":
			main_scene.spawn_cloud_blocks_simple(count)
		"block_dropper":
			main_scene.spawn_block_droppers_simple(count)
		"block_dropper_fireball":
			main_scene.spawn_block_droppers_fireball_simple(count)
		"enemy":
			main_scene.spawn_bombs_simple(count)
		_:
			print("WARNING: Unknown entity type: ", entity_type)

func spawn_boss_level(level: int, boss_type: String):
	"""Spawna en boss level"""
	print("BOSS LEVEL ", level, "! Spawning: ", boss_type)
	
	match boss_type:
		"Boss1":
			spawn_single_boss(main_scene.BOSS_SCENE, "Boss1", level, Vector2(576, 280))
		"Boss_Thunder":
			# Spawna 3 thunder bosses
			var center_pos = Vector2(576, 280)
			var left_pos = Vector2(576 - 150, 280)
			var right_pos = Vector2(576 + 150, 280)
			
			spawn_single_boss(main_scene.BOSS_THUNDER_SCENE, "Boss_Thunder_Center", level, center_pos)
			spawn_single_boss(main_scene.BOSS_THUNDER_SCENE, "Boss_Thunder_Left", level, left_pos)
			spawn_single_boss(main_scene.BOSS_THUNDER_SCENE, "Boss_Thunder_Right", level, right_pos)
		_:
			print("ERROR: Unknown boss type: ", boss_type)

func spawn_single_boss(boss_scene_path: String, boss_name: String, level: int, position: Vector2):
	"""Spawna en enda boss på specifik position"""
	var boss_scene = load(boss_scene_path)
	if not boss_scene:
		print("ERROR: Could not load boss scene: ", boss_scene_path)
		return
	
	var boss = boss_scene.instantiate()
	boss.global_position = position
	
	# Skala boss health för högre levels
	var boss_health_multiplier = 1.0 + (level - 5) * 0.2
	if boss.has_method("set_health_multiplier"):
		boss.set_health_multiplier(boss_health_multiplier)
	
	# Connecta boss signals med distortion effects
	var boss_position = boss.global_position
	
	if boss.has_signal("boss_died"):
		boss.boss_died.connect(func(score_points): main_scene._on_boss_died_with_distortion(score_points, boss_position))
	elif boss.has_signal("block_destroyed"):
		boss.block_destroyed.connect(func(score_points): main_scene._on_boss_died_with_distortion(score_points, boss_position))
	
	if boss.has_signal("boss_hit"):
		boss.boss_hit.connect(main_scene._on_enemy_hit)
	elif boss.has_signal("block_hit"):
		boss.block_hit.connect(main_scene._on_enemy_hit)
	
	main_scene.add_child(boss)
	main_scene.bosses.append(boss)
	main_scene.total_enemies += 1
	
	# Reservera boss position
	var boss_positions: Array[Vector2] = [boss_position]
	main_scene.spawn_manager.reserve_positions(boss_positions)
	
	print(boss_name, " spawned at ", position, " with health multiplier: ", boss_health_multiplier)

func print_level_summary(level: int, config: Dictionary):
	"""Skriv ut en sammanfattning av vad som spawnades"""
	print("Level ", level, " spawned successfully:")
	
	for entity_type in config.keys():
		var count = config[entity_type]
		print("  - ", count, " ", entity_type.replace("_", " "))

func is_boss_level(level: int) -> bool:
	"""Kolla om en level är en boss level"""
	if not level_configs.has(level):
		return false
	
	return level_configs[level].has("boss")

func level_completed():
	"""Hantera när en level är klar"""
	if is_boss_level(current_level):
		print("BOSS LEVEL ", current_level, " COMPLETED!")
		await get_tree().create_timer(2.0).timeout
	else:
		print("Level ", current_level, " completed!")
		await get_tree().create_timer(1.0).timeout
	
	current_level += 1
	
	# Uppdatera UI omedelbart efter level ökning
	if main_scene and main_scene.has_method("update_ui"):
		main_scene.update_ui()
	
	# Starta nästa level om den finns
	if level_configs.has(current_level):
		start_level(current_level)
	else:
		print("All levels completed! Player wins!")
		main_scene.player_wins()

func get_level_config(level: int) -> Dictionary:
	"""Få konfigurationen för en specifik level"""
	if level_configs.has(level):
		return level_configs[level]
	else:
		return {}

func add_level_config(level: int, config: Dictionary):
	"""Lägg till en ny level konfiguration"""
	level_configs[level] = config
	print("Added configuration for level ", level, ": ", config)

func modify_level_config(level: int, entity_type: String, count: int):
	"""Modifiera en specifik entity i en level konfiguration"""
	if not level_configs.has(level):
		level_configs[level] = {}
	
	level_configs[level][entity_type] = count
	print("Modified level ", level, ": ", entity_type, " = ", count)
