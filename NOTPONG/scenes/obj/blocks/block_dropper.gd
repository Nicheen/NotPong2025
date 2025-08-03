extends StaticBody2D

# Enemy settings
@export var max_health: int = 20
@export var score_value: int = 20
@export var enemy_type: String = "basic"
@export var projectile_scene: PackedScene = load("res://scenes/obj/Projectile.tscn")
@export var projectile_speed: float = 200.0
@export var shoot_interval: float = 4.0  # Time between drops
@export var warning_time: float = 1.5    # Warning time before drop
@export var min_drop_interval: float = 3.0  # Minsta tid mellan drops
@export var max_drop_interval: float = 6.0  # Längsta tid mellan drops
# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var current_drop_interval: float = 0.0

# Sprite textures
var normal_texture: Texture2D
var cracked_texture: Texture2D

# Shooting system
var shoot_timer: float = 0.0
var warning_timer: float = 0.0
var is_warning_active: bool = false
var warning_blink_speed: float = 0.5  # Start blink speed
var last_blink_time: float = 0.0
var sprite_visible: bool = true

# Regeneration settings
@export var regeneration_delay: float = 3.0
@export var regeneration_pulse_time: float = 1.0

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
signal block_dropper_died(score_points: int)
signal block_dropper_hit(damage: int)

func _ready():
	# Set up enemy
	current_health = max_health
	
	# Set collision layer for enemy (layer 5)
	collision_layer = 16  # Layer 5 (2^4 = 16)
	collision_mask = 2    # Can be hit by projectiles (layer 2)
	randomize_drop_interval()

	# Store original sprite color and texture
	if sprite:
		original_color = sprite.modulate
		normal_texture = sprite.texture
		
		# Load the cracked texture
		cracked_texture = load("res://images/BlockDropperCracked.png")
		if not cracked_texture:
			print("WARNING: Could not load cracked texture at res://images/BlockDropperCracked.png")
	
	print("Block Dropper created with ", max_health, " health at position: ", global_position)

func _physics_process(delta):
	# Handle regeneration timing
	if has_been_damaged and not is_dead and not is_regenerating:
		regeneration_timer = delta
		if regeneration_timer >= regeneration_delay:
			start_regeneration()
	
	# Handle shooting timing
	shoot_timer += delta
	
	# Check if we should start warning
	if not is_warning_active and shoot_timer >= (shoot_interval - warning_time):
		start_warning()
	
	# Handle warning blinks
	if is_warning_active and not is_regenerating:
		handle_warning_blinks(delta)
	
	# Check if we should drop projectile
	if shoot_timer >= shoot_interval:
		drop_projectile()
	
	shoot_timer += delta
	
	# Check if we should start warning (använd current_drop_interval istället för shoot_interval)
	if not is_warning_active and shoot_timer >= (current_drop_interval - warning_time):
		start_warning()
	
	# Handle warning blinks
	if is_warning_active and not is_regenerating:
		handle_warning_blinks(delta)
	
	# Check if we should drop projectile (använd current_drop_interval)
	if shoot_timer >= current_drop_interval:
		drop_projectile()
func randomize_drop_interval():
	"""Sätt en ny random drop interval för denna dropper"""
	current_drop_interval = randf_range(min_drop_interval, max_drop_interval)
	print("Block Dropper will drop in ", current_drop_interval, " seconds")
	
func start_warning():
	"""Start the warning indicator before dropping projectile"""
	is_warning_active = true
	warning_timer = 0.0
	warning_blink_speed = 0.5  # Start slow
	print("Warning started - projectile dropping in ", warning_time, " seconds!")

func handle_warning_blinks(delta):
	"""Handle the accelerating blink effect"""
	warning_timer += delta
	
	# Calculate how far through the warning we are (0.0 to 1.0)
	var warning_progress = warning_timer / warning_time
	
	# Accelerate blink speed as we get closer to drop time
	# Start at 0.5 seconds, end at 0.1 seconds
	var current_blink_speed = lerp(0.5, 0.1, warning_progress)
	
	# Handle blinking
	last_blink_time += delta
	if last_blink_time >= current_blink_speed:
		toggle_sprite_visibility()
		last_blink_time = 0.0

func toggle_sprite_visibility():
	"""Toggle sprite color for warning effect - red pulsing like regeneration"""
	if not sprite or is_regenerating:
		return
	
	sprite_visible = !sprite_visible
	
	if sprite_visible:
		sprite.modulate = Color.RED  # Red warning
	else:
		sprite.modulate = original_color  # Normal color

func stop_warning():
	"""Stop the warning effect and restore normal appearance"""
	is_warning_active = false
	warning_timer = 0.0
	sprite_visible = true
	
	if sprite and not is_regenerating:
		sprite.modulate = original_color

func drop_projectile():
	"""Drop a projectile straight down"""
	if is_dead:
		return
	
	print("Dropping projectile!")
	
	# Stop warning effect
	stop_warning()
	randomize_drop_interval()

	# Reset shoot timer
	shoot_timer = 0.0
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	
	# Position it just below the block dropper
	var spawn_position = global_position + Vector2(0, 40)
	projectile.global_position = spawn_position
	
	# Add to scene first
	get_tree().current_scene.add_child(projectile)
	
	# Wait one frame then initialize
	await get_tree().process_frame
	
	# Initialize projectile to move straight down (enemy projectile)
	var drop_direction = Vector2(0, 1)  # Straight down
	projectile.initialize(drop_direction, projectile_speed, Vector2.ZERO, Vector2.ZERO, true)
	
	# CRITICAL FIX: Remove auto-destroy timer and disable bounce limits
	if projectile.has_method("disable_auto_destroy"):
		projectile.disable_auto_destroy()
	else:
		# Manual fix - find and remove the timer
		for child in projectile.get_children():
			if child is Timer:
				child.queue_free()
				print("Removed auto-destroy timer from enemy projectile")
	
	# Also disable bounce limit and boundary destruction
	if projectile.collision_handler:
		projectile.collision_handler.max_bounces = 3
	
	print("Projectile dropped successfully with no time limit")

func take_damage(damage: int):
	if is_dead:
		return
	
	print("Block Dropper took ", damage, " damage")
	
	current_health -= damage
	shoot_timer -= 1
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
	
	# Emit hit signal
	block_dropper_hit.emit(damage)
	
	# Check if dead
	if current_health <= 0:
		die()

func take_laser_damage(damage: int):
	"""Take damage from laser without awarding score when destroyed"""
	if is_dead:
		return
	
	print("Block Dropper took ", damage, " laser damage (no score on death)")
	
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
		print("Changed to cracked sprite")
	else:
		print("WARNING: Could not change to cracked sprite - missing sprite or texture")

func die():
	if is_dead:
		return
	is_dead = true
	print("Block Dropper died! Awarding ", score_value, " points")
	
	# Stop any warning effects
	stop_warning()
	
	# Emit death signal with score
	block_dropper_died.emit(score_value)
	
	play_death_effect()

func die_silently():
	"""Die without awarding score - used for laser kills"""
	if is_dead:
		return
	
	is_dead = true
	print("Block Dropper destroyed by laser (no score awarded)")
	
	# Stop any warning effects
	stop_warning()
	
	# Send signal with 0 points so enemies_killed counter still updates
	block_dropper_died.emit(0)
	
	play_death_effect()

func show_damage_effect():
	if not sprite:
		return
	
	# Don't show damage effect if regenerating (green pulse takes priority)
	if is_regenerating:
		return
	
	# Temporarily stop warning effect for damage flash
	var was_warning = is_warning_active
	if was_warning:
		stop_warning()
	
	# Flash red when hit
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", original_color, 0.1)
	
	# Resume warning if it was active
	if was_warning:
		await tween.finished
		start_warning()

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
	tween.set_parallel(true)
	
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
	take_damage(10)

# Regeneration system functions
func start_regeneration():
	"""Start the regeneration process with green pulsing"""
	if is_dead or not has_been_damaged:
		return
	
	is_regenerating = true
	print("Starting regeneration - pulsing green for ", regeneration_pulse_time, " seconds")
	
	# Stop warning effect during regeneration
	var was_warning = is_warning_active
	if was_warning:
		stop_warning()
	
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
