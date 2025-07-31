extends StaticBody2D

# Enemy settings
@export var max_health: int = 10
@export var score_value: int = 10  # Points awarded when killed
@export var enemy_type: String = "basic"

# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")

# Internal variables
var current_health: int
var is_dead: bool = false
var original_color: Color

# Signals
signal block_died(score_points: int)
signal block_hit(damage: int)

func _ready():
	# Set up enemy
	current_health = max_health
	
	# Set collision layer for enemy (let's use layer 5)
	collision_layer = 16  # Layer 5 (2^4 = 16)
	collision_mask = 2    # Can be hit by projectiles (layer 2)
	
	# Store original sprite color
	if sprite:
		original_color = sprite.modulate
	
	# Set up health bar if it exists
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	# Position enemy in middle of screen (or wherever you want)
	# This can be overridden when spawning
	
	print("Enemy created with ", max_health, " health at position: ", global_position)

func _physics_process(delta):
	pass

func take_damage(damage: int):
	if is_dead:
		return
	
	print("Enemy took ", damage, " damage")
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Update health bar
	if health_bar:
		health_bar.value = current_health
	
	# Visual damage feedback
	show_damage_effect()
	
	# Emit hit signal
	block_hit.emit(damage)
	
	# Check if dead
	if current_health <= 0:
		die()

# NEW: Silent damage method for laser kills (no score awarded)
func take_laser_damage(damage: int):
	"""Take damage from laser without awarding score when destroyed"""
	if is_dead:
		return
	
	print("Block took ", damage, " laser damage (no score on death)")
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Update health bar
	if health_bar:
		health_bar.value = current_health
	
	# Visual damage feedback
	show_damage_effect()
	
	# DON'T emit hit signal - no score for laser damage
	# block_hit.emit(damage)  # Commented out to prevent score
	
	# Check if dead - but call the silent death method
	if current_health <= 0:
		die_silently()

func die():
	if is_dead:
		return
	
	is_dead = true
	print("Enemy died! Awarding ", score_value, " points")
	
	# Emit death signal with score
	block_died.emit(score_value)
	
	play_death_effect()

# NEW: Silent death method (no score awarded)
func die_silently():
	"""Die without awarding score - used for laser kills"""
	if is_dead:
		return
	
	is_dead = true
	print("Block destroyed by laser (no score awarded)")
	
	# Don't emit the death signal that awards score
	# Just play the death effect
	play_death_effect()
	
func show_damage_effect():
	if not sprite:
		return
	
	# Flash red when hit
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", original_color, 0.1)

func play_death_effect():
	if not sprite:
		queue_free()
		return
	
	# Disable collision immediately
	if collision_shape:
		collision_shape.disabled = true
	
	# Hide health bar
	if health_bar:
		health_bar.visible = false
	
	# NEW: Check for blast damage to player BEFORE starting visual effects
	check_blast_damage()
	
	# Lås positionen så den inte rör sig
	var original_position = sprite.position
	
	# Supersnabb effekt - bara 0.1 sekunder
	var tween = create_tween()
	tween.set_parallel(true)  # Tillåt parallella animationer
	
	# Krymper skalan
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.1)
	
	# Håll positionen fast under hela animationen
	tween.tween_method(
		func(pos): sprite.position = pos,
		original_position, 
		original_position, 
		0.1
	)
	
	# Förstör direkt efter
	await tween.finished
	queue_free()
	
func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return not is_dead and current_health > 0

# Method called when projectile hits this enemy
func _on_projectile_hit():
	take_damage(10)  # Default damage from projectiles

# NEW: Blast damage system
func check_blast_damage():
	"""Check if player is within blast radius and apply damage + knockback"""
	var blast_radius = 80.0  # Smaller blast radius for basic blocks
	var blast_damage = 15  # Less damage than enemies
	var knockback_force = 600.0  # Less knockback than enemies
	
	# Find the player in the scene
	var player = find_player()
	if not player:
		return
	
	# Calculate distance to player
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Check if player is within blast radius
	if distance_to_player <= blast_radius:
		# Calculate damage based on distance (closer = more damage)
		var damage_multiplier = 1.0 - (distance_to_player / blast_radius)
		var final_damage = int(blast_damage * damage_multiplier)
		
		# Calculate knockback direction (away from explosion)
		var knockback_direction = (player.global_position - global_position).normalized()
		var final_knockback = knockback_force * damage_multiplier
		
		print("BLOCK BLAST HIT! Damage: ", final_damage, " Knockback: ", final_knockback)
		
		# Apply damage to player
		if player.has_method("take_damage"):
			player.take_damage(final_damage)
		
		# Apply knockback to player
		if player.has_method("apply_knockback"):
			player.apply_knockback(knockback_direction, final_knockback)

func find_player():
	"""Find the player node in the scene"""
	var scene_root = get_tree().current_scene
	var player = scene_root.find_child("Player", true, false)
	if player:
		return player
	
	# Fallback: look for CharacterBody2D with player layer
	for child in scene_root.get_children():
		if child is CharacterBody2D and child.collision_layer == 1:
			return child
	
	return null
