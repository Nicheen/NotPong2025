extends StaticBody2D

# Enemy settings - Iron block has 4 lives (40 health = 4 hits of 10 damage each)
@export var max_health: int = 40
@export var score_value: int = 25  # More points than blue blocks
@export var enemy_type: String = "iron_block"

# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

# Sprite textures for damage states
var normal_texture: Texture2D
var cracked1_texture: Texture2D
var cracked2_texture: Texture2D
var cracked3_texture: Texture2D

# Regeneration settings (longer than blue blocks)
@export var regeneration_delay: float = 7.0  # Even longer delay
@export var regeneration_pulse_time: float = 2.0  # Longer pulsing time

# Internal variables
var current_health: int
var is_dead: bool = false
var original_color: Color
var has_been_damaged: bool = false

# Regeneration variables
var regeneration_timer: float = 0.0
var is_regenerating: bool = false
var regeneration_tween: Tween

# Rotation variants (0, 90, 180, 270 degrees)
var rotation_variants = [0, 90, 180, 270]

# Signals
signal block_died(score_points: int)
signal block_hit(damage: int)

func _ready():
	# Set up iron block
	current_health = max_health
	
	# Set collision layer for blocks
	collision_layer = 16  # Layer 5 (2^4 = 16)
	collision_mask = 2    # Can be hit by projectiles (layer 2)
	
	# Apply random rotation for variation
	var random_rotation = rotation_variants[randi() % rotation_variants.size()]
	rotation_degrees = random_rotation
	
	# Store original sprite color and load textures
	if sprite:
		original_color = sprite.modulate
		normal_texture = sprite.texture
		
		# Load all damage state textures
		cracked1_texture = load("res://images/BlockIronCracked1.png")
		cracked2_texture = load("res://images/BlockIronCracked2.png")
		cracked3_texture = load("res://images/BlockIronCracked3.png")
		
		if not cracked1_texture or not cracked2_texture or not cracked3_texture:
			print("WARNING: Could not load one or more iron block cracked textures")
	
	print("Iron Block created with ", max_health, " health (4 lives) at position: ", global_position, " with rotation: ", rotation_degrees)

func _physics_process(delta):
	# Handle regeneration timing
	if has_been_damaged and not is_dead and not is_regenerating:
		regeneration_timer += delta
		if regeneration_timer >= regeneration_delay:
			start_regeneration()

func take_damage(damage: int):
	if is_dead:
		return
	
	print("Iron Block took ", damage, " damage (", current_health - damage, "/", max_health, " remaining)")
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Change sprite based on damage level
	update_damage_sprite()
	
	# Mark as damaged if this is first hit
	if not has_been_damaged and current_health < max_health:
		has_been_damaged = true
		regeneration_timer = 0.0  # Start regeneration timer
		print("Iron Block damaged - regeneration timer started!")
	
	# Stop any ongoing regeneration
	if is_regenerating:
		stop_regeneration()
	
	# Reset regeneration timer on damage
	regeneration_timer = 0.0
	
	# Visual damage feedback
	show_damage_effect()
	
	# Emit hit signal
	block_hit.emit(damage)
	
	# Check if dead (all lives lost)
	if current_health <= 0:
		die()

# Laser damage method (no score awarded)
func take_laser_damage(damage: int):
	if is_dead:
		return
	
	print("Iron Block took ", damage, " laser damage (no score on death)")
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Change sprite based on damage level
	update_damage_sprite()
	
	# Mark as damaged if this is first hit
	if not has_been_damaged and current_health < max_health:
		has_been_damaged = true
		regeneration_timer = 0.0
	
	# Stop any ongoing regeneration
	if is_regenerating:
		stop_regeneration()
	
	# Reset regeneration timer on damage
	regeneration_timer = 0.0
	
	# Visual damage feedback
	show_damage_effect()
	
	# Check if dead - but call the silent death method
	if current_health <= 0:
		die_silently()

func update_damage_sprite():
	"""Update sprite based on current health level"""
	if not sprite:
		return
	
	var health_percentage = float(current_health) / float(max_health)
	
	if health_percentage > 0.75:
		# 76-100% health: normal sprite
		sprite.texture = normal_texture
	elif health_percentage > 0.50:
		# 51-75% health: first crack
		sprite.texture = cracked1_texture
	elif health_percentage > 0.25:
		# 26-50% health: second crack
		sprite.texture = cracked2_texture
	else:
		# 1-25% health: third crack
		sprite.texture = cracked3_texture

func start_regeneration():
	"""Start the regeneration process"""
	if is_dead or is_regenerating:
		return
	
	is_regenerating = true
	print("Iron Block starting regeneration...")
	
	# Create regeneration tween
	regeneration_tween = create_tween()
	regeneration_tween.set_loops()  # Loop indefinitely
	
	# Pulse orange during regeneration (iron color)
	regeneration_tween.tween_property(sprite, "modulate", Color.ORANGE, regeneration_pulse_time / 2)
	regeneration_tween.tween_property(sprite, "modulate", original_color, regeneration_pulse_time / 2)
	
	# Wait for the pulsing period, then heal
	await get_tree().create_timer(regeneration_pulse_time * 4).timeout  # Pulse 4 times (longer than blue)
	
	if is_regenerating:  # Check if still regenerating (not interrupted)
		complete_regeneration()

func complete_regeneration():
	"""Complete the regeneration and restore to full health"""
	if is_dead:
		return
	
	print("Iron Block regeneration complete!")
	
	# Restore to full health
	current_health = max_health
	has_been_damaged = false
	regeneration_timer = 0.0
	
	# Change back to normal sprite
	if sprite and normal_texture:
		sprite.texture = normal_texture
	
	# Stop regeneration
	stop_regeneration()
	
	# Flash bright orange to indicate full regeneration
	var heal_tween = create_tween()
	heal_tween.tween_property(sprite, "modulate", Color.ORANGE_RED, 0.2)
	heal_tween.tween_property(sprite, "modulate", original_color, 0.2)

func stop_regeneration():
	"""Stop the regeneration process"""
	if not is_regenerating:
		return
	
	is_regenerating = false
	
	# Stop the regeneration tween
	if regeneration_tween:
		regeneration_tween.kill()
		regeneration_tween = null
	
	# Restore original color
	if sprite:
		sprite.modulate = original_color
	
	print("Iron Block regeneration stopped")

func die():
	if is_dead:
		return
	
	is_dead = true
	print("Iron Block died! Awarding ", score_value, " points")
	
	# Emit death signal with score
	block_died.emit(score_value)
	
	play_death_effect()

# Silent death method (no score awarded)
func die_silently():
	"""Die without awarding score - used for laser kills"""
	if is_dead:
		return
	
	is_dead = true
	print("Iron Block destroyed by laser (no score awarded)")
	
	# Stop regeneration
	if is_regenerating:
		stop_regeneration()
	
	# Send signal with 0 points so enemy counter still updates
	block_died.emit(0)
	
	play_death_effect()

func show_damage_effect():
	if not sprite:
		return
	
	# Don't show damage effect if regenerating (orange pulse takes priority)
	if is_regenerating:
		return
	
	# Flash orange when hit (matching iron color)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.ORANGE, 0.1)
	tween.tween_property(sprite, "modulate", original_color, 0.1)

func play_death_effect():
	if not sprite:
		queue_free()
		return
	
	# Disable collision immediately
	if collision_polygon:
		collision_polygon.disabled = true
	
	# Lock position so it doesn't move
	var original_position = sprite.position
	
	# Super fast effect - only 0.1 seconds
	var tween = create_tween()
	tween.set_parallel(true)  # Allow parallel animations
	
	# Shrink the scale
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.1)
	
	# Keep position fixed during animation
	tween.tween_method(
		func(pos): sprite.position = pos,
		original_position, 
		original_position, 
		0.1
	)
	
	# Destroy after animation
	await tween.finished
	queue_free()

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return not is_dead and current_health > 0

# Method called when projectile hits this block
func _on_projectile_hit():
	take_damage(10)  # Default damage from projectiles
