class_name ProjectileCollisionHandler
extends Node

# Bounce settings
var bounce_damping: float = 0.8
var max_bounces: int = 3
var current_bounces: int = 0
var has_collided: bool = false

# Reference to parent projectile
var projectile: RigidBody2D
@onready var sprite = get_parent().get_parent().get_node("Sprite2D")  # Make sure this path is correct!
@onready var projectile2_texture = preload("res://images/PlayerProjectile2.png")
@onready var projectile3_texture = preload("res://images/PlayerProjectile3.png")
@onready var death_particles: GPUParticles2D = %DeathParticles
@onready var tail_particles: GPUParticles2D = %TailParticles

func _ready():
	# Get reference to parent projectile when component is ready
	# Components are children of the Components node, so we need get_parent().get_parent()
	projectile = get_parent().get_parent() as RigidBody2D
	
func initialize():
	# No longer needed - _ready() handles the reference
	pass

func handle_collision(other_body):
	
	print("[PROJECTILE] Projectile collided with: ", other_body.name, " on layer: ", other_body.collision_layer)
	
	# Markera att kollision har skett
	has_collided = true
	
	# Check collision type and handle accordingly
	if other_body.collision_layer == 1: # Player layer
		handle_player_hit(other_body)
	elif other_body.collision_layer == 2: # Damage block layer
		handle_damaged_hit(other_body)
	elif other_body.collision_layer == 3: # Bounce Layer
		handle_player_hit(other_body)
	elif other_body.collision_layer == 4: # Damage and bounce layer
		handle_damaged_bounce_hit(other_body)
	else:
		print("[PROJECTILE] This object is not DEFINED!")
		

func handle_player_hit(player_body):
	print("[PROJECTILE] Hit something and should bounce")
	current_bounces += 1
	
	# Calculate reflection direction away from player
	var player_pos = player_body.global_position
	var projectile_pos = projectile.global_position
	var reflection_direction = (projectile_pos - player_pos).normalized()
	
	# Set new velocity (maintain speed but change direction)
	var current_speed = projectile.linear_velocity.length()
	projectile.linear_velocity = reflection_direction * current_speed
	update_sprite(projectile.linear_velocity, projectile.global_position)
	projectile.bounced.emit(projectile.global_position)
	# Mark as player projectile after reflection
	projectile.is_player_projectile = true

func handle_damaged_hit(other_body):
	print("[PROJECTILE] Damaged object and free the projectile")
	if other_body.has_method("take_damage"):
		other_body.take_damage(10)
	
	# Hide the projectile sprite immediately
	if sprite:
		sprite.visible = false
	
	# Disable collision so it can't hit anything else
	projectile.collision_layer = 0
	projectile.collision_mask = 0
	
	# Stop the projectile movement
	projectile.linear_velocity = Vector2.ZERO
	
	# Turn of tail projectiles
	tail_particles.emitting = false
	
	# Trigger explosion effect
	projectile.create_explosion_at(projectile.global_position, projectile.linear_velocity, Vector2.ZERO)
	
	# Wait for particle effect to finish (death particles lifetime is 0.8s)
	var timer = Timer.new()
	timer.wait_time = 30.0  # Slightly longer than particle lifetime
	timer.one_shot = true
	timer.timeout.connect(func(): projectile.queue_free())
	projectile.add_child(timer)
	timer.start()

func handle_damaged_bounce_hit(other_body):
	print("[PROJECTILE] Damaged object and bounced projectile")
	if other_body.has_method("take_damage"):
		other_body.take_damage(10)
	handle_player_hit(other_body)
	
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
	death_particles.emitting = true
	
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
	
	# Wall bounce ska INTE markera projektilen som "kollliderad"
	# eftersom den ska kunna fortsätta studsa
	has_collided = false  # Reset för wall bounces
	
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

func update_sprite(pos: Vector2, vel: Vector2):
	if sprite == null:
		print("ERROR: Sprite2D not found!")
		return
		
	if current_bounces == 1:
		sprite.texture = projectile2_texture
	elif current_bounces == 2:
		sprite.texture = projectile3_texture
		
func handle_bounce(new_velocity: Vector2, new_position: Vector2):
	current_bounces += 1
	
	# Check bounce limit
	if current_bounces >= max_bounces:
		print("Projectile exceeded max bounces, destroying")
		projectile.create_explosion_at(new_position, new_velocity, Vector2(0, 0))
		projectile.queue_free()
		return
		
	# Apply bounce
	projectile.linear_velocity = new_velocity * bounce_damping
	projectile.global_position = new_position
	
	update_sprite(projectile.global_position, projectile.linear_velocity)
	
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
