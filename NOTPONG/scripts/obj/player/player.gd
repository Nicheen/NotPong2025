extends CharacterBody2D

# Movement settings
@export var speed: float = 600.0
@export var acceleration: float = 2000.0
@export var friction: float = 4000.0

# Teleport settings
@export var teleport_cooldown: float = 0.2
@export var play_area_size: Vector2 = Vector2(1000, 600)
@export var play_area_center: Vector2 = Vector2(500, 300)

# NEW: Top wall time limit settings
@export var top_wall_max_time: float = 2.0  # Max seconds on top wall
@export var top_wall_warning_time: float = 0.5  # Warning starts this many seconds before forced return

# Shooting settings
@export var projectile_scene: PackedScene = load("res://scenes/obj/Projectile.tscn")
@export var projectile_speed: float = 500.0
@export var shoot_cooldown: float = 0.1

# Health settings
@export var max_health: int = 100
@export var damage_per_hit: int = 10

# NEW: Knockback settings
@export var knockback_resistance: float = 0.3  # How much knockback is reduced (0.0 = full knockback, 1.0 = no knockback)
@export var knockback_recovery_time: float = 0.5  # How long knockback effects last

# NEW: Knockback state variables (add after existing internal variables)
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var is_being_knocked_back: bool = false

# Wall state tracking
enum WallSide { BOTTOM, TOP }
var current_wall: WallSide = WallSide.BOTTOM

# NEW: Top wall timing variables
var top_wall_timer: float = 0.0
var is_on_top_wall: bool = false
var warning_active: bool = false
var warning_tween: Tween  # Keep reference to stop it properly

# Internal variables
var teleport_timer: float = 0.0
var can_teleport: bool = true
var shoot_timer: float = 0.0
var can_shoot: bool = true
var current_health: int

# Optional: Visual feedback
@onready var sprite: Sprite2D = $Sprite2D
var teleport_effect_duration: float = 0.1
var is_teleporting: bool = false

# Signals
signal health_changed(new_health: int)
signal player_died

func _ready():
	# Set initial position and health
	global_position = Vector2(500, 200)
	current_health = max_health
	current_wall = WallSide.BOTTOM
	is_on_top_wall = false
	
	# Connect to projectile hits
	connect_to_projectiles()

func _physics_process(delta):
	handle_teleport_cooldown(delta)
	handle_shoot_cooldown(delta)
	handle_movement(delta)
	handle_teleport_input()
	handle_shoot_input()
	handle_teleport_effect(delta)
	handle_knockback(delta)
	# NEW: Handle top wall time limit
	handle_top_wall_timer(delta)
	
	# Apply movement
	move_and_slide()
func apply_knockback(direction: Vector2, force: float):
	"""Apply knockback to the player (X-axis only)"""
	print("Applying knockback - Direction: ", direction, " Force: ", force)
	
	# Reduce knockback based on resistance
	var final_force = force * (1.0 - knockback_resistance)
	
	# Only use the X component of direction - ignore Y
	var horizontal_direction = Vector2(direction.x, 0.0).normalized()
	
	# Set knockback state (X-axis only)
	knockback_velocity = Vector2(horizontal_direction.x * final_force, 0.0)
	knockback_timer = knockback_recovery_time
	is_being_knocked_back = true
	
	# Visual effect - flash player red briefly
	if sprite:
		var flash_tween = create_tween()
		flash_tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	print("Horizontal knockback applied: ", knockback_velocity)

func handle_knockback(delta: float):
	"""Handle knockback physics and recovery (X-axis only)"""
	if not is_being_knocked_back:
		return
	
	# Decrease knockback timer
	knockback_timer -= delta
	
	# Apply knockback to velocity
	if knockback_timer > 0:
		# Gradually reduce knockback over time
		var decay_factor = knockback_timer / knockback_recovery_time
		var current_knockback = knockback_velocity * decay_factor
		
		# Add knockback to normal movement (X-axis only)
		velocity.x += current_knockback.x * delta
		# Don't modify velocity.y - keep vertical movement unchanged
		
		# Clamp horizontal velocity to prevent going too fast
		var max_knockback_speed = 1200.0
		if abs(velocity.x) > max_knockback_speed:
			velocity.x = sign(velocity.x) * max_knockback_speed
	else:
		# Knockback finished
		is_being_knocked_back = false
		knockback_velocity = Vector2.ZERO
		knockback_timer = 0.0
		print("Knockback recovery complete")

func get_knockback_info() -> Dictionary:
	"""Get current knockback state for debugging"""
	return {
		"is_knocked_back": is_being_knocked_back,
		"knockback_velocity": knockback_velocity,
		"time_remaining": knockback_timer
	}

func handle_movement(delta):
	# Get input direction using the Input Map actions
	var input_dir = Input.get_axis("move_left", "move_right")
	
	# Apply movement based on current wall (only top and bottom)
	match current_wall:
		WallSide.BOTTOM:
			# Normal horizontal movement on bottom
			if input_dir != 0:
				var changing_direction = (velocity.x > 0 and input_dir < 0) or (velocity.x < 0 and input_dir > 0)
				
				if changing_direction:
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * 3 * delta)
				else:
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, friction * delta)
				
		WallSide.TOP:
			# Horizontal movement on top (same logic)
			if input_dir != 0:
				var changing_direction = (velocity.x > 0 and input_dir < 0) or (velocity.x < 0 and input_dir > 0)
				
				if changing_direction:
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * 3 * delta)
				else:
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_teleport_input():
	if not can_teleport:
		return
	
	var teleport_direction = Vector2.ZERO
	
	# Use Input Map actions for teleporting
	if Input.is_action_just_pressed("teleport_up"):
		# Only allow teleport up if not already on top or if forced down recently
		if current_wall == WallSide.BOTTOM:
			teleport_direction = Vector2(0, -1)
	elif Input.is_action_just_pressed("teleport_down"):
		# Always allow teleport down
		teleport_direction = Vector2(0, 1)
	
	if teleport_direction != Vector2.ZERO:
		teleport_to_edge(teleport_direction)

# NEW: Handle top wall timer and forced return
func handle_top_wall_timer(delta):
	if not is_on_top_wall:
		return
	
	top_wall_timer += delta
	
	# Check for warning phase
	if top_wall_timer >= (top_wall_max_time - top_wall_warning_time) and not warning_active:
		start_warning_effect()
		warning_active = true
	
	# Force return to bottom when time is up
	if top_wall_timer >= top_wall_max_time:
		force_return_to_bottom()

func start_warning_effect():
	"""Visual warning that player will be forced down soon"""
	if sprite and not warning_active:
		warning_active = true
		warning_tween = create_tween()
		warning_tween.set_loops()  # Loop indefinitely until stopped
		warning_tween.tween_property(sprite, "modulate", Color.YELLOW, 0.2)
		warning_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
		print("WARNING: You will be forced down in ", (top_wall_max_time - top_wall_timer), " seconds!")

func force_return_to_bottom():
	"""Force player back to bottom wall when time limit is reached"""
	if current_wall == WallSide.TOP:
		# Don't use teleport_to_edge to avoid triggering teleport cooldown
		var new_position = global_position
		var half_size = play_area_size * 0.5
		var bottom_y = play_area_center.y + half_size.y - 50
		
		new_position.y = bottom_y
		global_position = new_position
		
		# Save current x-velocity
		var current_x_velocity = velocity.x
		velocity = Vector2(current_x_velocity, 0)
		
		# Update wall state
		current_wall = WallSide.BOTTOM
		reset_top_wall_state()
		
		# Visual effect but no cooldown
		start_teleport_effect()
		update_sprite_rotation()
		
		print("Time limit reached! Forced back to bottom wall (no cooldown penalty)!")

func handle_shoot_input():
	if not can_shoot:
		return
	
	# Check for mouse click or shoot action
	if Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("ui_accept"):
		shoot_projectile()

func shoot_projectile():
	if not projectile_scene or not can_shoot:
		return
		
	print("=== SHOOTING PROJECTILE ===")
	
	# Get shoot direction toward mouse
	var mouse_pos = get_global_mouse_position()
	var shoot_direction = (mouse_pos - global_position).normalized()
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	
	# Position it in front of player
	var spawn_position = global_position + (shoot_direction * 80)
	projectile.global_position = spawn_position
	
	print("Spawning projectile at: ", spawn_position)
	print("Shoot direction: ", shoot_direction)
	
	# Add to scene first
	get_tree().current_scene.add_child(projectile)
	
	# Wait one frame then initialize
	await get_tree().process_frame
	
	# Initialize the projectile
	projectile.initialize(shoot_direction, projectile_speed)
	
	# Connect the hit signal
	projectile.hit_player.connect(_on_projectile_hit)
	
	print("Projectile setup complete")
	
	# Start cooldown
	start_shoot_cooldown()

func teleport_to_edge(direction: Vector2):
	var new_position = global_position
	var half_size = play_area_size * 0.5
	var bounds = {
		"top": play_area_center.y - half_size.y,
		"bottom": play_area_center.y + half_size.y
	}
	
	# Save current x-velocity before teleporting
	var current_x_velocity = velocity.x
	
	# Teleport to edge and update current wall (only up/down)
	if direction.y > 0:  # Teleport down
		new_position.y = bounds.bottom - 50
		current_wall = WallSide.BOTTOM
		
		# NEW: Reset top wall timer and effects when going to bottom
		if is_on_top_wall:
			reset_top_wall_state()
		
	elif direction.y < 0:  # Teleport up
		new_position.y = bounds.top + 50
		current_wall = WallSide.TOP
		
		# NEW: Start top wall timer
		start_top_wall_timer()
	
	# Apply teleportation
	global_position = new_position
	
	# Keep x-velocity, reset y-velocity
	velocity = Vector2(current_x_velocity, 0)
	
	# ALWAYS apply teleport cooldown for voluntary teleports
	start_teleport_cooldown()
	start_teleport_effect()
	
	# Update sprite rotation based on wall
	update_sprite_rotation()

# NEW: Top wall timer management functions
func start_top_wall_timer():
	"""Start the timer when player reaches top wall"""
	is_on_top_wall = true
	top_wall_timer = 0.0
	warning_active = false
	print("Started top wall timer - you have ", top_wall_max_time, " seconds!")

func reset_top_wall_state():
	"""Reset all top wall related state when returning to bottom"""
	is_on_top_wall = false
	top_wall_timer = 0.0
	warning_active = false
	
	# Stop the warning tween properly
	if warning_tween and warning_tween.is_valid():
		warning_tween.kill()
		warning_tween = null
	
	# Reset sprite color immediately
	if sprite:
		sprite.modulate = Color.WHITE
	
	print("Top wall state reset - back to bottom wall")

func start_teleport_cooldown():
	can_teleport = false
	teleport_timer = teleport_cooldown

func handle_teleport_cooldown(delta):
	if not can_teleport:
		teleport_timer -= delta
		if teleport_timer <= 0:
			can_teleport = true

func start_shoot_cooldown():
	can_shoot = false
	shoot_timer = shoot_cooldown

func handle_shoot_cooldown(delta):
	if not can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0:
			can_shoot = true

func start_teleport_effect():
	is_teleporting = true
	if sprite:
		var tween = create_tween()
		tween.tween_method(set_sprite_modulate, Color.WHITE, Color.CYAN, 0.1)
		tween.tween_method(set_sprite_modulate, Color.CYAN, Color.WHITE, 0.1)

func handle_teleport_effect(delta):
	if is_teleporting:
		teleport_effect_duration -= delta
		if teleport_effect_duration <= 0:
			is_teleporting = false
			teleport_effect_duration = 0.1

func set_sprite_modulate(color: Color):
	if sprite:
		sprite.modulate = color

func set_play_area(center: Vector2, size: Vector2):
	play_area_center = center
	play_area_size = size

func update_sprite_rotation():
	if not sprite:
		return
	
	var tween = create_tween()
	var target_rotation = 0.0
	
	match current_wall:
		WallSide.BOTTOM:
			target_rotation = 0.0  # Normal orientation
		WallSide.TOP:
			target_rotation = PI  # Upside down
	
	tween.tween_property(sprite, "rotation", target_rotation, 0.2)

func connect_to_projectiles():
	# This function can be used to connect to existing projectiles if needed
	pass

func _on_projectile_hit():
	take_damage(damage_per_hit)

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	
	# Emit health changed signal
	health_changed.emit(current_health)
	
	# Visual damage feedback
	if sprite:
		var tween = create_tween()
		tween.tween_method(set_sprite_modulate, Color.WHITE, Color.RED, 0.1)
		tween.tween_method(set_sprite_modulate, Color.RED, Color.WHITE, 0.1)
	
	# Check if player died
	if current_health <= 0:
		player_died.emit()
		print("Player died!")

func heal(amount: int):
	current_health += amount
	current_health = min(max_health, current_health)
	health_changed.emit(current_health)

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

# NEW: Utility functions for checking top wall status
func get_remaining_top_time() -> float:
	"""Get remaining time on top wall"""
	if not is_on_top_wall:
		return 0.0
	return max(0.0, top_wall_max_time - top_wall_timer)

func is_in_warning_phase() -> bool:
	"""Check if player is in warning phase on top wall"""
	return warning_active
