# heart_pickup.gd
extends AnimatableBody2D

# Heart settings
@export var health_restore: int = 20
@export var max_health: int = 10
@export var fall_speed: float = 0.0

# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionPolygon2D = $CollisionPolygon2D

# Internal variables
var current_health: int
var is_dead: bool = false
var velocity: Vector2 = Vector2.ZERO

signal heart_destroyed  # Signal för när heart förstörs utan att samlas in
var registered_in_main: bool = false

func _ready():
	# Set up heart
	current_health = max_health
	velocity = Vector2(0, fall_speed)  # Fall downward
	
	# Registrera denna heart pickup i main scene
	register_with_main_scene()
	
	print("Heart pickup created with ", max_health, " health at position: ", global_position)

func _physics_process(delta):
	if is_dead:
		return
	
	# Move the heart downward
	global_position += velocity * delta
	
	# Remove heart if it goes off screen
	if global_position.y > get_viewport().get_visible_rect().size.y + 50:
		remove_from_main_scene()  # Ta bort från array innan queue_free
		queue_free()
		
func register_with_main_scene():
	"""Registrera denna heart pickup i main scene så den kan rensas vid level completion"""
	var main_scene = get_tree().current_scene
	
	if main_scene and main_scene.has_method("register_heart_pickup"):
		main_scene.register_heart_pickup(self)
		registered_in_main = true
		print("Heart pickup registered with main scene")
	else:
		print("Warning: Could not register heart pickup with main scene")
		
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
	
	var blop_sounds = [
		preload("res://audio/noels/blop1.wav"),
		preload("res://audio/noels/blop2.wav"),
		preload("res://audio/noels/blop3.wav")
	]
	
	# Pick a random sound and play it
	var random_sound = blop_sounds[randi() % blop_sounds.size()]
	GlobalAudioManager.play_sfx(random_sound)
	is_dead = true
	print("Heart destroyed - healing player!")
	
	# Heal the player
	heal_player()
	
	# Ta bort från main scene array
	remove_from_main_scene()
	
	# Simple destruction effect
	show_destruction_effect()
	
	# Remove from scene
	queue_free()

func remove_from_main_scene():
	"""Ta bort denna heart pickup från main scene array när den förstörs"""
	var main_scene = get_tree().current_scene
	
	if main_scene and "heart_pickups" in main_scene:
		var heart_array = main_scene.heart_pickups
		var index = heart_array.find(self)
		if index != -1:
			heart_array.remove_at(index)
			print("Removed heart pickup from main scene array")
			
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
