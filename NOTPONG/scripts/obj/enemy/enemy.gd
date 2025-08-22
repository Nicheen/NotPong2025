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

var explosion_delay: float = 0.0

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
	
func start_burning(exploded_by_bomb: bool = false):
	"""Start the burning effect"""
	if is_burning or is_dead:
		return
		
	is_burning = true

	# Start the burn timer
	if exploded_by_bomb:
		# Chain explosions happen faster but with variation
		burn_timer.wait_time = randf_range(0.3, 0.7)
	else:
		# Player-triggered explosions take longer
		burn_timer.wait_time = randf_range(1.2, 1.8)
		
	burn_timer.start()
	start_burning_modulation()

func start_burning_modulation():
	"""Create pulsing red effect while burning"""
	if not sprite or is_dead:
		return
	
	var burn_tween = create_tween()
	burn_tween.set_loops()
	burn_tween.tween_property(sprite, "modulate", Color.RED, 0.3)
	burn_tween.tween_property(sprite, "modulate", original_color, 0.3)

func _on_burn_timer_timeout():
	"""Called when burn timer expires - deal explosive damage"""
	if is_dead:
		return
		
	
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
		die()
	else:
		is_burning = false

func take_damage(damage: int, exploded_by_bomb: bool = false):
	if is_dead:
		return
	
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
	enemy_died.emit(score_value, global_position)
	play_death_effect()

func die_silently():
	if is_dead:
		return
	
	is_dead = true
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
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= blast_radius:
		var damage_multiplier = 1.0 - (distance_to_player / blast_radius)
		var final_damage = int(blast_damage * damage_multiplier)
		var knockback_direction = (player.global_position - global_position).normalized()
		var final_knockback = knockback_force * damage_multiplier
		
		print("BLAST HIT! Damage: ", final_damage, " Knockback: ", final_knockback)
		
		if player.has_method("take_damage"):
			player.take_damage(final_damage)
		
		if player.has_method("apply_knockback"):
			player.apply_knockback(knockback_direction, final_knockback)
		

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
	create_optimized_explosion()

func create_optimized_explosion():
	"""Fast, simple explosion that doesn't lag"""
	# Hide original sprite
	sprite.visible = false
	
	# Create simple explosion sprite
	var explosion = Sprite2D.new()
	explosion.texture = create_explosion_texture()
	explosion.global_position = global_position
	explosion.modulate = Color.ORANGE_RED
	explosion.scale = Vector2(0.5, 0.5)
	get_parent().add_child(explosion)
	
	# Quick scale and fade animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(explosion, "scale", Vector2(2.5, 2.5), 0.4)
	tween.tween_property(explosion, "modulate", Color.TRANSPARENT, 0.4)
	
	# Clean up
	tween.finished.connect(func(): 
		if is_instance_valid(explosion):
			explosion.queue_free()
	)
	
	# Remove enemy immediately to prevent further interactions
	queue_free()

func create_explosion_texture() -> ImageTexture:
	"""Create simple explosion texture"""
	var size = 24
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size/2, size/2)
	
	for x in range(size):
		for y in range(size):
			var pixel_pos = Vector2(x, y)
			var distance = center.distance_to(pixel_pos)
			
			if distance <= size/2:
				var alpha = 1.0 - (distance / (size/2))
				image.set_pixel(x, y, Color(1, 0.6, 0, alpha))
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture
	
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
