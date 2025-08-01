class_name ProjectileCollisionHandler
extends Node

# Bounce settings
var bounce_damping: float = 0.8
var max_bounces: int = 3
var current_bounces: int = 0

# Reference to parent projectile
var projectile: RigidBody2D

func _ready():
	# Get reference to parent projectile when component is ready
	# Components are children of the Components node, so we need get_parent().get_parent()
	projectile = get_parent().get_parent() as RigidBody2D

func initialize():
	# No longer needed - _ready() handles the reference
	pass

func handle_collision(body):
	print("Projectile collided with: ", body.name, " on layer: ", body.collision_layer)
	
	# Check collision type and handle accordingly
	if is_player_target(body):
		handle_player_hit(body)
	elif is_enemy_target(body):
		handle_enemy_hit(body)
	elif body.collision_layer == 4:  # Wall layer
		handle_wall_collision(body)
	elif body.collision_layer == 2:  # Lava zone or another projectile
		# Check if it's actually a projectile or a lava zone StaticBody2D
		if body is RigidBody2D:
			handle_projectile_collision(body)
		else:
			# This is a lava zone StaticBody2D
			handle_lava_collision(body)
	else:
		handle_generic_collision(body)
		
func handle_lava_collision(lava_body):
	print("Hit lava zone - damaging player and destroying projectile")
	
	# Find and damage the player
	var scene_root = projectile.get_tree().current_scene
	var player = scene_root.find_child("Player", true, false)
	
	if player and player.has_method("take_damage"):
		player.take_damage(20)  # Lava damage amount
		print("Player damaged by lava projectile!")
	
	# Destroy the projectile
	projectile.queue_free()
	
func handle_player_hit(player_body):
	print("Hit player - reflecting projectile")
	
	# Calculate reflection direction away from player
	var player_pos = player_body.global_position
	var projectile_pos = projectile.global_position
	var reflection_direction = (projectile_pos - player_pos).normalized()
	
	# Apply reflection with some randomness
	var random_angle = randf_range(-0.1, 0.1)
	reflection_direction = reflection_direction.rotated(random_angle)
	
	# Set new velocity (maintain speed but change direction)
	var current_speed = projectile.linear_velocity.length()
	projectile.linear_velocity = reflection_direction * current_speed
	
	# Mark as player projectile after reflection
	projectile.is_player_projectile = true

func handle_enemy_hit(enemy_body):
	print("Hit enemy - destroying projectile immediately")
	if enemy_body.has_method("take_damage"):
		enemy_body.take_damage(10)
	projectile.queue_free()

func handle_projectile_collision(other_projectile):
	print("=== PROJECTILE COLLISION DETECTED ===")
	
	# Check if this is a defensive save
	var is_defensive_save = check_if_defensive_save(other_projectile)
	
	# Get collision data
	var collision_point = (projectile.global_position + other_projectile.global_position) * 0.5
	var my_velocity = projectile.linear_velocity
	var other_velocity = other_projectile.linear_velocity
	
	print("Collision at: ", collision_point)
	print("My velocity: ", my_velocity, " Other velocity: ", other_velocity)
	
	# Create explosion effect
	projectile.create_explosion_at(collision_point, my_velocity, other_velocity)
	
	# Emit signals for achievement tracking
	projectile.projectile_destroyed_by_collision.emit(is_defensive_save)
	if other_projectile.has_signal("projectile_destroyed_by_collision"):
		other_projectile.projectile_destroyed_by_collision.emit(is_defensive_save)
	
	if is_defensive_save:
		print("DEFENSIVE SAVE ACHIEVED!")
	
	# Destroy both projectiles
	other_projectile.queue_free()
	projectile.queue_free()

func handle_wall_collision(wall_body):
	print("Handling wall bounce with: ", wall_body.name)
	
	var collision_normal = calculate_wall_collision_normal(wall_body)
	var reflected_velocity = projectile.linear_velocity.reflect(collision_normal)
	
	# Add randomness to prevent infinite bouncing
	var random_angle = randf_range(-0.2, 0.2)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply bounce with separation
	var separation_distance = 20.0
	var new_position = projectile.global_position + collision_normal * separation_distance
	
	handle_bounce(reflected_velocity, new_position)

func handle_generic_collision(body):
	print("Hit unknown object - bouncing")
	var new_velocity = -projectile.linear_velocity * bounce_damping
	handle_bounce(new_velocity, projectile.global_position)

func handle_bounce(new_velocity: Vector2, new_position: Vector2):
	current_bounces += 1
	
	# Check bounce limit
	if current_bounces >= max_bounces:
		print("Projectile exceeded max bounces, destroying")
		projectile.queue_free()
		return
	
	# Apply bounce
	projectile.linear_velocity = new_velocity * bounce_damping
	projectile.global_position = new_position
	
	# Emit signal
	projectile.bounced.emit(projectile.global_position)
	
	print("Projectile bounced! Count: ", current_bounces, " New velocity: ", projectile.linear_velocity)

func calculate_wall_collision_normal(wall_body) -> Vector2:
	var collision_normal = Vector2.ZERO
	
	# Try raycast first
	var space_state = projectile.get_world_2d().direct_space_state
	var ray_query = PhysicsRayQueryParameters2D.create(
		projectile.global_position - projectile.linear_velocity.normalized() * 30,
		projectile.global_position + projectile.linear_velocity.normalized() * 30
	)
	ray_query.collision_mask = 8  # Wall layer mask
	ray_query.exclude = [projectile.get_rid()]
	
	var result = space_state.intersect_ray(ray_query)
	if result and result.has("normal"):
		collision_normal = result.normal
		print("Got collision normal from raycast: ", collision_normal)
	else:
		# Fallback: Calculate from positions
		if wall_body and wall_body.has_method("get_global_position"):
			var wall_pos = wall_body.global_position
			collision_normal = (projectile.global_position - wall_pos).normalized()
			print("Calculated normal from positions: ", collision_normal)
		else:
			# Final fallback
			collision_normal = -projectile.linear_velocity.normalized()
			print("Using velocity-based normal: ", collision_normal)
	
	# Validate normal
	if collision_normal.length_squared() < 0.1:
		collision_normal = -projectile.linear_velocity.normalized()
		print("Fixed invalid normal to: ", collision_normal)
	
	return collision_normal

func check_if_defensive_save(other_projectile) -> bool:
	var my_distance = projectile.get_distance_to_bounds()
	var other_distance = other_projectile.get_distance_to_bounds() if other_projectile.has_method("get_distance_to_bounds") else 999.0
	
	var save_threshold = 100.0
	var is_save = my_distance < save_threshold or other_distance < save_threshold
	
	print("Distance to bounds - Me: ", my_distance, " Other: ", other_distance)
	print("Is defensive save: ", is_save)
	
	return is_save

func is_player_target(body) -> bool:
	if body.collision_layer == 1:  # Player layer
		return true
	if body.has_method("take_damage") and "player" in body.name.to_lower():
		return true
	return false

func is_enemy_target(body) -> bool:
	if body.collision_layer == 16:  # Enemy layer
		return true
	if body.has_method("take_damage") and "enemy" in body.name.to_lower():
		return true
	return false
