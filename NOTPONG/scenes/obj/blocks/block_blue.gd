extends StaticBody2D

# Enemy settings - Blue block has 2 lives (20 health = 2 hits of 10 damage each)
@export var max_health: int = 20
@export var score_value: int = 15  # More points than regular blocks
@export var enemy_type: String = "blue_block"

# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Sprite textures
var normal_texture: Texture2D
var cracked_texture: Texture2D

# Regeneration settings (longer than regular blocks)
@export var regeneration_delay: float = 5.0  # Longer delay before regeneration starts
@export var regeneration_pulse_time: float = 1.5  # Longer pulsing time

# Internal variables
var current_health: int
var is_dead: bool = false
var original_color: Color
var has_been_damaged: bool = false

# Regeneration variables
var regeneration_timer: float = 0.0
var is_regenerating: bool = false
var regeneration_tween: Tween

# Signals
signal block_died(score_points: int)
signal block_hit(damage: int)

func _ready():
	# Set up blue block
	current_health = max_health
	
	# Set collision layer for blocks
	collision_layer = 16  # Layer 5 (2^4 = 16)
	collision_mask = 2    # Can be hit by projectiles (layer 2)
	
	# Store original sprite color and load textures
	if sprite:
		original_color = sprite.modulate
		normal_texture = sprite.texture
		
		# Load the cracked texture
		cracked_texture = load("res://images/BlockBlueCracked.png")
		if not cracked_texture:
			print("WARNING: Could not load cracked texture at res://images/BlockBlueCracked.png")
	
	print("Blue Block created with ", max_health, " health (2 lives) at position: ", global_position)

func _physics_process(delta):
	# Handle regeneration timing
	if has_been_damaged and not is_dead and not is_regenerating:
		regeneration_timer += delta
		if regeneration_timer >= regeneration_delay:
			start_regeneration()

func take_damage(damage: int):
	if is_dead:
		return
	
	print("Blue Block took ", damage, " damage (", current_health - damage, "/", max_health, " remaining)")
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Change sprite to cracked version after first damage (first life lost)
	if not has_been_damaged and current_health < max_health:
		change_to_cracked_sprite()
		has_been_damaged = true
		regeneration_timer = 0.0  # Start regeneration timer
		print("Blue Block lost first life - now cracked!")
	
	# Stop any ongoing regeneration
	if is_regenerating:
		stop_regeneration()
	
	# Reset regeneration timer on damage
	regeneration_timer = 0.0
	
	# Visual damage feedback
	show_damage_effect()
	
	# Emit hit signal
	block_hit.emit(damage)
	
	# Check if dead (second life lost)
	if current_health <= 0:
		die()

# Laser damage method (no score awarded)
func take_laser_damage(damage: int):
	if is_dead:
		return
	
	print("Blue Block took ", damage, " laser damage (no score on death)")
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Change sprite to cracked version after first damage
	if not has_been_damaged and current_health < max_health:
		change_to_cracked_sprite()
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

func change_to_cracked_sprite():
	"""Change the sprite to the cracked version"""
	if sprite and cracked_texture:
		sprite.texture = cracked_texture
		print("Blue Block changed to cracked sprite")
	else:
		print("WARNING: Could not change to cracked sprite - missing sprite or texture")

func start_regeneration():
	"""Start the regeneration process"""
	if is_dead or is_regenerating:
		return
	
	is_regenerating = true
	print("Blue Block starting regeneration...")
	
	# Create regeneration tween
	regeneration_tween = create_tween()
	regeneration_tween.set_loops()  # Loop indefinitely
	
	# Pulse green during regeneration
	regeneration_tween.tween_property(sprite, "modulate", Color.GREEN, regeneration_pulse_time / 2)
	regeneration_tween.tween_property(sprite, "modulate", original_color, regeneration_pulse_time / 2)
	
	# Wait for the pulsing period, then heal
	await get_tree().create_timer(regeneration_pulse_time * 3).timeout  # Pulse 3 times
	
	if is_regenerating:  # Check if still regenerating (not interrupted)
		complete_regeneration()

func complete_regeneration():
	"""Complete the regeneration and restore to full health"""
	if is_dead:
		return
	
	print("Blue Block regeneration complete!")
	
	# Restore to full health
	current_health = max_health
	has_been_damaged = false
	regeneration_timer = 0.0
	
	# Change back to normal sprite
	if sprite and normal_texture:
		sprite.texture = normal_texture
	
	# Stop regeneration
	stop_regeneration()
	
	# Flash bright green to indicate full regeneration
	var heal_tween = create_tween()
	heal_tween.tween_property(sprite, "modulate", Color.LIME_GREEN, 0.2)
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
	
	print("Blue Block regeneration stopped")

func die():
	if is_dead:
		return
	
	is_dead = true
	print("Blue Block died! Awarding ", score_value, " points")
	
	# Emit death signal with score
	block_died.emit(score_value)
	
	play_death_effect()

# Silent death method (no score awarded)
func die_silently():
	"""Die without awarding score - used for laser kills"""
	if is_dead:
		return
	
	is_dead = true
	print("Blue Block destroyed by laser (no score awarded)")
	
	# Stop regeneration
	if is_regenerating:
		stop_regeneration()
	
	# VIKTIG FIX: Skicka ändå signal så att enemies_killed räknaren uppdateras
	# Vi skickar 0 poäng istället för score_value
	block_died.emit(0)
	
	play_death_effect()

func show_damage_effect():
	if not sprite:
		return
	
	# Don't show damage effect if regenerating (green pulse takes priority)
	if is_regenerating:
		return
	
	# Flash blue when hit (matching block color)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.CYAN, 0.1)
	tween.tween_property(sprite, "modulate", original_color, 0.1)

func play_death_effect():
	if not sprite:
		queue_free()
		return
	
	# Disable collision immediately
	if collision_shape:
		collision_shape.disabled = true
	
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
