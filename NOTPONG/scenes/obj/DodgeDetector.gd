# DodgeDetector.gd
# Lägg till som child till Player med en Area2D och CollisionShape2D
extends Area2D

signal perfect_dodge_detected(enemy_attack)

# Inställningar
@export var detection_radius: float = 80.0  # Hur stor area runt spelaren
@export var dodge_window: float = 0.3       # Tidsram för perfect dodge

# State tracking
var nearby_attacks: Array = []
var last_dash_time: float = 0.0
var player: CharacterBody2D
var enhanced_shots_remaining: int = 0

func _ready():
	# Hitta player reference
	player = get_parent()
	
	# Konfigurera area
	body_entered.connect(_on_attack_entered)
	body_exited.connect(_on_attack_exited)
	area_entered.connect(_on_area_entered) 
	area_exited.connect(_on_area_exited)
	
	# Sätt collision layers (detektera projectiles och enemies)
	collision_layer = 0  # Vi kolliderar inte
	collision_mask = 6   # Layer 2 (Damage) + Layer 3 (enligt din setup)
	
	# Skapa collision shape
	setup_collision_shape()
	
	print("Dodge detector ready!")

func setup_collision_shape():
	"""Skapa en cirkulär collision shape för detection"""
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = detection_radius
	collision.shape = circle
	add_child(collision)

func _process(delta):
	# Kontrollera för perfect dodge
	check_for_perfect_dodge()
	
	# NYTT: Enkelt reactive dodge system
	check_for_active_area_attacks()

func check_for_laser_attacks():
	"""Timing-baserad kontroll för laser/thunder attacks"""
	if not Input.is_action_just_pressed("dash"):
		return
	
	# Timing-baserad dodge - kolla om attacks kommer aktiveras snart
	check_for_imminent_lasers()
	check_for_imminent_thunder()

func check_for_imminent_lasers():
	"""Kontrollera för lasers som kommer aktiveras inom dodge window"""
	var scene_root = get_tree().current_scene
	var laser_blocks = []
	find_laser_blocks_recursive(scene_root, laser_blocks)
	
	var dodge_timing_window = 0.3  # Samma som dodge_detection_window
	
	for laser_block in laser_blocks:
		if not is_instance_valid(laser_block):
			continue
		
		# Kontrollera timer - hur lång tid kvar till laser aktiveras
		if not ("laser_timer" in laser_block and "laser_activation_delay" in laser_block):
			continue
			
		var time_until_activation = laser_block.laser_activation_delay - laser_block.laser_timer
		
		# Perfect dodge om laser kommer aktiveras inom dodge window
		if time_until_activation > 0 and time_until_activation <= dodge_timing_window:
			# Kontrollera om spelaren skulle bli träffad av denna laser
			if would_laser_hit_player(laser_block):
				print("Perfect dodge detected! Laser activates in: ", time_until_activation, " seconds")
				perfect_dodge_detected.emit(laser_block)
				
				if PerfectDodgeSystem:
					PerfectDodgeSystem.trigger_perfect_dodge()
				
				disable_laser_temporarily(laser_block)
				return

func would_laser_hit_player(laser_block) -> bool:
	"""Kontrollera om lasern skulle träffa spelaren när den aktiveras"""
	if not laser_block:
		return false
	
	# Få laser beam component
	var laser = laser_block.get_node_or_null("LaserBeam2D")
	if not laser:
		return false
	
	# Kontrollera laser direction och position
	var laser_start = laser_block.global_position
	var laser_direction = Vector2.RIGHT  # Standard laser riktning
	
	# Om laser är roterad, justera riktning
	if laser.rotation != 0:
		laser_direction = Vector2.RIGHT.rotated(laser.rotation)
	
	# Kontrollera om spelaren är i laser path
	var player_pos = player.global_position
	var to_player = player_pos - laser_start
	
	# Kontrollera om spelaren är på samma höjd/linje som lasern
	var perpendicular_distance = abs(to_player.dot(laser_direction.rotated(PI/2)))
	var laser_width = 25.0  # Ungefär laser width
	
	if perpendicular_distance <= laser_width:
		# Kontrollera om spelaren är framför laser start position
		var forward_distance = to_player.dot(laser_direction)
		if forward_distance > 0:
			print("Player would be hit by laser! Distance: ", perpendicular_distance)
			return true
	
	return false

func check_for_imminent_thunder():
	"""Kontrollera för thunder som kommer aktiveras inom dodge window"""
	var scene_root = get_tree().current_scene
	var thunder_controllers = []
	find_thunder_controllers_recursive(scene_root, thunder_controllers)
	
	var dodge_timing_window = 0.3
	
	for thunder in thunder_controllers:
		if not is_instance_valid(thunder):
			continue
		
		# Kontrollera cycle timer för thunder
		if not ("cycle_timer" in thunder and "current_inactive_duration" in thunder):
			continue
		
		var time_until_activation = thunder.current_inactive_duration - thunder.cycle_timer
		
		# Perfect dodge om thunder kommer aktiveras inom dodge window
		if time_until_activation > 0 and time_until_activation <= dodge_timing_window:
			# Kontrollera om spelaren skulle bli träffad av thunder
			if would_thunder_hit_player(thunder):
				print("Perfect dodge detected! Thunder activates in: ", time_until_activation, " seconds")
				perfect_dodge_detected.emit(thunder)
				
				if PerfectDodgeSystem:
					PerfectDodgeSystem.trigger_perfect_dodge()
				
				disable_thunder_temporarily(thunder)
				return

func would_thunder_hit_player(thunder_controller) -> bool:
	"""Kontrollera om thunder skulle träffa spelaren när det aktiveras"""
	if not thunder_controller:
		return false
	
	# Kontrollera om spelaren är i thunder area
	var thunder_pos = thunder_controller.global_position
	var player_pos = player.global_position
	
	# Thunder har en viss width (från thunder scene setup)
	var thunder_width = 150.0 * 0.4  # 150 width * 0.4 scale från scene
	var distance_x = abs(player_pos.x - thunder_pos.x)
	
	if distance_x <= thunder_width / 2:
		print("Player would be hit by thunder! X distance: ", distance_x)
		return true
	
	return false

func find_thunder_controllers_recursive(node, thunder_array):
	"""Hitta alla thunder controllers rekursivt"""
	if ("thunder" in node.name.to_lower() and 
		node.has_method("deactivate_thunder")):
		thunder_array.append(node)
	
	for child in node.get_children():
		find_thunder_controllers_recursive(child, thunder_array)

func disable_thunder_temporarily(thunder_controller):
	"""Stäng av thunder tillfälligt när det dodgas"""
	if thunder_controller.has_method("deactivate_thunder"):
		thunder_controller.deactivate_thunder()
		print("Thunder deactivated due to perfect dodge")
		
		# Återaktivera efter perfect dodge perioden
		var timer = get_tree().create_timer(0.6)
		timer.timeout.connect(_reactivate_thunder.bind(thunder_controller))

func _reactivate_thunder(thunder_controller):
	"""Återaktivera thunder efter dodge period"""
	if is_instance_valid(thunder_controller) and thunder_controller.has_method("activate_vertical_thunder"):
		thunder_controller.activate_vertical_thunder()
		print("Thunder reactivated after dodge period")

func find_laser_blocks_recursive(node, laser_blocks_array):
	"""Hitta alla laser blocks rekursivt"""
	if "laser" in node.name.to_lower() and node.has_method("deactivate_laser"):
		laser_blocks_array.append(node)
	
	for child in node.get_children():
		find_laser_blocks_recursive(child, laser_blocks_array)

func disable_laser_temporarily(laser_block):
	"""Stäng av laser tillfälligt när den dodgas"""
	if laser_block.has_method("deactivate_laser"):
		laser_block.deactivate_laser()
		print("Laser deactivated due to perfect dodge")
		
		# Återaktivera efter perfect dodge perioden (0.6 sekunder)
		var timer = get_tree().create_timer(0.6)
		timer.timeout.connect(_reactivate_laser.bind(laser_block))

func check_for_perfect_dodge():
	"""Kontrollera om spelaren gjort en perfect dodge"""
	if not Input.is_action_just_pressed("dash"):
		return
	
	if nearby_attacks.is_empty():
		return
	
	# FIX 3: Speciell hantering för laser attacks
	var incoming_attack = find_incoming_attack()
	if incoming_attack:
		print("Perfect dodge detected against: ", incoming_attack.name)
		perfect_dodge_detected.emit(incoming_attack)
		
		# Aktivera perfect dodge systemet
		if PerfectDodgeSystem:
			PerfectDodgeSystem.trigger_perfect_dodge()
		
		# Markera att vi dodgade denna attack
		mark_attack_as_dodged(incoming_attack)
		
		# Speciell hantering för laser
		if is_laser_attack(incoming_attack):
			disable_laser_temporarily(incoming_attack)

func is_laser_attack(attack) -> bool:
	"""Kontrollera om attacken är en laser"""
	return (attack is RayCast2D or 
			"laser" in attack.name.to_lower() or
			attack.get_class() == "RayCast2D")

func _reactivate_laser(laser_block):
	"""Återaktivera laser efter dodge period"""
	if is_instance_valid(laser_block) and laser_block.has_method("activate_laser"):
		laser_block.activate_laser()
		print("Laser reactivated after dodge period")

func find_incoming_attack():
	"""Hitta attack som kommer träffa oss inom dodge window"""
	for attack in nearby_attacks:
		if not is_instance_valid(attack):
			continue
			
		# Kontrollera avstånd och riktning
		var distance = global_position.distance_to(attack.global_position)
		var attack_speed = get_attack_speed(attack)
		
		if attack_speed > 0:
			var time_to_impact = distance / attack_speed
			
			# Perfect dodge om attacken kommer träffa inom dodge window
			if time_to_impact > 0 and time_to_impact <= dodge_window:
				return attack
	
	return null

func get_attack_speed(attack) -> float:
	"""Försök hitta attackens hastighet"""
	if "velocity" in attack:
		return attack.velocity.length()
	elif "speed" in attack:
		return attack.speed
	elif "linear_velocity" in attack:
		return attack.linear_velocity.length()
	else:
		# Default guess för statiska enemies
		return 200.0

func mark_attack_as_dodged(attack):
	"""Markera att vi dodgade denna attack så vi inte tar skada"""
	if attack.has_method("set_dodged"):
		attack.set_dodged(true)
	elif "dodged" in attack:
		attack.dodged = true

func _on_attack_entered(body):
	"""När en attack/enemy kommer in i vårt detection område"""
	if is_attack_object(body):
		nearby_attacks.append(body)
		print("Attack entered detection zone: ", body.name)

func check_for_active_area_attacks():
	"""Enkelt system - dodge aktiva laser/thunder attacks"""
	if not Input.is_action_just_pressed("dash"):
		return
	
	# Kolla om spelaren just nu tar skada från laser eller thunder
	if is_player_being_damaged_by_area_attack():
		print("Reactive dodge detected! Player was being damaged by area attack")
		perfect_dodge_detected.emit(null)
		
		if PerfectDodgeSystem:
			PerfectDodgeSystem.trigger_perfect_dodge()
		
		# Ge spelaren 1 enhanced shot
		enhanced_shots_remaining = 1
		print("Player granted 1 enhanced shot")
		
		# Gör spelaren tillfälligt immun mot area damage
		make_player_temporarily_immune()

func is_player_being_damaged_by_area_attack() -> bool:
	"""Kontrollera om spelaren just nu tar skada från area attacks"""
	var scene_root = get_tree().current_scene
	
	# Hitta alla aktiva lasers - FIX: Kolla även laser_ready state
	var laser_blocks = []
	find_laser_blocks_recursive(scene_root, laser_blocks)
	
	for laser_block in laser_blocks:
		if not is_instance_valid(laser_block):
			continue
		
		# Kolla om laser är aktiv ELLER kommer aktiveras mycket snart
		var laser_active = ("laser_activated" in laser_block and laser_block.laser_activated)
		var laser_about_to_fire = false
		
		if "laser_timer" in laser_block and "laser_activation_delay" in laser_block:
			var time_left = laser_block.laser_activation_delay - laser_block.laser_timer
			laser_about_to_fire = (time_left <= 0.1 and time_left >= -0.1)
		
		if laser_active or laser_about_to_fire:
			# Kontrollera om spelaren är i laser path
			if is_player_in_laser_path(laser_block):
				print("Player is in laser attack area!")
				return true
	
	# Kontrollera thunder (samma som innan)
	var thunder_controllers = []
	find_thunder_controllers_recursive(scene_root, thunder_controllers)
	
	for thunder in thunder_controllers:
		if not is_instance_valid(thunder):
			continue
			
		if ("is_lightning_active" in thunder and thunder.is_lightning_active and
			"players_in_area" in thunder and player in thunder.players_in_area):
			print("Player is currently being hit by thunder!")
			return true
	
	return false

func is_player_in_laser_path(laser_block) -> bool:
	"""Kontrollera om spelaren är i laser path"""
	if not laser_block or not player:
		return false
	
	var laser_pos = laser_block.global_position
	var player_pos = player.global_position
	
	# Enkel kontroll - samma Y-position med lite margin
	var y_diff = abs(player_pos.y - laser_pos.y)
	var laser_width = 30.0  # Laser width med margin
	
	if y_diff <= laser_width:
		# Kontrollera om spelaren är till höger om laser (i laser path)
		if player_pos.x > laser_pos.x:
			print("Player in laser path! Y-diff: ", y_diff)
			return true
	
	return false


func make_player_temporarily_immune():
	"""Gör spelaren immun mot area damage under slow motion period"""
	if not player:
		return
	
	# Lägg till immunity flag på spelaren
	if not "area_damage_immunity" in player:
		player.set_meta("area_damage_immunity", true)
	else:
		player.area_damage_immunity = true
	
	print("Player granted temporary area damage immunity")
	
	# Ta bort immunity efter slow motion period
	var immunity_timer = get_tree().create_timer(0.6)  # Lite längre än slow motion
	immunity_timer.timeout.connect(_remove_player_immunity)

func _remove_player_immunity():
	"""Ta bort area damage immunity"""
	if player and is_instance_valid(player):
		if player.has_meta("area_damage_immunity"):
			player.remove_meta("area_damage_immunity")
		elif "area_damage_immunity" in player:
			player.area_damage_immunity = false
		print("Player area damage immunity removed")

func _on_attack_exited(body):
	"""När en attack/enemy lämnar vårt detection område"""
	if body in nearby_attacks:
		nearby_attacks.erase(body)
		print("Attack left detection zone: ", body.name)

func _on_area_entered(area):
	"""För projektiler som är Area2D"""
	if is_attack_object(area):
		nearby_attacks.append(area)
		print("Projectile entered detection zone: ", area.name)

func _on_area_exited(area):
	"""För projektiler som är Area2D"""
	if area in nearby_attacks:
		nearby_attacks.erase(area)
		print("Projectile left detection zone: ", area.name)

func is_attack_object(obj) -> bool:
	"""Kontrollera om objektet är en attack/projectile/enemy"""
	if not obj:
		return false
	
	# FIX 1: Exkludera player projectiles
	if "is_player_projectile" in obj and obj.is_player_projectile:
		return false
	
	var name_lower = obj.name.to_lower()
	
	# NYTT: Speciell hantering för FIREBALLS - dessa BORDE detekteras!
	if "fireball" in name_lower:
		print("🔥 FIREBALL DETECTED for dodge detection: ", obj.name)
		return true
	
	# NYTT: Kontrollera för Fireball class
	if obj.get_script() and obj.get_script().get_global_name() == "Fireball":
		print("🔥 FIREBALL CLASS DETECTED for dodge detection: ", obj.name)
		return true
	
	# Kontrollera om det är en projektil från vanliga block_droppers (exkludera dessa)
	if "projectile" in name_lower and obj.collision_layer == 2:
		# Om det har en direction neråt och INTE är en fireball, exkludera
		if "linear_velocity" in obj and obj.linear_velocity.y > 0 and "fireball" not in name_lower:
			return false
	
	# Kontrollera namn patterns för hostile attacks
	if ("enemy" in name_lower and "projectile" not in name_lower):
		return true
	
	# Kontrollera collision layers för hostile objects
	if obj.collision_layer & 2:  # Layer 2 = Damage
		# Men bara om det inte är en player projectile
		if not ("is_player_projectile" in obj):
			return true
	
	# Kontrollera för laser attacks (LaserBeam2D från block_laser)
	if obj is RayCast2D or "laser" in name_lower:
		return true
	
	# Kontrollera om objektet har attack-relaterade metoder
	if obj.has_method("deal_damage") or obj.has_method("explode"):
		return true
	
	# EXTRA: Kontrollera för Area2D fireballs med damage method
	if obj is Area2D and obj.has_method("hit_player"):
		print("🔥 AREA2D FIREBALL DETECTED: ", obj.name)
		return true
	
	return false

func get_detection_radius() -> float:
	return detection_radius

func set_detection_radius(new_radius: float):
	detection_radius = new_radius
	# Uppdatera collision shape om den finns
	var collision = get_child(0) as CollisionShape2D
	if collision and collision.shape is CircleShape2D:
		collision.shape.radius = detection_radius
