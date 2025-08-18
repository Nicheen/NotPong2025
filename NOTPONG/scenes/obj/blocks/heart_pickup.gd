# heart_pickup.gd
extends AnimatableBody2D

# Heart settings
@export var health_restore: int = 10
@export var max_health: int = 10
@export var fall_speed: float = 0.0

# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionPolygon2D = $CollisionPolygon2D

# Internal variables
var current_health: int
var is_dead: bool = false
var velocity: Vector2 = Vector2.ZERO

func _ready():
	# Set up heart
	current_health = max_health
	velocity = Vector2(0, fall_speed)  # Fall downward
	
	print("Heart pickup created with ", max_health, " health at position: ", global_position)

func _physics_process(delta):
	if is_dead:
		return
	
	# Move the heart downward
	global_position += velocity * delta
	
	# Remove heart if it goes off screen
	if global_position.y > get_viewport().get_visible_rect().size.y + 50:
		queue_free()

func take_damage(damage: int):
	if is_dead:
		return
	
	print("Heart took ", damage, " damage")
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Visual damage feedback
	show_damage_effect()
	
	# Check if dead
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	print("Heart destroyed - healing player!")
	
	# Heal the player
	heal_player()
	
	# Simple destruction effect
	show_destruction_effect()
	
	# Remove from scene
	queue_free()

func heal_player():
	"""Find the player and heal them"""
	var player = find_player_in_scene()
	
	if player and player.has_method("heal") and player.has_method("get_health") and player.has_method("get_max_health"):
		var current_hp = player.get_health()
		var max_hp = player.get_max_health()
		var new_hp = min(current_hp + health_restore, max_hp)
		
		# Set health to the new value (capped at max)
		var actual_heal = new_hp - current_hp
		if actual_heal > 0:
			player.heal(actual_heal)
			
			# Update health bar manually since player.heal() doesn't do it
			if "health_bar" in player and player.health_bar:
				player.health_bar.value = player.get_health()
			
			print("Healed player for ", actual_heal, " HP (", current_hp, " -> ", new_hp, ")")
		else:
			print("Player already at max health!")
	else:
		print("Could not find player to heal!")

func find_player_in_scene():
	"""Find the player using multiple methods"""
	var scene_root = get_tree().current_scene
	
	# Method 1: Look for node named "Player"
	var player = scene_root.find_child("Player", true, false)
	if player:
		return player
	
	# Method 2: Look for CharacterBody2D with collision_layer 1 (usually player)
	for child in scene_root.get_children():
		if child is CharacterBody2D and child.collision_layer == 1:
			return child
	
	# Method 3: Check if main.gd has a player reference
	if "player" in scene_root:
		var player_ref = scene_root.get("player")
		if player_ref:
			return player_ref
	
	return null

func show_damage_effect():
	"""Flash the heart when hit"""
	if sprite:
		sprite.modulate = Color.WHITE
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.2)

func show_destruction_effect():
	"""Simple destruction effect"""
	if sprite:
		var tween = create_tween()
		tween.parallel().tween_property(sprite, "modulate", Color.GREEN, 0.3)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.3)
