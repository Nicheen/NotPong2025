extends RigidBody2D

# Core projectile settings
var direction: Vector2
var speed: float = 500.0
var lifetime: float = 8.0
var is_player_projectile: bool = false

# World boundaries - default to your game area
var world_bounds: Rect2 = Rect2(200, 0, 752, 648)  # Your actual play area bounds

# Components (now as Node references)
@onready var collision_handler: ProjectileCollisionHandler = $Components/CollisionHandler
@onready var boundary_handler: ProjectileBoundaryHandler = $Components/BoundaryHandler
@onready var effect_manager: ProjectileEffectManager = $Components/EffectManager

# Visual effects
@onready var sprite: Sprite2D = $Sprite2D
var original_scale: Vector2

# Debug info (optional)
@onready var debug_info: Node2D = $DebugInfo
@onready var velocity_label: Label = $DebugInfo/VelocityLabel
@onready var bounce_label: Label = $DebugInfo/BounceLabel
@onready var distance_label: Label = $DebugInfo/DistanceLabel

# Signals
signal hit_player
signal bounced(position: Vector2)
signal projectile_destroyed_by_collision(was_save: bool)

func _ready():
	setup_physics()
	setup_components()
	setup_auto_destroy()
	
	print("Projectile created - Layer: ", collision_layer, " Mask: ", collision_mask)
	print("World bounds set to: ", world_bounds)

func setup_physics():
	gravity_scale = 0
	linear_damp = 0
	contact_monitor = true
	max_contacts_reported = 10
	
	if sprite:
		original_scale = sprite.scale

func setup_components():
	# Initialize boundary handler with bounds immediately
	if boundary_handler:
		boundary_handler.initialize(world_bounds)
		print("Boundary handler initialized with bounds: ", world_bounds)
	
	# Connect collision signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func setup_auto_destroy():
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_destroy_projectile)
	add_child(timer)
	timer.start()

func initialize(shoot_direction: Vector2, projectile_speed: float, area_center: Vector2 = Vector2.ZERO, area_size: Vector2 = Vector2.ZERO, from_player: bool = true):
	direction = shoot_direction.normalized()
	speed = projectile_speed
	is_player_projectile = from_player
	
	# Update world bounds if provided
	if area_size != Vector2.ZERO:
		var half_size = area_size * 0.5
		world_bounds = Rect2(area_center - half_size, area_size)
		print("Updated world bounds to: ", world_bounds)
	else:
		# Use default play area bounds (adjust these to match your game)
		world_bounds = Rect2(200, 0, 752, 648)  # Left wall at x=200, right wall at x=952
		print("Using default world bounds: ", world_bounds)
	
	# Update boundary handler with new bounds
	if boundary_handler:
		boundary_handler.update_bounds(world_bounds)
	
	# Set velocity
	linear_velocity = direction * speed
	print("Projectile initialized - From player: ", from_player, " Velocity: ", linear_velocity)

func _physics_process(delta):
	if boundary_handler:
		boundary_handler.check_boundaries()
		boundary_handler.maintain_minimum_velocity()
	update_debug_info()

func update_debug_info():
	# Update debug labels if they exist and debug is enabled
	if debug_info and debug_info.visible:
		if velocity_label:
			velocity_label.text = str(int(linear_velocity.length()))
		if bounce_label:
			bounce_label.text = str(collision_handler.current_bounces)
		if distance_label:
			distance_label.text = str(int(get_distance_to_bounds()))

func toggle_debug_info():
	if debug_info:
		debug_info.visible = !debug_info.visible

func _on_body_entered(body):
	if collision_handler:
		collision_handler.handle_collision(body)

func create_explosion_at(position: Vector2, velocity1: Vector2, velocity2: Vector2):
	if effect_manager:
		effect_manager.create_explosion_effect(position, velocity1, velocity2)

func get_distance_to_bounds() -> float:
	if boundary_handler:
		return boundary_handler.get_distance_to_bounds()
	return 999.0

func handle_bounce(new_velocity: Vector2, new_position: Vector2):
	if collision_handler:
		collision_handler.handle_bounce(new_velocity, new_position)

func _destroy_projectile():
	print("Destroying projectile at position: ", global_position)
	queue_free()

func force_destroy():
	print("Force destroying projectile")
	queue_free()
