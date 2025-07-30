class_name ProjectileBoundaryHandler
extends Node

# Velocity settings
var min_velocity: float = 50.0

# World boundaries
var world_bounds: Rect2

# Reference to parent projectile
var projectile: RigidBody2D

func _ready():
	# Get reference to parent projectile when component is ready
	# Components are children of the Components node, so we need get_parent().get_parent()
	projectile = get_parent().get_parent() as RigidBody2D

func initialize(bounds: Rect2):
	world_bounds = bounds
	print("Boundary handler initialized with bounds: ", bounds)

func update_bounds(new_bounds: Rect2):
	world_bounds = new_bounds
	print("Updated bounds to: ", new_bounds)

func check_boundaries():
	if not projectile:
		return
		
	var pos = projectile.global_position
	var vel = projectile.linear_velocity
	var bounced = false
	var new_velocity = vel
	var new_position = pos
	
	# Add some margin to prevent getting stuck at boundaries
	var margin = 15.0
	
	# Check left boundary
	if pos.x <= world_bounds.position.x + margin:
		new_velocity.x = abs(new_velocity.x)  # Force positive (rightward)
		new_position.x = world_bounds.position.x + margin + 5
		bounced = true
		print("Hit left boundary at x=", pos.x)
	
	# Check right boundary
	elif pos.x >= (world_bounds.position.x + world_bounds.size.x) - margin:
		new_velocity.x = -abs(new_velocity.x)  # Force negative (leftward)
		new_position.x = (world_bounds.position.x + world_bounds.size.x) - margin - 5
		bounced = true
		print("Hit right boundary at x=", pos.x)
	
	# Check top boundary
	if pos.y <= world_bounds.position.y + margin:
		new_velocity.y = abs(new_velocity.y)  # Force positive (downward)
		new_position.y = world_bounds.position.y + margin + 5
		bounced = true
		print("Hit top boundary at y=", pos.y)
	
	# Check bottom boundary
	elif pos.y >= (world_bounds.position.y + world_bounds.size.y) - margin:
		new_velocity.y = -abs(new_velocity.y)  # Force negative (upward)
		new_position.y = (world_bounds.position.y + world_bounds.size.y) - margin - 5
		bounced = true
		print("Hit bottom boundary at y=", pos.y)
	
	if bounced:
		# Add small random variation to prevent infinite bouncing patterns
		var random_variation = Vector2(
			randf_range(-0.1, 0.1),
			randf_range(-0.1, 0.1)
		)
		new_velocity = (new_velocity + random_variation * 50.0).normalized() * new_velocity.length()
		
		print("Boundary bounce - Old velocity: ", vel, " New velocity: ", new_velocity)
		projectile.handle_bounce(new_velocity, new_position)

func maintain_minimum_velocity():
	if not projectile:
		return
		
	var current_velocity = projectile.linear_velocity.length()
	if current_velocity > 0 and current_velocity < min_velocity:
		# Boost velocity to minimum while maintaining direction
		var velocity_direction = projectile.linear_velocity.normalized()
		projectile.linear_velocity = velocity_direction * min_velocity
		print("Boosted velocity from ", current_velocity, " to ", min_velocity)

func get_distance_to_bounds() -> float:
	if not projectile:
		return 999.0
		
	var pos = projectile.global_position
	var distances = [
		pos.x - world_bounds.position.x,  # Left
		(world_bounds.position.x + world_bounds.size.x) - pos.x,  # Right
		pos.y - world_bounds.position.y,  # Top
		(world_bounds.position.y + world_bounds.size.y) - pos.y   # Bottom
	]
	
	# Return the smallest distance (closest to any boundary)
	return distances.min()
