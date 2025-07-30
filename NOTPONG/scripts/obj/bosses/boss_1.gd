extends CharacterBody2D

# Enemy settings
@export var max_health: int = 200
@export var score_value: int = 500  # Points awarded when killed
@export var enemy_type: String = "boss"

# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")

# Internal variables
var current_health: int
var is_dead: bool = false
var original_color: Color

# Signals
signal boss_died(score_points: int)
signal boss_hit(damage: int)

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
	boss_hit.emit(damage)
	
	# Check if dead
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	print("Enemy died! Awarding ", score_value, " points")
	
	# Emit death signal with score
	boss_died.emit(score_value)
	
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
