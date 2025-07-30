extends CharacterBody2D

# Movement settings
@export var speed: float = 600.0
@export var acceleration: float = 2000.0
@export var friction: float = 4000.0

# Teleport settings
@export var teleport_cooldown: float = 0.2
@export var play_area_size: Vector2 = Vector2(1000, 600)
@export var play_area_center: Vector2 = Vector2(500, 300)

# Shooting settings
@export var projectile_scene: PackedScene = load("res://scenes/obj/Projectile.tscn")
@export var projectile_speed: float = 500.0
@export var shoot_cooldown: float = 0.1

# Health settings
@export var max_health: int = 100
@export var damage_per_hit: int = 10

# Wall state tracking
enum WallSide { BOTTOM, TOP }
var current_wall: WallSide = WallSide.BOTTOM

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
	
	# Connect to projectile hits
	connect_to_projectiles()

func _physics_process(delta):
	handle_teleport_cooldown(delta)
	handle_shoot_cooldown(delta)
	handle_movement(delta)
	handle_teleport_input()
	handle_shoot_input()
	handle_teleport_effect(delta)
	
	# Apply movement
	move_and_slide()

func handle_movement(delta):
	# Get input direction using the Input Map actions
	var input_dir = Input.get_axis("move_left", "move_right")
	
	# Apply movement based on current wall (only top and bottom)
	match current_wall:
		WallSide.BOTTOM:
			# Normal horizontal movement on bottom
			if input_dir != 0:
				# Kolla om vi byter riktning
				var changing_direction = (velocity.x > 0 and input_dir < 0) or (velocity.x < 0 and input_dir > 0)
				
				if changing_direction:
					# Mycket högre acceleration när vi byter riktning
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * 3 * delta)
				else:
					# Normal acceleration
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, friction * delta)
				
		WallSide.TOP:
			# Horizontal movement on top (samma logik)
			if input_dir != 0:
				# Kolla om vi byter riktning
				var changing_direction = (velocity.x > 0 and input_dir < 0) or (velocity.x < 0 and input_dir > 0)
				
				if changing_direction:
					# Mycket högre acceleration när vi byter riktning
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * 3 * delta)
				else:
					# Normal acceleration
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_teleport_input():
	if not can_teleport:
		return
	
	var teleport_direction = Vector2.ZERO
	
	# Use Input Map actions for teleporting
	if Input.is_action_just_pressed("teleport_up"):
		teleport_direction = Vector2(0, -1)
	elif Input.is_action_just_pressed("teleport_down"):
		teleport_direction = Vector2(0, 1)
	
	if teleport_direction != Vector2.ZERO:
		teleport_to_edge(teleport_direction)

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
	
	# Spara nuvarande x-hastighet innan teleportering
	var current_x_velocity = velocity.x
	
	# Teleport to edge and update current wall (only up/down)
	if direction.y > 0:  # Teleport down
		new_position.y = bounds.bottom - 50
		current_wall = WallSide.BOTTOM
	elif direction.y < 0:  # Teleport up
		new_position.y = bounds.top + 50
		current_wall = WallSide.TOP
	
	# Apply teleportation
	global_position = new_position
	
	# Behåll x-hastigheten, nollställ bara y-hastigheten
	velocity = Vector2(current_x_velocity, 0)
	
	start_teleport_cooldown()
	start_teleport_effect()
	
	# Update sprite rotation based on wall
	update_sprite_rotation()

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
	
	match current_wall:
		WallSide.BOTTOM:
			sprite.rotation = 0.0  # Normal orientation
		WallSide.TOP:
			sprite.rotation = PI  # Upside down
	
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
		# Optional: disable movement or restart game
		print("Player died!")

func heal(amount: int):
	current_health += amount
	current_health = min(max_health, current_health)
	health_changed.emit(current_health)

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health
