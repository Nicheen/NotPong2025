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

@export var dash_distance: float = 100.0  # Distance to dash
@export var dash_cooldown: float = 1.5   # Cooldown time in seconds
@export var dash_grace_period: float = 1.5

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

var dash_timer: float = 0.0
var can_dash: bool = true
var is_dashing: bool = false
var dash_input_buffer: float = 0.0  # Buffer time for dash input
var dash_grace_timer: float = 0.0   # Grace period timer
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

func _physics_process(delta):
	handle_teleport_cooldown(delta)
	handle_shoot_cooldown(delta)
	handle_dash_cooldown(delta)
	handle_dash_grace_period(delta)
	handle_movement(delta)
	handle_teleport_input()
	handle_shoot_input()
	handle_dash_input()
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
		tween.tween_method(set_sprite_modulate, Color.WHITE, Color.CYAN, 0.3)
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
	
	tween.tween_property(sprite, "rotation", target_rotation, 0.0)

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

func handle_dash_input():
	"""Handle dash input - Shift key with grace period (ONLY while held)"""
	if not can_dash:
		return
	
	# KRITISK FIX: Kolla om Shift är nedtryckt JUST NU
	var shift_held = Input.is_action_pressed("dash")
	
	# Om Shift inte är nedtryckt, avbryt grace period
	if not shift_held and dash_grace_timer > 0.0:
		print("🚫 Shift released during grace period - dash cancelled")
		dash_grace_timer = 0.0
		return
	
	# Check for dash input (Shift key)
	if Input.is_action_just_pressed("dash"):
		# Get current input direction
		var input_dir = Input.get_axis("move_left", "move_right")
		
		if input_dir != 0:
			# Has direction - perform dash immediately
			perform_dash()
		else:
			# No direction - start grace period
			print("⏰ Dash input detected but no direction - starting grace period (", dash_grace_period, " seconds)")
			print("   (Keep holding Shift and press A/D to dash)")
			dash_grace_timer = dash_grace_period

func handle_dash_grace_period(delta):
	"""Handle grace period for dash input"""
	if dash_grace_timer <= 0.0:
		return
	
	dash_grace_timer -= delta
	
	# KRITISK: Kolla om Shift fortfarande är nedtryckt
	if not Input.is_action_pressed("dash"):
		print("🚫 Shift released - grace period cancelled")
		dash_grace_timer = 0.0
		return
	
	# Check if player starts moving during grace period
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		print("✨ Direction input detected during grace period - performing dash!")
		perform_dash()
		dash_grace_timer = 0.0  # Clear grace period
		return
	
	# Grace period expired
	if dash_grace_timer <= 0.0:
		print("⏰ Grace period expired - dash cancelled (no cooldown penalty)")
		dash_grace_timer = 0.0

func perform_dash():
	"""Perform the dash movement"""
	if not can_dash:
		print("Dash on cooldown!")
		return
	
	# Get current input direction
	var input_dir = Input.get_axis("move_left", "move_right")
	
	# If no input, don't dash (this shouldn't happen due to grace period)
	if input_dir == 0:
		print("No direction input - dash cancelled")
		return
	
	print("🏃 DASHING ", "RIGHT" if input_dir > 0 else "LEFT")
	
	# Clear any ongoing grace period
	dash_grace_timer = 0.0
	
	# Calculate dash direction (only horizontal)
	var dash_direction = Vector2(input_dir, 0).normalized()
	
	# Calculate target position
	var current_pos = global_position
	var target_pos = current_pos + (dash_direction * dash_distance)
	
	# Clamp to play area bounds (så spelaren inte dashar utanför spelet)
	var half_size = play_area_size * 0.5
	var min_x = play_area_center.x - half_size.x + 25  
	var max_x = play_area_center.x + half_size.x - 25
	
	if target_pos.x <= 196:
		target_pos.x = 196
	elif target_pos.x >= 956:
		target_pos.x = 956
	else:
		target_pos.x = clamp(target_pos.x, min_x, max_x)
	
	print("Dashing from ", current_pos, " to ", target_pos)
	
	# Perform instant teleport (behåller nuvarande hastighet)
	var current_velocity = velocity  # Spara nuvarande hastighet
	global_position = target_pos
	velocity = current_velocity  # Återställ hastighet efter dash
	
	# Start cooldown and effects
	start_dash_cooldown()
	create_dash_afterimages(current_pos, dash_direction)
	create_dash_effect()
	
	print("Dash complete! Distance: ", current_pos.distance_to(target_pos), " pixels")

func create_dash_afterimages(start_pos: Vector2, dash_direction: Vector2):
	"""Create afterimage effect showing dash trail"""
	if not sprite:
		return
	
	print("🌟 Creating dash afterimages")
	
	# Create 3 afterimages spread out along the dash path
	var afterimage_count = 3
	
	for i in range(afterimage_count):
		create_single_afterimage(start_pos, dash_direction, i, afterimage_count)

func create_single_afterimage(start_pos: Vector2, dash_direction: Vector2, index: int, total_count: int):
	"""Create a single afterimage sprite positioned along dash path"""
	# Create afterimage sprite
	var afterimage = Sprite2D.new()
	afterimage.texture = sprite.texture
	afterimage.scale = sprite.scale
	afterimage.rotation = sprite.rotation
	
	# Position afterimages along the dash path with better spacing
	# index 0 = mest genomskinlig, spawnar där spelaren började (start_pos)
	# index 1 = mellan-genomskinlig, spawnar 33% längs dash-vägen  
	# index 2 = minst genomskinlig, spawnar 66% längs dash-vägen
	var current_pos = global_position
	var target_pos = current_pos + (dash_direction * dash_distance)
	var half_size = play_area_size * 0.5
	var diff = 0
	var outside = false
	var min_x = play_area_center.x - half_size.x + 25  
	var max_x = play_area_center.x + half_size.x - 25
	
	if target_pos.x <= 196:
		target_pos.x = 196
		outside = true
	elif target_pos.x >= 956:
		target_pos.x = 956
		outside = true
	else:
		target_pos.x = clamp(target_pos.x, min_x, max_x)
		
	var progress_along_dash = float(index) / float(total_count - 1)  # 0.0, 0.5, 1.0
	
	var afterimage_pos = start_pos + (dash_direction * dash_distance * progress_along_dash)
	
	if not outside:
		afterimage.global_position = afterimage_pos
	else:
		afterimage.global_position = start_pos
	
	# Set transparency - mest genomskinlig längst bak, minst genomskinlig närmast spelaren
	# index 0 (start) = mest genomskinlig (0.3)
	# index 1 (mitt) = mellan (0.5) 
	# index 2 (slut) = minst genomskinlig (0.7)
	var alpha = 0.3 + (float(index) / float(total_count - 1) * 0.4)  # 0.3, 0.5, 0.7
	afterimage.modulate = Color(1.0, 1.0, 1.0, alpha)
	
	# Add to scene
	get_tree().current_scene.add_child(afterimage)
	
	print("   Afterimage ", index + 1, " created at ", afterimage_pos, " with alpha ", alpha)
	
	# Animate afterimage - fade out 5x snabbare (0.16 sekunder istället för 0.8)
	var fade_duration = 0.16  # 5x snabbare än tidigare
	var afterimage_tween = create_tween()
	afterimage_tween.set_parallel(true)
	
	# Fade out mycket snabbare
	afterimage_tween.tween_property(afterimage, "modulate:a", 0.0, fade_duration)
	if outside: return
	# Slight forward movement (mindre rörelse, snabbare)
	var drift_distance = 8  # Mindre drift än tidigare (8 istället för 15)
	var drift_target = afterimage_pos + (dash_direction * drift_distance)
	afterimage_tween.tween_property(afterimage, "global_position", drift_target, fade_duration * 0.7)
	
	# Scale down slightly (snabbare animation)
	afterimage_tween.tween_property(afterimage, "scale", sprite.scale * 0.9, fade_duration)
	
	# Clean up afterimage snabbare
	afterimage_tween.tween_callback(func(): 
		if is_instance_valid(afterimage):
			afterimage.queue_free()
			print("   Afterimage ", index + 1, " cleaned up")
	).set_delay(fade_duration)

func start_dash_cooldown():
	"""Start dash cooldown"""
	can_dash = false
	dash_timer = dash_cooldown
	print("Dash cooldown started - ", dash_cooldown, " seconds")

func handle_dash_cooldown(delta):
	"""Handle dash cooldown timer"""
	if not can_dash:
		dash_timer -= delta
		if dash_timer <= 0:
			can_dash = true
			print("✨ Dash ready!")

func create_dash_effect():
	"""Visual effect for dash on player"""
	if not sprite:
		return
	
	# Flash effect - snabb cyan blink på spelaren
	var dash_tween = create_tween()
	dash_tween.set_parallel(true)
	
	# Quick flash sequence
	dash_tween.tween_property(sprite, "modulate", Color.CYAN, 0.05)
	dash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	dash_tween.tween_property(sprite, "modulate", Color.CYAN, 0.05)
	dash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	
	# Kort scale effect för att visa "speed"
	var original_scale = sprite.scale
	dash_tween.tween_property(sprite, "scale", original_scale * 1.2, 0.1)
	dash_tween.tween_property(sprite, "scale", original_scale, 0.1)

# UTILITY FUNKTIONER för UI/debugging

func get_dash_cooldown_remaining() -> float:
	"""Get remaining dash cooldown time"""
	if can_dash:
		return 0.0
	return dash_timer

func get_dash_grace_remaining() -> float:
	"""Get remaining grace period time"""
	return dash_grace_timer

func is_dash_ready() -> bool:
	"""Check if dash is ready"""
	return can_dash

func is_in_grace_period() -> bool:
	"""Check if currently in grace period"""
	return dash_grace_timer > 0.0

func is_shift_held() -> bool:
	"""Check if Shift is currently held down"""
	return Input.is_action_pressed("dash")

func get_dash_info() -> Dictionary:
	"""Get dash state info for debugging"""
	return {
		"can_dash": can_dash,
		"cooldown_remaining": get_dash_cooldown_remaining(),
		"grace_remaining": get_dash_grace_remaining(),
		"in_grace_period": is_in_grace_period(),
		"shift_held": is_shift_held(),
		"dash_distance": dash_distance,
		"is_dashing": is_dashing
	}
	
func get_remaining_top_time() -> float:
	"""Get remaining time on top wall"""
	if not is_on_top_wall:
		return 0.0
	return max(0.0, top_wall_max_time - top_wall_timer)

func is_in_warning_phase() -> bool:
	"""Check if player is in warning phase on top wall"""
	return warning_active
