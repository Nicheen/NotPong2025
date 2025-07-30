extends CharacterBody2D

# Enemy settings
@export var max_health: int = 20
@export var score_value: int = 20  # Points awarded when killed
@export var enemy_type: String = "lazer"

# Thunder settings
@export var thunder_activation_delay: float = 2.0  # Time before thunder activates
@export var thunder_duration: float = 3.0  # How long thunder stays active
@export var thunder_direction: String = "vertical"  # "vertical" or "horizontal"

# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")

# Thunder effect
var thunder_effect: Node2D
var thunder_timer: float = 0.0
var thunder_duration_timer: float = 0.0
var thunder_activated: bool = false
var thunder_ready: bool = false

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
	
	# Find thunder effect (should be a child of this block)
	thunder_effect = get_node_or_null("VFX_Thunder")
	if thunder_effect:
		setup_thunder_effect()
		# Start the thunder activation timer
		thunder_ready = true
		print("Thunder effect found and configured")
	else:
		print("WARNING: No thunder effect found on laser block")
	
	print("Laser block created with ", max_health, " health at position: ", global_position)

func _physics_process(delta):
	# Basic enemy doesn't move
	if not is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
	
	# Handle thunder timing
	if thunder_ready and not thunder_activated and not is_dead:
		thunder_timer += delta
		if thunder_timer >= thunder_activation_delay:
			activate_thunder()

func setup_thunder_effect():
	"""Configure the thunder effect for this laser block"""
	if not thunder_effect:
		return
	
	# Add the thunder controller script if it doesn't have one
	if not thunder_effect.get_script():
		var thunder_script = load("res://scripts/effects/thunder_controller.gd")  # You'll need to save the script here
		if thunder_script:
			thunder_effect.set_script(thunder_script)
	
	# Make sure thunder starts hidden
	thunder_effect.visible = false

func activate_thunder():
	"""Activate the thunder effect"""
	if not thunder_effect or thunder_activated:
		return
	
	thunder_activated = true
	thunder_duration_timer = 0.0
	
	# Make thunder visible and configure it
	thunder_effect.visible = true
	
	# Choose thunder direction and activate
	if thunder_direction == "horizontal":
		if thunder_effect.has_method("activate_horizontal_thunder"):
			thunder_effect.activate_horizontal_thunder()
	else:
		if thunder_effect.has_method("activate_vertical_thunder"):
			thunder_effect.activate_vertical_thunder()
	
	print("Thunder activated on laser block at: ", global_position)

func deactivate_thunder():
	"""Deactivate the thunder effect"""
	if not thunder_effect or not thunder_activated:
		return
	
	if thunder_effect.has_method("deactivate_thunder"):
		thunder_effect.deactivate_thunder()
	
	thunder_activated = false
	thunder_ready = false  # Prevent reactivation
	
	print("Thunder deactivated on laser block")

func take_damage(damage: int):
	if is_dead:
		return
	
	print("Laser block took ", damage, " damage")
	
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

func die():
	if is_dead:
		return
	
	is_dead = true
	print("Laser block died! Awarding ", score_value, " points")
	
	# Deactivate thunder before dying
	if thunder_activated:
		deactivate_thunder()
	
	# Emit death signal with score
	block_died.emit(score_value)
	
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
