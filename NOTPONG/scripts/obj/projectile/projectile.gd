extends RigidBody2D

# Core projectile settings
var direction: Vector2
var speed: float = 500.0
var lifetime: float = 8.0
var is_player_projectile: bool = false

# Bounce settings
var bounce_damping: float = 0.8
var max_bounces: int = 3
var current_bounces: int = 0

# World boundaries for cleanup (not physics)
var world_bounds: Rect2 = Rect2(200, 0, 752, 648)

# Visual components
@onready var sprite: Sprite2D = $Sprite2D
@onready var effect_manager: ProjectileEffectManager = $Components/EffectManager
var original_scale: Vector2

# Signals
signal hit_player
signal hit_enemy
signal player_should_take_damage  # New signal for lava hits
signal block_damaged(block, damage_amount)  # New signal for block damage
signal projectile_destroyed_by_collision(was_save: bool)
signal bounced(position: Vector2)

func _ready():
	setup_physics()
	setup_auto_destroy()
	
	# Store original scale
	if sprite:
		original_scale = sprite.scale
	
	# Connect collision signals - use the correct signal for RigidBody2D
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	print("Projectile created - Layer: ", collision_layer, " Mask: ", collision_mask)

func setup_physics():
	# Physics settings - let Godot handle the physics
	gravity_scale = 0
	linear_damp = 0
	contact_monitor = true
	max_contacts_reported = 10
	
	# Important: Set the collision behavior
	# For projectiles, you might want continuous collision detection
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

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
	
	# Update world bounds if provided (for cleanup/tracking only)
	if area_size != Vector2.ZERO:
		var half_size = area_size * 0.5
		world_bounds = Rect2(area_center - half_size, area_size)
	
	# Set initial velocity - let physics handle the rest
	linear_velocity = direction * speed
	print("Projectile initialized - From player: ", from_player, " Velocity: ", linear_velocity)

func _on_body_entered(body):
	print("Collision detected with: ", body.name, " Layer: ", body.collision_layer)
	
	# Handle different collision types
	match body.collision_layer:
		1: # Player layer - bounces projectile back
			handle_player_collision(body)
		2: # Objects layer - blocks that take damage
			handle_block_collision(body)
		3: # Playing Field - left/right walls that bounce projectiles
			handle_playing_field_bounce(body)
		4: # Lava - destroys projectile AND damages player
			handle_lava_collision(body)
		5: # DamageField - might pass through or be affected
			handle_damage_field_collision(body)
		6: # Another Projectile
			handle_projectile_collision(body)
		_:
			print("Hit unknown collision layer: ", body.collision_layer)

func handle_player_collision(player_body):
	print("Hit player - bouncing projectile back!")
	
	# Emit signal for game logic (might trigger player damage or effects)
	hit_player.emit()
	
	# Handle bounce off player
	handle_player_bounce(player_body)

func handle_block_collision(block_body):
	print("Hit block: ", block_body.name)
	
	var damage_amount = 10  # Adjust damage value as needed
	
	# Damage the block if it has a damage method
	if block_body.has_method("take_damage"):
		block_body.take_damage(damage_amount)
		print("Dealt ", damage_amount, " damage to block")
	
	# Emit signal for game logic tracking
	block_damaged.emit(block_body, damage_amount)
	
	# Destroy the projectile after hitting a block
	_destroy_projectile()

func handle_playing_field_bounce(wall_body):
	print("Hit playing field wall - bouncing back into play area")
	handle_wall_bounce(wall_body)

func handle_lava_collision(lava_body):
	print("Hit lava - projectile destroyed, player should take damage")
	
	# Emit signal so game manager can damage the player
	# You might want to add a specific signal for this
	if has_signal("player_should_take_damage"):
		player_should_take_damage.emit()
	
	_destroy_projectile()

func handle_damage_field_collision(damage_field_body):
	print("Hit damage field")
	# Might pass through or be destroyed depending on your game rules
	# For now, let's say it passes through
	pass

func handle_projectile_collision(other_projectile):
	print("=== PROJECTILE COLLISION ===")
	
	# Check if this is a defensive save
	var is_defensive_save = false
	
	# Get collision point
	var collision_point = (global_position + other_projectile.global_position) * 0.5
	
	# Create explosion effect
	if effect_manager:
		effect_manager.create_explosion_at(collision_point, linear_velocity, other_projectile.linear_velocity)
	
	# Emit signals
	projectile_destroyed_by_collision.emit(is_defensive_save)
	if other_projectile.has_signal("projectile_destroyed_by_collision"):
		other_projectile.projectile_destroyed_by_collision.emit(is_defensive_save)
	
	if is_defensive_save:
		print("DEFENSIVE SAVE ACHIEVED!")
	
	# Destroy both projectiles
	other_projectile.queue_free()
	_destroy_projectile()

func handle_wall_bounce(wall_body):
	current_bounces += 1
	
	if current_bounces >= max_bounces:
		print("Max bounces reached - destroying projectile")
		_destroy_projectile()
		return
	
	# Let Godot's physics handle the actual bounce
	# We just need to apply damping and emit signals
	
	# Emit bounce signal
	bounced.emit(global_position)
	
	print("Projectile bounced! Count: ", current_bounces)

func handle_player_bounce(player_body):
	"""Handle bouncing off the player paddle"""
	current_bounces += 1
	
	if current_bounces >= max_bounces:
		print("Max bounces reached - destroying projectile")
		_destroy_projectile()
		return
	
	# For player bounces, you might want special logic
	# Like changing angle based on where it hit the paddle
	var hit_position = global_position
	var player_position = player_body.global_position
	var paddle_width = 64.0  # Adjust based on your player size
	
	# Calculate relative hit position (-1 to 1)
	var relative_hit = (hit_position.x - player_position.x) / (paddle_width * 0.5)
	relative_hit = clamp(relative_hit, -1.0, 1.0)
	
	# Modify bounce angle based on hit position
	call_deferred("apply_player_bounce", relative_hit)
	
	bounced.emit(global_position)
	print("Bounced off player! Count: ", current_bounces)

func apply_player_bounce(relative_hit_position: float):
	"""Apply special player bounce physics"""
	# Get current speed
	var current_speed = linear_velocity.length()
	
	# Calculate new direction with angle modification
	var base_angle = -PI/2  # Upward direction
	var angle_modification = relative_hit_position * PI/3  # Up to 60 degrees
	var new_angle = base_angle + angle_modification
	
	# Apply new velocity
	var new_direction = Vector2(cos(new_angle), sin(new_angle))
	linear_velocity = new_direction * current_speed * bounce_damping
	
	print("Player bounce - Relative hit: ", relative_hit_position, " New angle: ", rad_to_deg(new_angle))

func get_distance_to_bounds() -> float:
	var pos = global_position
	var distances = [
		pos.x - world_bounds.position.x,  # Left
		(world_bounds.position.x + world_bounds.size.x) - pos.x,  # Right
		pos.y - world_bounds.position.y,  # Top
		(world_bounds.position.y + world_bounds.size.y) - pos.y   # Bottom
	]
	return distances.min()

func _physics_process(delta):
	# Optional: Check if projectile is way outside bounds for cleanup
	if not world_bounds.has_point(global_position):
		var distance_outside = get_distance_to_bounds()
		if distance_outside < -100:  # 100 pixels outside bounds
			print("Projectile too far outside bounds - cleaning up")
			_destroy_projectile()

func _destroy_projectile():
	print("Destroying projectile at position: ", global_position)
	queue_free()

func force_destroy():
	print("Force destroying projectile")
	queue_free()
