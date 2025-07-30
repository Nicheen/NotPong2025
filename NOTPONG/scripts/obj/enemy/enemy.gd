extends CharacterBody2D

# Enemy settings
@export var max_health: int = 30
@export var score_value: int = 100  # Points awarded when killed
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
signal enemy_died(score_points: int)
signal enemy_hit(damage: int)

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
	# Basic enemy doesn't move, but you can add movement here
	# For now, just ensure it stays in place
	if not is_dead:
		velocity = Vector2.ZERO
		move_and_slide()

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
	enemy_hit.emit(damage)
	
	# Check if dead
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	print("Enemy died! Awarding ", score_value, " points")
	
	# Emit death signal with score
	enemy_died.emit(score_value)
	
	# Play death effect
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
	
	# Create explosion effect with sequential phases
	var tween = create_tween()
	
	# Phase 1: Quick expansion and flash to yellow (explosion start)
	tween.parallel().tween_property(sprite, "scale", sprite.scale * 1.8, 0.15)
	tween.parallel().tween_property(sprite, "modulate", Color.YELLOW, 0.1)
	
	# Phase 2: Bright flash to white (explosion peak)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	
	# Phase 3: Rapid expansion with color change (explosion expansion)
	tween.parallel().tween_property(sprite, "scale", sprite.scale * 3.5, 0.2)
	tween.parallel().tween_property(sprite, "modulate", Color.ORANGE, 0.15)
	
	# Phase 4: Final expansion and fade (explosion dissipation)
	tween.parallel().tween_property(sprite, "scale", sprite.scale * 5.0, 0.25)
	tween.parallel().tween_property(sprite, "modulate", Color.TRANSPARENT, 0.25)
	
	# Optional: Add some particles or additional visual effects
	create_explosion_particles()
	
	# Wait for animation then destroy
	await tween.finished
	queue_free()

# Optional: Create simple particle-like effects for explosion
func create_explosion_particles():
	# Create several small "debris" sprites that fly outward
	for i in range(6):
		var particle = Sprite2D.new()
		particle.texture = sprite.texture
		particle.scale = Vector2(0.1, 0.1)
		particle.modulate = Color.ORANGE
		particle.global_position = global_position
		
		# Add to parent scene
		get_parent().add_child(particle)
		
		# Random direction and distance
		var angle = randf() * TAU  # Full circle in radians
		var distance = randf_range(50, 150)
		var target_pos = global_position + Vector2(cos(angle), sin(angle)) * distance
		
		# Animate particle
		var particle_tween = create_tween()
		particle_tween.set_parallel(true)
		particle_tween.tween_property(particle, "global_position", target_pos, 0.4)
		particle_tween.tween_property(particle, "modulate", Color.TRANSPARENT, 0.4)
		particle_tween.tween_property(particle, "scale", Vector2.ZERO, 0.4)
		
		# Clean up particle
		particle_tween.finished.connect(func(): particle.queue_free())

# Alternative simpler explosion effect (if you prefer less particles)
func play_simple_explosion_effect():
	if not sprite:
		queue_free()
		return
	
	# Disable collision
	if collision_shape:
		collision_shape.disabled = true
	if health_bar:
		health_bar.visible = false
	
	# Simple but effective explosion
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Quick flash and expand
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "scale", sprite.scale * 2.5, 0.2)
	
	# Fade to orange/red and continue expanding
	tween.tween_property(sprite, "modulate", Color.ORANGE_RED, 0.15)
	tween.tween_property(sprite, "scale", sprite.scale * 4.0, 0.3)
	
	# Final fade out
	tween.tween_property(sprite, "modulate", Color.TRANSPARENT, 0.2)
	
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
