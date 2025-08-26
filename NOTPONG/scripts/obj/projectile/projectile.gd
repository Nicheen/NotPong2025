class_name Projectile extends RigidBody2D

# Core projectile settings
var direction: Vector2
var previous_speed: Vector2

var damage_multiplier: float = 1.0
var current_bounces: int = 0
var last_collision_normal: Vector2 = Vector2.ZERO
var last_collision_point: Vector2 = Vector2.ZERO
var pending_collision = null
var is_player_projectile: bool = false
var has_collided: bool = false
var critical_hit: bool = false

var damage: int
var velocity: Vector2
var player: Player

@export var base_speed: float = 300.0
@export var max_speed: float = 500.0
@export var base_damage: int = 10
@export var max_bounces: int = 3

@onready var death_particles: GPUParticles2D = %DeathParticles
@onready var tail_particles: GPUParticles2D = %TailParticles
@onready var sprite: Sprite2D = %Sprite2D

@onready var projectile2_texture = preload("res://images/PlayerProjectile2.png")
@onready var projectile3_texture = preload("res://images/PlayerProjectile3.png")

signal bounced(position: Vector2)
signal hit_target(target, damage_dealt)

func _ready():
	damage = base_damage   
	lock_rotation = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	
	# Enable contact monitoring for RigidBody2D
	contact_monitor = true
	max_contacts_reported = 10
	
	# Connect the RigidBody2D collision signal
	body_entered.connect(_on_body_entered)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
		
func initialize(shoot_direction: Vector2, projectile_speed: float, from_player: bool = true):
	direction = shoot_direction.normalized()
	is_player_projectile = from_player
	linear_velocity = direction * projectile_speed
	previous_speed = linear_velocity
	
func _integrate_forces(state):
	if state.get_contact_count() > 0:
		# Get the first contact
		var contact_normal = state.get_contact_local_normal(0)
		var contact_position = state.get_contact_local_position(0)
		var collider = state.get_contact_collider_object(0)
		
		# Store collision data for use in _on_body_entered
		last_collision_normal = contact_normal
		last_collision_point = to_global(contact_position)
		
		# Store the collider for processing
		if collider and not pending_collision:
			pending_collision = collider
			
func _on_body_entered(body):
	print("[PROJECTILE] Hit: ", body.name, " on layer: ", body.collision_layer)
	
	if body.is_in_group("projectiles"):
		body.queue_free()
		destroy()
		return
		
	# Handle different collision types based on layer
	match body.collision_layer:
		1: # Player layer
			handle_bounce(body)
		2: # Damage block layer
			damage_object(body)
			destroy()
		4: # Bounce layer
			handle_bounce(body)
		8: # Damage and bounce layer
			damage_object(body)
			handle_bounce(body)
		16: # Damage player
			damage_object(player)
			destroy()
		_:
			print("[PROJECTILE] Unknown collision layer!")

func get_collision_info(colliding_body):
	# Use raycast to get precise collision normal
	var space_state = get_world_2d().direct_space_state
	
	# Cast a ray from previous position to current position
	var ray_start = global_position - linear_velocity.normalized() * 20.0
	var ray_end = global_position + linear_velocity.normalized() * 20.0
	
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [self]  # Exclude self from raycast
	query.collision_mask = colliding_body.collision_layer
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		# Fallback: try casting from center of colliding body to projectile
		var body_center = colliding_body.global_position
		var projectile_center = global_position
		
		query = PhysicsRayQueryParameters2D.create(body_center, projectile_center)
		query.exclude = [self]
		result = space_state.intersect_ray(query)
		
		if result.is_empty():
			return null
	
	return {
		"normal": result.normal,
		"position": result.position
	}

func handle_bounce(colliding_body):
	current_bounces += 1
	
	# Check if we've bounced too many times
	if current_bounces >= max_bounces:
		destroy()
		return
	
	# Calculate bounce direction (simple approach)
	var bounce_normal = last_collision_normal
	
	# Apply bounce with current speed
	if bounce_normal == Vector2.ZERO:
		var collision_info = get_collision_info(colliding_body)
		if collision_info:
			bounce_normal = collision_info["normal"]
		else:
			# Final fallback
			bounce_normal = (global_position - colliding_body.global_position).normalized()
	
	# Calculate proper reflection
	var incoming_velocity = previous_speed
	var bounce_velocity = incoming_velocity - 2 * incoming_velocity.dot(bounce_normal) * bounce_normal
	
	# Apply the bounce
	linear_velocity = bounce_velocity.normalized() * base_speed

	# Move away from collision point along normal to prevent sticking
	if last_collision_point != Vector2.ZERO:
		global_position = last_collision_point + bounce_normal * 15
	else:
		global_position += bounce_normal * 15
	
	# Reset collision data for next collision
	last_collision_normal = Vector2.ZERO
	last_collision_point = Vector2.ZERO
	
	previous_speed = linear_velocity
	
	# Mark as player projectile and emit signal
	is_player_projectile = true
	bounced.emit(global_position)

func damage_object(colliding_body):
	if colliding_body.has_method("take_damage"):
		colliding_body.take_damage(damage)
		print("[PROJECTILE] Applied damage: ", damage)
	else:
		print("[PROJECTILE] Something went wrong with damage giving")
	
func calculate_wall_collision_normal(wall_body) -> Vector2:
	var collision_normal = Vector2.ZERO
	
	# Try raycast first
	var space_state = get_world_2d().direct_space_state
	var ray_query = PhysicsRayQueryParameters2D.create(
		global_position - linear_velocity.normalized() * 30,
		global_position + linear_velocity.normalized() * 30
	)
	ray_query.collision_mask = 8  # Wall layer mask
	ray_query.exclude = [get_rid()]
	
	var result = space_state.intersect_ray(ray_query)
	if result and result.has("normal"):
		collision_normal = result.normal
		print("[PROJECTILE] Got collision normal from raycast: ", collision_normal)
	else:
		# Fallback: Calculate from positions
		if wall_body and wall_body.has_method("get_global_position"):
			var wall_pos = wall_body.global_position
			collision_normal = (global_position - wall_pos).normalized()
			print("[PROJECTILE] Calculated normal from positions: ", collision_normal)
		else:
			# Final fallback
			collision_normal = -linear_velocity.normalized()
			print("[PROJECTILE] Using velocity-based normal: ", collision_normal)
	
	# Validate normal
	if collision_normal.length_squared() < 0.1:
		collision_normal = -linear_velocity.normalized()
		print("[PROJECTILE] Fixed invalid normal to: ", collision_normal)
	
	return collision_normal

func show_enhanced_projectile_effect():
	var tween = create_tween()
	tween.set_loops()  # Loop tills projektilen förstörs
	tween.tween_property(sprite, "modulate", Color.GOLD, 0.3)
	tween.tween_property(sprite, "modulate", Color.YELLOW, 0.3)

func deal_damage_to_target(target):
	if target.has_method("take_damage"):
		target.take_damage(damage)
	else:
		print("[PROJECTILE] Error, target object does not have func. take_damage()")	
	if critical_hit:
		create_floating_damage_text(target.global_position, damage)

func create_floating_damage_text(pos: Vector2, damage: int):
	var label = Label.new()
	label.text = str(damage) + "!"  # FIXED: Tar bort * 10
	label.add_theme_font_size_override("font_size", 24)
	
	# Färg baserat på damage multiplier
	if damage_multiplier > 1.0:
		label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	
		
	label.global_position = pos
	get_tree().current_scene.add_child(label)
	
	# Skapa tween från scene tree istället för create_tween()
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", pos + Vector2(0, -50), 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	
	# Ta bort efter animation
	tween.finished.connect(func(): 
		if is_instance_valid(label):
			label.queue_free()
	)

func update_sprite():
	if current_bounces == 1:
		sprite.texture = projectile2_texture
	elif current_bounces >= 2:
		sprite.texture = projectile3_texture

func destroy():
	print("[PROJECTILE] Projectile was destroyed.")
	queue_free()

func _on_death_timer_timeout() -> void:
	destroy()
