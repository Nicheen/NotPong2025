extends StaticBody2D

# Enemy settings
@export var max_health: int = 20
@export var score_value: int = 100
@export var enemy_type: String = "basic"

# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer = $Audio
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")

var normal_texture: Texture2D
var cracked_texture: Texture2D
# Internal variables
var current_health: int
var is_dead: bool = false
var original_color: Color
var is_burning: bool = false
var burn_timer: Timer

# Signals
signal enemy_died(score_points: int, death_position: Vector2)
signal enemy_hit(damage: int)

func _ready():
	current_health = max_health
	
	# Create burn timer
	burn_timer = Timer.new()
	burn_timer.wait_time = 1.5
	burn_timer.one_shot = true
	burn_timer.timeout.connect(_on_burn_timer_timeout)
	add_child(burn_timer)
	
	if sprite:
		original_color = sprite.modulate
		normal_texture = sprite.texture
		cracked_texture = load("res://images/Bomb2.png")
		
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	print("Enemy created with ", max_health, " health at position: ", global_position)

func _physics_process(delta):
	pass
	
func start_burning(exploded_by_bomb: bool = false):
	"""Start the burning effect"""
	if is_burning or is_dead:
		return
		
	is_burning = true
	print("Enemy started burning! Will explode in 1.5 seconds...")
	
	# Start the burn timer
	if exploded_by_bomb:
		burn_timer.wait_time = 0.5
	burn_timer.start()
	
	# Start burning visual effect
	start_burning_modulation()

func start_burning_modulation():
	"""Create pulsing red effect while burning"""
	if not sprite or is_dead:
		return
	
	var burn_tween = create_tween()
	burn_tween.set_loops() # Loop indefinitely
	
	# Pulse between red and original color
	burn_tween.tween_property(sprite, "modulate", Color.RED, 0.3)
	burn_tween.tween_property(sprite, "modulate", original_color, 0.3)

func _on_burn_timer_timeout():
	"""Called when burn timer expires - deal explosive damage"""
	if is_dead:
		return
		
	print("BURN TIMER EXPIRED! Enemy takes 10 explosive damage!")
	
	# Stop the burning modulation
	if sprite:
		var final_tween = create_tween()
		final_tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	
	# Deal the explosive damage (this will likely kill the enemy)
	current_health -= 10
	current_health = max(0, current_health)
	
	if health_bar:
		health_bar.value = current_health
	
	# Emit signal and die if health reaches 0
	enemy_hit.emit(10)
	
	if current_health <= 0:
		print("Enemy exploded from burning!")
		die()
	else:
		# If somehow still alive, stop burning
		is_burning = false

func take_damage(damage: int, exploded_by_bomb: bool = false):
	if is_dead:
		return
	
	print("Enemy took ", damage, " damage")
	
	current_health -= damage
	current_health = max(0, current_health)
	
	if current_health < max_health:
		change_to_cracked_sprite()
	if health_bar:
		health_bar.value = current_health
	
	show_damage_effect()
	
	if not is_burning and current_health > 0:
		start_burning(exploded_by_bomb)
	
	enemy_hit.emit(damage)
	
	if current_health <= 0:
		die()
		
func change_to_cracked_sprite():
	"""Change the sprite to the cracked version"""
	if sprite and cracked_texture:
		sprite.texture = cracked_texture
		
func take_laser_damage(damage: int):
	if is_dead:
		return
	
	print("Enemy took ", damage, " laser damage (no score on death)")
	
	current_health -= damage * 2
	current_health = max(0, current_health)
	
	if health_bar:
		health_bar.value = current_health
	
	show_damage_effect()
	
	if current_health <= 0:
		die_silently()

func die():
	if is_dead:
		return
	GlobalAudioManager.play_sfx(preload("res://audio/sfx/large-underwater-explosion-190270.wav"))
	is_dead = true
	print("Enemy died! Awarding ", score_value, " points")
	enemy_died.emit(score_value, global_position)
	play_death_effect()

func die_silently():
	if is_dead:
		return
	
	is_dead = true
	print("Enemy destroyed by laser (no score awarded)")
	enemy_died.emit(0, global_position)
	play_death_effect()

func show_damage_effect():
	if not sprite:
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", original_color, 0.1)

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return not is_dead and current_health > 0

func _on_projectile_hit():
	take_damage(10)
	
func check_blast_damage():
	var blast_radius = 150.0
	var blast_damage = 20
	var knockback_force = 2500.0
	
	var player = find_player()
	if not player:
		print("No player found for blast damage check")
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	print("Enemy explosion - Distance to player: ", distance_to_player, " Blast radius: ", blast_radius)
	
	if distance_to_player <= blast_radius:
		var damage_multiplier = 1.0 - (distance_to_player / blast_radius)
		var final_damage = int(blast_damage * damage_multiplier)
		var knockback_direction = (player.global_position - global_position).normalized()
		var final_knockback = knockback_force * damage_multiplier
		
		print("BLAST HIT! Damage: ", final_damage, " Knockback: ", final_knockback)
		
		if player.has_method("take_damage"):
			print(player)
			player.take_damage(final_damage)
		
		if player.has_method("apply_knockback"):
			player.apply_knockback(knockback_direction, final_knockback)
		else:
			print("Player doesn't have apply_knockback method - adding velocity directly")
			if "velocity" in player:
				player.velocity += knockback_direction * final_knockback
	else:
		print("Player outside blast radius - no damage")

func find_player():
	var scene_root = get_tree().current_scene
	
	var player = scene_root.find_child("Player", true, false)
	if player:
		return player
	
	for child in scene_root.get_children():
		if child is CharacterBody2D and child.collision_layer == 1:
			return child
	
	for child in scene_root.get_children():
		if child.has_method("take_damage") and child.has_method("get_health"):
			if "player" in child.name.to_lower():
				return child
	
	return null

func play_death_effect():
	if not sprite:
		queue_free()
		return
	
	if collision_shape:
		collision_shape.disabled = true
	
	if health_bar:
		health_bar.visible = false
	
	check_blast_damage()
	create_improved_explosion()

func create_improved_explosion():
	"""Create a much better looking explosion effect"""
	var explosion_pos = global_position
	
	# Create independent explosion container
	var explosion_container = Node2D.new()
	explosion_container.name = "BombExplosion"
	explosion_container.global_position = explosion_pos
	get_parent().add_child(explosion_container)
	
	# Hide original sprite
	sprite.visible = false
	
	# Create layered explosion effects without awaits
	create_core_flash(explosion_container)
	
	# Delay main effects slightly
	get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(explosion_container):
			create_main_fireball(explosion_container)
			create_shockwave_rings(explosion_container)
	)
	
	# Delay debris and smoke
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(explosion_container):
			create_debris_system(explosion_container)
			create_smoke_puffs(explosion_container)
	)
	
	# Screen effects
	create_screen_shake()
	
	# Clean up after all effects
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 3.0
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(explosion_container):
			explosion_container.queue_free()
	)
	explosion_container.add_child(cleanup_timer)
	cleanup_timer.start()
	
	# Remove enemy immediately
	queue_free()

func create_core_flash(container: Node2D):
	"""Bright initial flash"""
	var flash = create_explosion_sprite(60, Color.WHITE)
	flash.modulate.a = 0.9
	container.add_child(flash)
	
	# Create tween on the container, not the enemy
	var tween = container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.12)
	tween.tween_property(flash, "modulate:a", 0.0, 0.12)
	
	# Don't await here since enemy will be destroyed
	tween.finished.connect(func(): flash.queue_free())

func create_main_fireball(container: Node2D):
	"""Main orange fireball"""
	var fireball = create_explosion_sprite(45, Color.ORANGE_RED)
	container.add_child(fireball)
	
	# Create tween on the container
	var tween = container.create_tween()
	tween.set_parallel(true)
	
	# Expand and fade through colors
	tween.tween_property(fireball, "scale", Vector2(3.5, 3.5), 0.8)
	tween.tween_method(animate_fireball_color.bind(fireball), 0.0, 1.0, 0.8)
	tween.tween_property(fireball, "modulate:a", 0.0, 0.6)
	
	tween.finished.connect(func(): fireball.queue_free())

func animate_fireball_color(fireball: Node2D, progress: float):
	if not is_instance_valid(fireball):
		return
	
	# Color transition: Orange -> Yellow -> Red -> Dark Red
	var colors = [
		Color.ORANGE_RED,
		Color.YELLOW,
		Color.RED,
		Color.DARK_RED
	]
	
	var segment = progress * (colors.size() - 1)
	var index = int(segment)
	var local_progress = segment - index
	
	if index >= colors.size() - 1:
		fireball.modulate = colors[-1]
	else:
		fireball.modulate = colors[index].lerp(colors[index + 1], local_progress)

func create_shockwave_rings(container: Node2D):
	"""Multiple expanding rings"""
	var ring_count = 3
	
	for i in range(ring_count):
		var delay = i * 0.15
		
		# Use call_deferred to avoid timing issues
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_instance_valid(container):
				return
				
			var ring = create_ring_sprite(25, 8, Color.ORANGE)
			ring.modulate.a = 0.7 - (i * 0.2)
			container.add_child(ring)
			
			# Create tween on container
			var ring_tween = container.create_tween()
			ring_tween.set_parallel(true)
			ring_tween.tween_property(ring, "scale", Vector2(8.0, 8.0), 1.2)
			ring_tween.tween_property(ring, "modulate:a", 0.0, 1.0)
			
			ring_tween.finished.connect(func(): 
				if is_instance_valid(ring):
					ring.queue_free()
			)
		)

func create_debris_system(container: Node2D):
	"""Realistic debris with physics"""
	var debris_count = 20
	
	for i in range(debris_count):
		var debris = create_debris_piece()
		container.add_child(debris)
		
		# Random launch parameters
		var angle = randf() * TAU
		var speed = randf_range(150, 350)
		var gravity = randf_range(200, 400)
		
		var velocity = Vector2(cos(angle), sin(angle)) * speed
		animate_debris(debris, velocity, gravity, container)

func create_debris_piece() -> Node2D:
	"""Create individual debris piece"""
	var debris = Node2D.new()
	var sprite = Sprite2D.new()
	
	# Create small rectangular debris texture
	var size = randi_range(4, 10)
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	# Random debris color (metal/concrete)
	var colors = [Color.DIM_GRAY, Color.DARK_GRAY, Color.GRAY, Color.BROWN]
	var debris_color = colors[randi() % colors.size()]
	
	image.fill(debris_color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	sprite.texture = texture
	debris.add_child(sprite)
	
	return debris

func animate_debris(debris: Node2D, initial_velocity: Vector2, gravity: float, container: Node2D):
	"""Animate debris with realistic physics"""
	var duration = randf_range(1.5, 2.5)
	var rotation_speed = randf_range(-10, 10)
	
	# Create tween on container instead of enemy
	var tween = container.create_tween()
	tween.set_parallel(true)
	
	# Movement with gravity arc
	tween.tween_method(update_debris_position.bind(debris, initial_velocity, gravity), 0.0, duration, duration)
	
	# Rotation
	tween.tween_property(debris, "rotation", rotation_speed * duration, duration)
	
	# Fade out
	tween.tween_property(debris, "modulate:a", 0.0, duration * 0.8)
	
	tween.finished.connect(func():
		if is_instance_valid(debris):
			debris.queue_free()
	)

func update_debris_position(debris: Node2D, initial_velocity: Vector2, gravity: float, time: float):
	if not is_instance_valid(debris):
		return
	
	var pos = Vector2.ZERO
	pos.x = initial_velocity.x * time
	pos.y = initial_velocity.y * time + 0.5 * gravity * time * time
	
	debris.position = pos

func create_smoke_puffs(container: Node2D):
	"""Create smoke effects"""
	var smoke_count = 8
	
	for i in range(smoke_count):
		var delay = randf_range(0.2, 0.8)
		
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_instance_valid(container):
				return
				
			var smoke = create_explosion_sprite(30, Color.GRAY)
			smoke.modulate.a = 0.6
			smoke.position = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			container.add_child(smoke)
			
			# Create tween on container
			var smoke_tween = container.create_tween()
			smoke_tween.set_parallel(true)
			
			# Drift upward and expand
			smoke_tween.tween_property(smoke, "position", 
				smoke.position + Vector2(randf_range(-30, 30), -randf_range(80, 150)), 2.0)
			smoke_tween.tween_property(smoke, "scale", Vector2(2.5, 2.5), 2.0)
			smoke_tween.tween_property(smoke, "modulate:a", 0.0, 1.8)
			
			smoke_tween.finished.connect(func():
				if is_instance_valid(smoke):
					smoke.queue_free()
			)
		)

func create_explosion_sprite(radius: float, color: Color) -> Sprite2D:
	"""Create a solid circular sprite"""
	var sprite = Sprite2D.new()
	var size = int(radius * 2)
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(radius, radius)
	
	for x in range(size):
		for y in range(size):
			var pixel_pos = Vector2(x, y)
			var distance = center.distance_to(pixel_pos)
			
			if distance <= radius:
				# Soft gradient from center to edge
				var alpha = 1.0 - (distance / radius) * 0.4
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	sprite.texture = texture
	
	return sprite

func create_ring_sprite(outer_radius: float, thickness: float, color: Color) -> Sprite2D:
	"""Create a ring/donut shaped sprite"""
	var sprite = Sprite2D.new()
	var size = int(outer_radius * 2)
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(outer_radius, outer_radius)
	var inner_radius = outer_radius - thickness
	
	for x in range(size):
		for y in range(size):
			var pixel_pos = Vector2(x, y)
			var distance = center.distance_to(pixel_pos)
			
			if distance <= outer_radius and distance >= inner_radius:
				# Soft edges on both inner and outer
				var outer_alpha = 1.0 - max(0, (distance - outer_radius + 2) / 2)
				var inner_alpha = 1.0 - max(0, (inner_radius - distance + 2) / 2)
				var alpha = min(outer_alpha, inner_alpha)
				
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	sprite.texture = texture
	
	return sprite

func create_screen_shake():
	"""Enhanced screen shake"""
	var camera = find_camera_in_scene()
	if not camera:
		return
	
	if camera.has_method("add_trauma"):
		camera.add_trauma(0.8)
	else:
		# Manual screen shake - create independent tween
		var original_pos = camera.global_position
		var shake_tween = get_tree().create_tween()
		
		# More intense shake with decay
		for i in range(12):
			var intensity = 8.0 * (1.0 - float(i) / 12.0)  # Decay over time
			var shake_offset = Vector2(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity)
			)
			shake_tween.tween_property(camera, "global_position", 
				original_pos + shake_offset, 0.04)
		
		shake_tween.tween_property(camera, "global_position", original_pos, 0.1)

func find_camera_in_scene():
	var scene_root = get_tree().current_scene
	return scene_root.find_child("Camera2D", true, false)
