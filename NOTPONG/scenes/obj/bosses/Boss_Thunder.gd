extends StaticBody2D
@export var max_health: int = 100  # 3-hit kill (10 damage per hit)
@export var score_value: int = 300  # Increased score for larger block
@export var enemy_type: String = "thunder"

# Thunder settings
@export var thunder_delay: float = 2.0  # Time before thunder activates
@export var thunder_duration: float = 3.0  # How long thunder stays active
@export var thunder_damage_per_second: float = 15.0
@export var thunder_damage_interval: float = 0.1

# Movement and teleportation settings
@export var y_movement_range: float = 50.0  # Max movement in Y direction
@export var teleport_distance: float = 50.0  # Distance to teleport in X direction
var original_spawn_position: Vector2
var current_teleport_position: int = 0  # -2, -1, 0, +1, +2 (relative to spawn)
var hit_counter: int = 0  # Count hits to trigger teleport every other hit
var y_movement_timer: float = 0.0
var y_movement_speed: float = 30.0  # Pixels per second
var y_direction: int = 1  # 1 for up, -1 for down

# Node references
@onready var sprite: Sprite2D = %Sprite2D
@onready var thunder_effect: Node2D = $VFX_Thunder
@onready var collision_shape: CollisionShape2D = %CollisionShape2D

# Textures for different states - adjust paths as needed
var textures = {
	"normal": preload("res://images/bosses/Boss2.png"),
	"crack1": preload("res://images/bosses/Boss2Cracked1.png"),
	"crack2": preload("res://images/bosses/Boss2Cracked2.png"),
	"crack3": preload("res://images/bosses/Boss2Cracked3.png"),
	"crack4": preload("res://images/bosses/Boss2Cracked4.png"),
	"attack": preload("res://images/bosses/Boss2Attack.png"),
	"attack_crack1": preload("res://images/bosses/Boss2Attack1.png"),
	"attack_crack2": preload("res://images/bosses/Boss2Attack2.png"),
	"attack_crack3": preload("res://images/bosses/Boss2Attack3.png"),
	"attack_crack4": preload("res://images/bosses/Boss2Attack4.png")
}

# State variables
var current_health: int
var is_dead: bool = false
var thunder_timer: float = 0.0
var thunder_damage_timer: float = 0.0
var thunder_active: bool = false
var thunder_has_started: bool = false
var original_color: Color

# Signals
signal block_destroyed(score: int)

func _ready():
	current_health = max_health
	
	# Store original spawn position for teleport calculations
	original_spawn_position = global_position
	
	# Add random offset to movement timer so bosses don't move in sync
	y_movement_timer = randf() * 2.0
	
	# Store original sprite color
	if sprite:
		original_color = sprite.modulate
		sprite.scale = Vector2(3.125, 3.125)
	
	# Start thunder timer
	thunder_timer = 0.0
	
	# Set up thunder effect and connect its signals
	if thunder_effect:
		# FIXED: Pass boss position to setup_vertical_thunder
		thunder_effect.setup_vertical_thunder(global_position)
		thunder_effect.visible = false
		
		# Connect to thunder controller signals
		if thunder_effect.has_signal("thunder_activated"):
			thunder_effect.thunder_activated.connect(_on_thunder_activated)
		if thunder_effect.has_signal("thunder_deactivated"):
			thunder_effect.thunder_deactivated.connect(_on_thunder_deactivated)
		
		print("Thunder effect configured and signals connected for boss at position: ", global_position)
	
	print("Thunder boss created with ", max_health, " health at spawn position: ", original_spawn_position)

func _physics_process(delta):
	if is_dead:
		return
	
	# Handle Y-axis movement (continuous floating)
	handle_y_movement(delta)
	
	# Handle thunder timing
	thunder_timer += delta
	
	# Start thunder system after initial delay
	if not thunder_has_started and thunder_timer >= thunder_delay:
		start_thunder_system()
	
	# Handle thunder damage while active
	if thunder_active:
		thunder_damage_timer += delta
		if thunder_damage_timer >= thunder_damage_interval:
			apply_thunder_damage()
			thunder_damage_timer = 0.0

func handle_y_movement(delta):
	"""Handle continuous Y-axis floating movement"""
	y_movement_timer += delta
	
	# Create smooth sine wave movement
	var y_offset = sin(y_movement_timer * y_movement_speed / 30.0) * y_movement_range
	var target_x = original_spawn_position.x + (current_teleport_position * teleport_distance)
	var target_y = original_spawn_position.y + y_offset
	
	global_position = Vector2(target_x, target_y)

func teleport_boss():
	"""Teleport boss in X direction based on current position and constraints"""
	var possible_directions = []
	
	# Check which directions are allowed
	if current_teleport_position > -2:  # Can go left
		possible_directions.append(-1)
	if current_teleport_position < 2:   # Can go right
		possible_directions.append(1)
	
	if possible_directions.size() == 0:
		print("Boss cannot teleport - at maximum range")
		return
	
	# Choose random direction from available options
	var direction = possible_directions[randi() % possible_directions.size()]
	current_teleport_position += direction
	
	# Create teleport effect
	create_teleport_effect()
	
	var direction_text = "left" if direction == -1 else "right"
	print("Boss teleported ", direction_text, " - new teleport position: ", current_teleport_position)

func create_teleport_effect():
	"""Visual effect for teleportation"""
	if not sprite:
		return
	
	# Flash white briefly for teleport effect
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", original_color, 0.1)

func start_thunder_system():
	"""Start the continuous thunder cycling system"""
	thunder_has_started = true
	
	if thunder_effect and thunder_effect.has_method("start_thunder"):
		# FIXED: Make sure thunder effect knows correct position before starting
		if thunder_effect.has_method("setup_vertical_thunder"):
			thunder_effect.setup_vertical_thunder(global_position)
		thunder_effect.start_thunder()
		print("Thunder cycling system started on boss at position: ", global_position)

# Signal handlers for thunder state changes
func _on_thunder_activated():
	"""Called when the thunder controller activates lightning"""
	thunder_active = true
	update_sprite()
	print("Boss thunder received activation signal - updating sprite")

func _on_thunder_deactivated():
	"""Called when the thunder controller deactivates lightning"""
	thunder_active = false
	update_sprite()
	thunder_damage_timer = 0.0  # Reset damage timer
	print("Boss thunder received deactivation signal - updating sprite")

func apply_thunder_damage():
	"""Apply continuous damage to whatever the thunder is hitting"""
	if not thunder_effect:
		return
	
	# If thunder effect has a method to check for collisions, use it
	if thunder_effect.has_method("get_thunder_targets"):
		var targets = thunder_effect.get_thunder_targets()
		for target in targets:
			if target and target.has_method("take_damage"):
				var damage_amount = thunder_damage_per_second * thunder_damage_interval
				target.take_damage(damage_amount)
				print("Boss thunder dealing ", damage_amount, " damage to ", target.name)

func take_damage(damage: int):
	if is_dead:
		return
	
	print("Boss thunder took ", damage, " damage. Health: ", current_health, " -> ", (current_health - damage))
	
	current_health -= damage
	current_health = max(0, current_health)
	hit_counter += 1
	
	# Teleport every other hit (every 2nd hit)
	if hit_counter % 2 == 0:
		teleport_boss()
	
	update_sprite()
	show_damage_effect()
	
	if current_health <= 0:
		destroy_block()

func update_sprite():
	if not sprite or is_dead:
		return
	
	# Determine texture based on health and thunder state
	var texture_key = "normal"
	
	if thunder_active:
		# Thunder is active - use attack versions
		if current_health > 80:
			texture_key = "attack"
		elif current_health > 60:
			texture_key = "attack_crack1"
		elif current_health > 40: 
			texture_key = "attack_crack2"
		elif current_health > 20:
			texture_key = "attack_crack3"
		else: 
			texture_key = "attack_crack4"
	else:
		# Thunder is inactive - use normal versions
		if current_health > 80: 
			texture_key = "normal"
		elif current_health > 60:
			texture_key = "crack1"
		elif current_health > 40:
			texture_key = "crack2"
		elif current_health > 20:
			texture_key = "crack3"
		else: 
			texture_key = "crack4"
	
	if textures.has(texture_key):
		sprite.texture = textures[texture_key]
		print("Boss thunder health: ", current_health, "/", max_health, " - Using texture: ", texture_key, " (thunder_active: ", thunder_active, ")")

func show_damage_effect():
	if not sprite:
		return
	
	# Flash red when hit
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", original_color, 0.1)

func destroy_block():
	if is_dead:
		return
	
	is_dead = true
	print("Boss thunder destroyed! Awarding ", score_value, " points")
	
	# Stop thunder system before dying
	if thunder_effect and thunder_effect.has_method("end_thunder"):
		thunder_effect.end_thunder()
	
	# Emit destruction signal with score
	block_destroyed.emit(score_value)
	
	play_death_effect()

func play_death_effect():
	if not sprite:
		queue_free()
		return
	
	# Disable collision immediately
	if collision_shape:
		collision_shape.disabled = true
	
	# Lock position so it doesn't move
	var original_position = sprite.position
	
	# Death animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Shrink the scale
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2)
	
	# Keep position fixed during animation
	tween.tween_method(
		func(pos): sprite.position = pos,
		original_position, 
		original_position, 
		0.2
	)
	
	# Destroy after animation
	await tween.finished
	queue_free()

func _on_body_entered(body):
	# Handle collision with player/projectiles
	if body.has_method("take_damage"):
		body.take_damage(1)
	if body.has_method("destroy"):
		body.destroy()

# Utility methods
func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return not is_dead and current_health > 0
