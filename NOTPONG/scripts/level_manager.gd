extends Node

var main_scene: Node2D
var current_level: int = 1

# Grid koordinater (från spawn manager)
var x_positions = [926, 876, 826, 776, 726, 676, 626, 576, 526, 476, 426, 376, 326, 276, 226]
var y_positions = [124, 174, 224, 274, 324, 374, 424, 474, 524]

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
		# Level 4 - Test för alla entity typer i rader
		"precise_spawning": true,
		"entities": {
			
			"block_iron": [
				{"x": 0, "y": 0, "rotation": 180}, {"x": 1, "y": 0, "rotation": 270}, {"x": 2, "y": 0, "rotation": 180}, {"x": 3, "y": 0, "rotation": 270}, {"x": 4, "y": 0, "rotation": 180},
				{"x": 5, "y": 0, "rotation": 270}, {"x": 6, "y": 0, "rotation": 180}, {"x": 8, "y": 0, "rotation": 270}, {"x": 9, "y": 0, "rotation": 180},
				{"x": 10, "y": 0, "rotation": 270}, {"x": 11, "y": 0, "rotation": 180}, {"x": 12, "y": 0, "rotation": 270}, {"x": 13, "y": 0, "rotation": 180}, {"x": 14, "y": 0, "rotation": 270},
				
				{"x": 3, "y": 5, "rotation": 270}, {"x": 2, "y": 5, "rotation": 180}, {"x": 11,"y": 5, "rotation": 180}, {"x": 12,"y": 5, "rotation": 270},
				
				{"x": 4, "y": 4, "rotation": 270}, {"x": 1, "y": 4, "rotation": 180}, {"x": 10,"y": 4, "rotation": 180}, {"x": 13,"y": 4, "rotation": 270},
			],
			"block_laser": [
				{"x": 7, "y": 0},  
			],
			"block_red": [
				{"x": 3, "y": 4}, {"x": 2, "y": 4}, {"x": 11,"y": 4}, {"x": 12,"y": 4},
			]
			
		}
	},
	5: {
		# Boss level
		"boss": "Boss1"
	},
	6: {
		"block_red": 5,
		"block_blue": 3,
		"block_laser": 3,
		"block_iron": 8,
		"enemy": 3,
	},
	7: {
		"block_red": 30,
		"block_blue": 12,
		"enemy": 20,
		"block_iron": 5,
	},
	8: {
		"block_red": 10,
		"block_blue": 4,
		"block_cloud": 2,
		"enemy": 2,
		"block_dropper": 1,
	},
	9: {
		# Level 9 - Specifika positioner med avancerat mönster
		"precise_spawning": true,
		"entities": {
			"block_cloud": [
				{"x": 2, "y": 0}, {"x": 4, "y": 0}, {"x": 6, "y": 0}, {"x": 8, "y": 0}, {"x": 10, "y": 0}, {"x": 12, "y": 0}
			],
			"block_blue": [
				{"x": 2, "y": 1}, {"x": 4, "y": 1}, {"x": 6, "y": 1}, {"x": 8, "y": 1}, {"x": 10, "y": 1}, {"x": 12, "y": 1},  # Rad 2: Blå
				{"x": 2, "y": 3}, {"x": 4, "y": 3}, {"x": 6, "y": 3}, {"x": 8, "y": 3}, {"x": 10, "y": 3}, {"x": 12, "y": 3},  # Rad 4: Blå
				{"x": 2, "y": 5}, {"x": 4, "y": 5}, {"x": 6, "y": 5}, {"x": 8, "y": 5}, {"x": 10, "y": 5}, {"x": 12, "y": 5},  # Rad 6: Blå
				{"x": 2, "y": 7}, {"x": 4, "y": 7}, {"x": 6, "y": 7}, {"x": 8, "y": 7}, {"x": 10, "y": 7}, {"x": 12, "y": 7}   # Rad 8: Blå
			],
			"block_red": [
				{"x": 2, "y": 2}, {"x": 4, "y": 2}, {"x": 6, "y": 2}, {"x": 8, "y": 2}, {"x": 10, "y": 2}, {"x": 12, "y": 2},  # Rad 3: Röd
				{"x": 2, "y": 4}, {"x": 4, "y": 4}, {"x": 6, "y": 4}, {"x": 8, "y": 4}, {"x": 10, "y": 4}, {"x": 12, "y": 4},  # Rad 5: Röd
				{"x": 2, "y": 6}, {"x": 4, "y": 6}, {"x": 6, "y": 6}, {"x": 8, "y": 6}, {"x": 10, "y": 6}, {"x": 12, "y": 6},  # Rad 7: Röd
				{"x": 2, "y": 8}, {"x": 4, "y": 8}, {"x": 6, "y": 8}, {"x": 8, "y": 8}, {"x": 10, "y": 8}, {"x": 12, "y": 8},  # Rad 9: Röd
				# Röda block mellan blå block (på blå rader)
				{"x": 3, "y": 1}, {"x": 5, "y": 1}, {"x": 7, "y": 1}, {"x": 9, "y": 1}, {"x": 11, "y": 1},  # Mellan blå på rad 2
				{"x": 3, "y": 3}, {"x": 5, "y": 3}, {"x": 7, "y": 3}, {"x": 9, "y": 3}, {"x": 11, "y": 3},  # Mellan blå på rad 4
				{"x": 3, "y": 5}, {"x": 5, "y": 5}, {"x": 7, "y": 5}, {"x": 9, "y": 5}, {"x": 11, "y": 5},  # Mellan blå på rad 6
				{"x": 3, "y": 7}, {"x": 5, "y": 7}, {"x": 7, "y": 7}, {"x": 9, "y": 7}, {"x": 11, "y": 7},  # Mellan blå på rad 8
				# Röda block på yttersidorna av de blå raderna
				{"x": 1, "y": 1}, {"x": 13, "y": 1},  # Yttersidor på rad 2
				{"x": 1, "y": 3}, {"x": 13, "y": 3},  # Yttersidor på rad 4
				{"x": 1, "y": 5}, {"x": 13, "y": 5},  # Yttersidor på rad 6
				{"x": 1, "y": 7}, {"x": 13, "y": 7}   # Yttersidor på rad 8
			],
			
		}
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
	
	# Kolla om det är precision spawning
	if config.has("precise_spawning") and config["precise_spawning"]:
		spawn_precise_level(level, config)
	else:
		spawn_normal_level(level, config)

func spawn_normal_level(level: int, config: Dictionary):
	"""Spawna en vanlig level med random/weighted positioning"""
	print("Spawning level ", level, " with random positioning and config: ", config)
	
	# Spawna varje typ av entity baserat på konfigurationen
	for entity_type in config.keys():
		var count = config[entity_type]
		spawn_entity_type(entity_type, count)
	
	# Skriv ut vad som spawnades
	print_level_summary(level, config)

func spawn_precise_level(level: int, config: Dictionary):
	"""Spawna en level med exakta positioner"""
	print("Spawning level ", level, " with PRECISE positioning!")
	
	if not config.has("entities"):
		print("ERROR: Precise level missing 'entities' key!")
		return
	
	var entities = config["entities"]
	
	# Spawna varje entity typ på sina specifika positioner
	for entity_type in entities.keys():
		var positions_data = entities[entity_type]
		spawn_entities_at_precise_positions(entity_type, positions_data)
	
	print_precise_level_summary(level, entities)

func spawn_entities_at_precise_positions(entity_type: String, positions_data: Array):
	"""Spawna entities på exakta grid positioner"""
	print("Spawning ", positions_data.size(), " ", entity_type, " at precise positions")
	
	for pos_data in positions_data:
		if not pos_data.has("x") or not pos_data.has("y"):
			print("ERROR: Position data missing x or y: ", pos_data)
			continue
		
		var grid_x = pos_data["x"]
		var grid_y = pos_data["y"]
		var rotation = pos_data.get("rotation", null)  # Hämta rotation om den finns
		
		# Konvertera grid koordinater till world position
		var world_pos = grid_to_world_position(grid_x, grid_y)
		if world_pos == Vector2.ZERO:
			print("ERROR: Invalid grid position: (", grid_x, ", ", grid_y, ")")
			continue
		
		# Spawna entity på world position med optional rotation
		spawn_entity_at_position_with_rotation(entity_type, world_pos, rotation)

func grid_to_world_position(grid_x: int, grid_y: int) -> Vector2:
	"""Konvertera grid koordinater (0-14, 0-8) till world position"""
	if grid_x < 0 or grid_x >= x_positions.size():
		print("ERROR: Invalid grid_x: ", grid_x, " (valid range: 0-", x_positions.size()-1, ")")
		return Vector2.ZERO
	
	if grid_y < 0 or grid_y >= y_positions.size():
		print("ERROR: Invalid grid_y: ", grid_y, " (valid range: 0-", y_positions.size()-1, ")")
		return Vector2.ZERO
	
	var world_x = x_positions[grid_x]
	var world_y = y_positions[grid_y]
	
	return Vector2(world_x, world_y)

func spawn_entity_type(entity_type: String, count: int):
	"""Spawna en specifik typ av entity med random/weighted positioning"""
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

func spawn_entity_at_position_with_rotation(entity_type: String, world_pos: Vector2, rotation: Variant = null):
	"""Spawna en specifik entity på en exakt world position med optional rotation"""
	match entity_type:
		"block_red":
			main_scene.spawn_enemy_kvadrat_at_position(world_pos)
		"block_blue":
			main_scene.spawn_blue_block_at_position(world_pos)
		"block_laser":
			main_scene.spawn_laser_block_at_position(world_pos)
		"block_iron":
			spawn_iron_block_with_rotation(world_pos, rotation)
		"block_cloud":
			main_scene.spawn_cloud_block_at_position(world_pos)
		"block_dropper":
			main_scene.spawn_enemy_block_dropper_at_position(world_pos)
		"block_dropper_fireball":
			main_scene.spawn_fireball_dropper_at_position(world_pos)
		"enemy":
			main_scene.spawn_enemy_at_position(world_pos)
		_:
			print("WARNING: Unknown entity type for precise spawning: ", entity_type)

func spawn_iron_block_with_rotation(world_pos: Vector2, rotation: Variant = null):
	"""Spawna iron block med specifik rotation"""
	# Använd main scene för att spawna iron block
	main_scene.spawn_iron_block_at_position(world_pos)
	
	# Om rotation specificerades, ändra rotationen
	if rotation != null:
		# Hitta det senast spawnerade iron blocket
		var iron_blocks = main_scene.iron_blocks
		if iron_blocks.size() > 0:
			var latest_iron_block = iron_blocks[-1]  # Senast tillagda
			if is_instance_valid(latest_iron_block):
				latest_iron_block.rotation_degrees = rotation
				print("Set iron block rotation to ", rotation, " degrees at position ", world_pos)

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
	"""Skriv ut en sammanfattning av vad som spawnades (random)"""
	print("Level ", level, " spawned successfully (random positioning):")
	
	for entity_type in config.keys():
		if entity_type != "precise_spawning":
			var count = config[entity_type]
			print("  - ", count, " ", entity_type.replace("_", " "))

func print_precise_level_summary(level: int, entities: Dictionary):
	"""Skriv ut en sammanfattning av vad som spawnades (precise)"""
	print("Level ", level, " spawned successfully (PRECISE positioning):")
	
	for entity_type in entities.keys():
		var positions = entities[entity_type]
		print("  - ", positions.size(), " ", entity_type.replace("_", " "), " at specific positions")

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

# === UTILITY FUNCTIONS ===

func get_level_config(level: int) -> Dictionary:
	"""Få konfigurationen för en specifik level"""
	if level_configs.has(level):
		return level_configs[level]
	else:
		return {}

func add_precise_level_config(level: int, entities: Dictionary):
	"""Lägg till en ny precision level konfiguration"""
	level_configs[level] = {
		"precise_spawning": true,
		"entities": entities
	}
	print("Added precise configuration for level ", level)

func add_normal_level_config(level: int, config: Dictionary):
	"""Lägg till en ny vanlig level konfiguration"""
	level_configs[level] = config
	print("Added normal configuration for level ", level, ": ", config)

func set_entity_at_grid_position_with_rotation(level: int, entity_type: String, grid_x: int, grid_y: int, rotation: int = 0):
	"""Lägg till en entity på en specifik grid position för en level med rotation"""
	if not level_configs.has(level):
		level_configs[level] = {"precise_spawning": true, "entities": {}}
	
	var config = level_configs[level]
	
	# Konvertera till precision format om det inte redan är det
	if not config.has("precise_spawning"):
		config["precise_spawning"] = true
		config["entities"] = {}
	
	# Lägg till entity position med rotation
	if not config["entities"].has(entity_type):
		config["entities"][entity_type] = []
	
	var entity_data = {"x": grid_x, "y": grid_y}
	if rotation != 0:  # Lägg bara till rotation om den inte är 0
		entity_data["rotation"] = rotation
	
	config["entities"][entity_type].append(entity_data)
	print("Added ", entity_type, " at grid position (", grid_x, ", ", grid_y, ") with rotation ", rotation, "° for level ", level)

func visualize_grid():
	"""Debug funktion för att visa grid koordinater"""
	print("\n=== GRID VISUALIZATION ===")
	print("Grid size: ", x_positions.size(), "x", y_positions.size())
	print("X positions (0-14): ", x_positions)
	print("Y positions (0-8): ", y_positions)
	
	print("\nGrid layout:")
	for y in range(y_positions.size()):
		var line = "Row " + str(y) + " (y=" + str(y_positions[y]) + "): "
		for x in range(x_positions.size()):
			line += "(" + str(x) + "," + str(y) + ") "
		print(line)
	print("=== END GRID ===\n")
