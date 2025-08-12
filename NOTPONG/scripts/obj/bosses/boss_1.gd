extends StaticBody2D

# Enemy settings
@export var max_health: int = 240
@export var score_value: int = 500  # Points awarded when killed
@export var enemy_type: String = "boss"

# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")


var textures = {
	"normal": preload("res://images/bosses/Boss1.png"),
	"crack1": preload("res://images/bosses/Boss1Cracked1.png"),
	"crack2": preload("res://images/bosses/Boss1Cracked2.png"),
	"crack3": preload("res://images/bosses/Boss1Cracked3.png"),
	"crack4": preload("res://images/bosses/Boss1Cracked4.png"),
	"crack5": preload("res://images/bosses/Boss1Cracked5.png"),
	"crack6": preload("res://images/bosses/Boss1Cracked6.png"),
	"armour": preload("res://images/bosses/Boss1Armour1&2.png"),
	"armour_crack3": preload("res://images/bosses/Boss1Armour3.png"),
	"armour_crack4": preload("res://images/bosses/Boss1Armour4.png"),
	"armour_crack5": preload("res://images/bosses/Boss1Armour5.png"),
	"armour_crack6": preload("res://images/bosses/Boss1Armour6.png"),
}
# Internal variables
var current_health: int
var is_dead: bool = false
var armour_duration: float = randf_range(4.0, 6.0)
var armour_active: bool = false
var original_color: Color
var armour_timer: float = 0.0
var is_transitioning: bool = false
var original_rotation: float = 0.0
var armour_rotation: float = 0.0

var activate_armour_duration: float = randf_range(2.0, 6.0)
var activate_armour_timer: float = 0.0


var spawn_position: Vector2  # Where boss spawned
var movement_timer: float = 0.0
var movement_speed: float = 0.4  # 5x långsammare (var 2.0, nu 0.4)
var current_pattern: String = "horizontal_eight"  # "horizontal_eight" or "vertical_eight"
var pattern_loop_count: int = 0
var is_moving: bool = true

# Movement boundaries (from spawn position)
var max_horizontal_range: float = 200.0  # 150 pixels left/right
var max_vertical_range: float = 100.0    # 100 pixels up/down
# Signals
signal boss_died(score_points: int)
signal boss_hit(damage: int)

func _ready():
	# Set up enemy
	current_health = max_health
	
	spawn_position = global_position
	
	# Choose random starting pattern
	var patterns = ["horizontal_eight", "vertical_eight"]
	current_pattern = patterns[randi() % 2]
	
	# Choose random starting direction within pattern
	movement_timer = randf() * TAU  # Random point in the pattern cycle
	# Store original sprite color
	if sprite:
		original_color = sprite.modulate
	
	# Set up health bar if it exists
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	# Position enemy in middle of screen (or wherever you want)
	# This can be overridden when spawning
	
	print("Enemy created with ", max_health, " health at position: ", global_position)

func deactivate_armoured_mode():
	"""Simple armoured mode deactivation"""
	
	print("🛡️ DEACTIVATING ARMOURED MODE")
	
	armour_active = false
	is_transitioning = true
	collision_layer = 2  # Back to enemy layer
	
	var tween = create_tween()
	tween.tween_property(sprite, "rotation_degrees", original_rotation, 0.25)
	
	await tween.finished
	
	is_transitioning = false
	pause_movement()
	armour_active = false
	update_sprite()
	resume_movement()

	print("🛡️ ARMOURED MODE DEACTIVATED")
	
	
	
func _physics_process(delta):
	# Handle armoured mode timing
	if not is_dead and is_moving and not is_transitioning:
		update_movement_pattern(delta)
	if armour_active and not is_transitioning:
		armour_timer += delta
		if armour_timer >= armour_duration:
			armour_timer = 0.0
			armour_duration = randf_range(4.0, 6.0)
			deactivate_armoured_mode()
			
	if not armour_active and not is_transitioning:
		activate_armour_timer += delta
		if activate_armour_timer >= activate_armour_duration:
			activate_armour_timer = 0.0
			activate_armour_duration = randf_range(2.0, 6.0)
			activate_armoured_mode()

func take_damage(damage: int):
	if is_dead:
		print("   Boss already dead - ignoring")
		return
	
	# If armoured, block damage and show effect
	if armour_active:
		print("   🛡️ DAMAGE BLOCKED BY ARMOUR!")
		show_armour_block_effect()
		GlobalAudioManager.play_sfx(preload("res://audio/noels/thud1.wav"))
		return
	
	# Apply damage - EXAKT som andra enemies
	var old_health = current_health
	current_health -= damage
	current_health = max(0, current_health)
	
	print("   Health changed: ", old_health, " -> ", current_health)
	
	# Update health bar - EXAKT som andra enemies
	if health_bar:
		health_bar.value = current_health
	if current_health <= 0:
		die()
		is_moving = false

	# Update sprite
	update_sprite()
	
	# Visual feedback - EXAKT som andra enemies
	show_damage_effect()
	if current_health % 50 == 0:
		activate_armoured_mode()
	
func update_movement_pattern(delta):
	"""Update boss movement in figure-8 patterns"""
	movement_timer += delta * movement_speed
	
	# Check if we completed a full loop (2π radians)
	if movement_timer >= TAU:
		movement_timer = 0.0  # Reset to 0 för smooth transition
		pattern_loop_count += 1
		switch_movement_pattern()
	
	# Calculate position based on current pattern
	var new_position = calculate_pattern_position()
	
	# Smooth movement - använd move_toward för jämn övergång
	var movement_step = 200.0 * delta  # Pixels per second movement speed
	global_position = global_position.move_toward(new_position, movement_step)

func calculate_pattern_position() -> Vector2:
	"""Calculate position based on current movement pattern"""
	var x_offset: float
	var y_offset: float
	
	match current_pattern:
		"horizontal_eight":
			# Liggande åtta (∞) - horizontal figure-8
			x_offset = sin(movement_timer) * max_horizontal_range
			y_offset = sin(movement_timer * 2) * max_vertical_range * 0.5  # Halverad höjd
			
		"vertical_eight":
			# Stående åtta (8) - vertical figure-8  
			x_offset = sin(movement_timer * 2) * max_horizontal_range * 0.5  # Halverad bredd
			y_offset = sin(movement_timer) * max_vertical_range
			
		_:
			x_offset = 0
			y_offset = 0
	
	return spawn_position + Vector2(x_offset, y_offset)

func switch_movement_pattern():
	"""Switch between horizontal and vertical figure-8 patterns"""
	# Switch pattern
	if current_pattern == "horizontal_eight":
		current_pattern = "vertical_eight"
	else:
		current_pattern = "horizontal_eight"
	
	# Add small random offset for variation (inte för stor för smooth transition)
	movement_timer = randf() * 0.5  # Bara liten variation
	
	print("🔄 Boss switching to ", current_pattern, " pattern (Loop ", pattern_loop_count, ")")

func pause_movement():
	"""Pause movement (useful during armoured transitions)"""
	is_moving = false
	print("⏸️ Boss movement paused")

func resume_movement():
	"""Resume movement"""
	is_moving = true
	print("▶️ Boss movement resumed")
	
func show_armour_block_effect():
	"""Blue flash when armour blocks"""
	if not sprite:
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.CYAN, 0.1)
	tween.tween_property(sprite, "modulate", original_color, 0.1)
	
func update_sprite():
	if not sprite or is_dead:
		return
	print("Changing Sprite..." + str(armour_active))
	# Determine texture based on health and thunder state
	var health_ratio = float(current_health) / float(max_health)
	var texture_key = "normal"
	
	if armour_active:
		if current_health > 160:  # 30-21 hp = normal attack
			texture_key = "armour"
		elif current_health > 120:  # 20-11 hp = crack1 attack
			texture_key = "armour_crack3"
		elif current_health > 80:  # 20-11 hp = crack1 attack
			texture_key = "armour_crack4"
		elif current_health > 40:  # 20-11 hp = crack1 attack
			texture_key = "armour_crack5"
		else:  # 10-1 hp = crack2 attack
			texture_key = "armour_crack6"
	else:
		# Thunder is inactive - use normal versions
		if current_health > 230:  # 30-21 hp = normal attack
			texture_key = "normal"
		elif current_health > 200:	
			texture_key = "crack1"
		elif current_health > 160:  # 20-11 hp = crack1 attack
			texture_key = "crack2"
		elif current_health > 120:  # 20-11 hp = crack1 attack
			texture_key = "crack3"
		elif current_health > 80:  # 20-11 hp = crack1 attack
			texture_key = "crack4"
		elif current_health > 40:  # 20-11 hp = crack1 attack
			texture_key = "crack5"
		else:  # 10-1 hp = crack2 attack
			texture_key = "crack6"
	
	if textures.has(texture_key):
		sprite.texture = textures[texture_key]
		print("Thunder block health: ", current_health, "/", max_health, " - Using texture: ", texture_key)

func activate_armoured_mode():
	"""Simple armoured mode activation"""

	if armour_active or is_transitioning:
		return
	
	print("🛡️ ACTIVATING ARMOURED MODE")
	
	# Choose rotation direction
	var directions = [45.0, -45.0]
	armour_rotation = original_rotation + directions[randi() % 2]
	
	print("   Rotating from ", sprite.rotation_degrees, " to ", armour_rotation)
	
	is_transitioning = true
	pause_movement()
	var tween = create_tween()
	tween.tween_property(sprite, "rotation_degrees", armour_rotation, 0.25)
	
	await tween.finished
	
	# Activate armour
	armour_active = true
	is_transitioning = false
	armour_timer = 0.0
	collision_layer = 4  # Wall layer for bouncing projectiles
	
	update_sprite()
	resume_movement()
	print("🛡️ ARMOURED MODE ACTIVE - Collision layer: ", collision_layer)

func die():
	if is_dead:
		return
	
	is_dead = true
	print("Enemy died! Awarding ", score_value, " points")
	
	# Emit death signal with score
	boss_died.emit(score_value)
	
	play_death_effect()
	
	
	
func show_damage_effect():
	if not sprite:
		return
	
	# Flash red when hit
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", original_color, 0.1)

func play_death_effect():
	if not sprite:
		queue_free()
		return
	
	# Disable collision immediately
	if collision_shape:
		collision_shape.disabled = true
	
	# Hide health bar
	if health_bar:
		health_bar.visible = false
	
	# Lås positionen så den inte rör sig
	var original_position = sprite.position
	
	# Supersnabb effekt - bara 0.1 sekunder
	var tween = create_tween()
	tween.set_parallel(true)  # Tillåt parallella animationer
	
	# Krymper skalan
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.1)
	
	# Håll positionen fast under hela animationen
	tween.tween_method(
		func(pos): sprite.position = pos,
		original_position, 
		original_position, 
		0.1
	)
	
	# Förstör direkt efter
	await tween.finished
	queue_free()
	
func get_movement_info() -> Dictionary:
	"""Get movement state info for debugging"""
	return {
		"current_pattern": current_pattern,
		"movement_timer": movement_timer,
		"pattern_loop_count": pattern_loop_count,
		"is_moving": is_moving,
		"spawn_position": spawn_position,
		"current_position": global_position,
		"target_position": calculate_pattern_position()
	}
func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return not is_dead and current_health > 0

# Method called when projectile hits this enemy
func _on_projectile_hit():
	take_damage(10)  # Default damage from projectiles
