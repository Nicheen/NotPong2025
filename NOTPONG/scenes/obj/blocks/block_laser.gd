extends StaticBody2D

# Enemy settings
@export var max_health: int = 20
@export var score_value: int = 30  # Points awarded when killed
@export var enemy_type: String = "laser"

# laser settings
@export var laser_activation_delay: float = 2.0  # Time before laser activates
@export var laser_duration: float = 3.0  # How long laser stays active
@export var laser_damage_per_second: float = 10.0
@export var laser_damage_interval: float = 0.1

# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var laser := $LaserBeam2D

# Sprite textures
var normal_texture: Texture2D
var cracked_texture: Texture2D

# laser effect
var laser_timer: float = 0.0
var laser_duration_timer: float = 0.0
var laser_damage_timer: float = 0.0
var laser_activated: bool = false
var laser_ready: bool = false

# Regeneration settings
@export var regeneration_delay: float = 3.0  # Time before regeneration starts
@export var regeneration_pulse_time: float = 1.0  # Time spent pulsing before healing

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
	# Set up enemy
	current_health = max_health
	
	# Store original sprite color and texture
	if sprite:
		original_color = sprite.modulate
		normal_texture = sprite.texture
		
		# Load the cracked texture
		cracked_texture = load("res://images/BlocklaserCracked.png")
		if not cracked_texture:
			print("WARNING: Could not load cracked texture at res://images/BlocklaserCracked.png")
	
	if laser:
		laser.collision_mask = 1 + 16
	
	laser_ready = true
	
	print("laser block created with ", max_health, " health at position: ", global_position)

func _physics_process(delta):
	# Handle laser timing
	if laser_ready and not laser_activated and not is_dead:
		laser_timer += delta
		if laser_timer >= laser_activation_delay:
			activate_laser()
			
	# Handle laser duration
	if laser_activated and not is_dead:
		laser_duration_timer += delta
		
		# NEW: Handle continuous laser damage
		if laser.is_colliding():
			laser_damage_timer += delta
			if laser_damage_timer >= laser_damage_interval:
				apply_laser_damage()
				laser_damage_timer = 0.0  # Reset damage timer
		else:
			laser_damage_timer = 0.0  # Reset if not hitting anything
		
		# Check if laser duration is over
		if laser_duration_timer >= laser_duration:
			deactivate_laser()
			# Reset for next cycle
			laser_timer = 0.0
			laser_ready = true
			
	# Handle regeneration timing
	if has_been_damaged and not is_dead and not is_regenerating:
		regeneration_timer += delta
		if regeneration_timer >= regeneration_delay:
			start_regeneration()
			
func apply_laser_damage():
	"""Apply continuous damage to whatever the laser is hitting"""
	if not laser.is_colliding():
		return
		
	var hit_body = laser.get_collider()
	if not hit_body or not hit_body.has_method("take_damage"):
		return
	
	# Calculate damage for this interval
	var damage_amount = laser_damage_per_second * laser_damage_interval
	
	# Check what we're hitting
	if hit_body.collision_layer == 16:  # It's a block
		# Use the new silent damage method for blocks
		if hit_body.has_method("take_laser_damage"):
			hit_body.take_laser_damage(damage_amount)
			print("laser dealing ", damage_amount, " damage to block (no score)")
		else:
			# Fallback to regular damage if the method doesn't exist
			hit_body.take_damage(damage_amount)
			print("laser dealing ", damage_amount, " damage to block (with score - fallback)")
		
	elif hit_body.collision_layer == 1:  # It's the player
		hit_body.take_damage(damage_amount)
		print("laser dealing ", damage_amount, " damage to player")
		
func activate_laser():
	"""Activate the laser effect"""
	laser_activated = true
	laser_duration_timer = 0.0
	laser_damage_timer = 0.0
	laser.is_casting = true
	
	print("laser activated on laser block at: ", global_position)

func deactivate_laser():
	"""Deactivate the laser effect"""
	laser_activated = false
	laser_duration_timer = 0.0
	laser_damage_timer = 0.0
	laser.is_casting = false
	
	print("laser deactivated on laser block")

func take_damage(damage: int):
	if is_dead:
		return
	
	print("laser block took ", damage, " damage")
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Change sprite to cracked version after first damage
	if not has_been_damaged and current_health < max_health:
		change_to_cracked_sprite()
		has_been_damaged = true
		regeneration_timer = 0.0  # Start regeneration timer
	
	# Stop any ongoing regeneration
	if is_regenerating:
		stop_regeneration()
	
	# Reset regeneration timer on damage
	regeneration_timer = 0.0
	
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
	
	print("laser block took ", damage, " laser damage (no score on death)")
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Change sprite to cracked version after first damage
	if not has_been_damaged and current_health < max_health:
		change_to_cracked_sprite()
		has_been_damaged = true
		regeneration_timer = 0.0  # Start regeneration timer
	
	# Stop any ongoing regeneration
	if is_regenerating:
		stop_regeneration()
	
	# Reset regeneration timer on damage
	regeneration_timer = 0.0
	
	# Visual damage feedback
	show_damage_effect()
	
	# Emit hit signal (still show damage feedback)
	block_hit.emit(damage)
	
	# Check if dead - but call the silent death method
	if current_health <= 0:
		die_silently()

func die():
	if is_dead:
		return
	
	is_dead = true
	print("laser block died! Awarding ", score_value, " points")
	
	laser.is_casting = false

	# Emit death signal with score
	block_died.emit(score_value)
	
	play_death_effect()

# NEW: Silent death method (no score awarded)
func die_silently():
	"""Die without awarding score - used for laser kills"""
	if is_dead:
		return
	
	is_dead = true
	print("Laser block destroyed by laser (no score awarded)")
	
	laser.is_casting = false
	
	# VIKTIG FIX: Skicka ändå signal så att enemies_killed räknaren uppdateras
	# Vi skickar 0 poäng istället för score_value
	block_died.emit(0)
	
	# Play the death effect
	play_death_effect()

func change_to_cracked_sprite():
	"""Change the sprite to the cracked version"""
	if sprite and cracked_texture:
		sprite.texture = cracked_texture
		print("Changed to cracked sprite")
	else:
		print("WARNING: Could not change to cracked sprite - missing sprite or texture")

func show_damage_effect():
	if not sprite:
		return
	
	# Don't show damage effect if regenerating (green pulse takes priority)
	if is_regenerating:
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

# Method called when projectile hits this enemy
func _on_projectile_hit():
	take_damage(10)  # Default damage from projectiles

# Regeneration system functions
func start_regeneration():
	"""Start the regeneration process with green pulsing"""
	if is_dead or not has_been_damaged:
		return
	
	is_regenerating = true
	print("Starting regeneration - pulsing green for ", regeneration_pulse_time, " seconds")
	
	# Start green pulsing effect
	regeneration_tween = create_tween()
	regeneration_tween.set_loops()
	regeneration_tween.tween_property(sprite, "modulate", Color.GREEN, 0.3)
	regeneration_tween.tween_property(sprite, "modulate", original_color, 0.3)
	
	# After pulse time, complete the regeneration
	var regeneration_complete_timer = Timer.new()
	regeneration_complete_timer.wait_time = regeneration_pulse_time
	regeneration_complete_timer.one_shot = true
	regeneration_complete_timer.timeout.connect(complete_regeneration)
	add_child(regeneration_complete_timer)
	regeneration_complete_timer.start()

func complete_regeneration():
	"""Complete the regeneration process"""
	if is_dead:
		return
	
	print("Regeneration complete - restored to full health")
	
	# Restore health
	current_health = max_health
	has_been_damaged = false
	regeneration_timer = 0.0
	
	# Change back to normal sprite
	if sprite and normal_texture:
		sprite.texture = normal_texture
	
	# Stop regeneration effects
	stop_regeneration()

func stop_regeneration():
	"""Stop the regeneration process"""
	is_regenerating = false
	
	# Stop pulsing tween
	if regeneration_tween and regeneration_tween.is_valid():
		regeneration_tween.kill()
		regeneration_tween = null
	
	# Reset sprite color
	if sprite:
		sprite.modulate = original_color
