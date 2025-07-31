extends StaticBody2D

# Block settings
@export var max_health: int = 30  # 3-hit kill (10 damage per hit)
@export var score_value: int = 30  # Increased score for larger block
@export var enemy_type: String = "thunder"

# Thunder settings
@export var thunder_delay: float = 2.0  # Time before thunder activates
@export var thunder_duration: float = 3.0  # How long thunder stays active
@export var thunder_damage_per_second: float = 15.0
@export var thunder_damage_interval: float = 0.1

# Node references
@onready var sprite: Sprite2D = %Sprite2D
@onready var thunder_effect: Node2D = $VFX_Thunder
@onready var collision_shape: CollisionShape2D = %CollisionShape2D

# Textures for different states - adjust paths as needed
var textures = {
	"normal": preload("res://images/BlockThunder.png"),
	"attack": preload("res://images/BlockThunderAttack.png"),
	"crack1": preload("res://images/BlockThunderCrack1.png"),
	"crack2": preload("res://images/BlockThunderCrack2.png"),
	"attack_crack1": preload("res://images/BlockThunderAttackCrack1.png"),
	"attack_crack2": preload("res://images/BlockThunderAttackCrack2.png")
}

# State variables
var current_health: int
var is_dead: bool = false
var thunder_timer: float = 0.0
var thunder_damage_timer: float = 0.0  # Timer for damage intervals
var thunder_active: bool = false
var original_color: Color

# Signals - match the main scene's expected signal name
signal block_destroyed(score: int)

func _ready():
	current_health = max_health
	collision_layer = 16  # Enemy layer
	collision_mask = 2    # Hit by projectiles
	
	# Store original sprite color
	if sprite:
		original_color = sprite.modulate
		# Ensure thunder block is properly sized (2x2 = 100x100 pixels)
		# The sprite scale should be adjusted to make it 2x2 grid spaces
		sprite.scale = Vector2(3.125, 3.125)  # Adjust based on your base sprite size
	
	# Start thunder timer
	thunder_timer = 0.0
	
	# Hide thunder effect initially
	if thunder_effect:
		thunder_effect.visible = false
	
	print("Thunder block created with ", max_health, " health at position: ", global_position)

func _physics_process(delta):
	if is_dead:
		return
	
	# Handle thunder timing
	thunder_timer += delta
	
	# Activate thunder after delay
	if not thunder_active and thunder_timer >= thunder_delay:
		activate_thunder()
	
	# Handle thunder damage while active
	if thunder_active:
		thunder_damage_timer += delta
		if thunder_damage_timer >= thunder_damage_interval:
			apply_thunder_damage()
			thunder_damage_timer = 0.0
	
	# Deactivate thunder after duration
	if thunder_active and thunder_timer >= thunder_delay + thunder_duration:
		deactivate_thunder()

func activate_thunder():
	thunder_active = true
	update_sprite()
	
	if thunder_effect:
		thunder_effect.visible = true
		# If thunder effect has activation method, call it
		if thunder_effect.has_method("activate_thunder"):
			thunder_effect.activate_thunder()
	
	print("Thunder activated on thunder block at: ", global_position)

func deactivate_thunder():
	thunder_active = false
	update_sprite()
	
	if thunder_effect:
		thunder_effect.visible = false
		# If thunder effect has deactivation method, call it
		if thunder_effect.has_method("deactivate_thunder"):
			thunder_effect.deactivate_thunder()
	
	# Reset timer for next cycle
	thunder_timer = 0.0
	thunder_damage_timer = 0.0
	
	print("Thunder deactivated on thunder block")

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
				print("Thunder dealing ", damage_amount, " damage to ", target.name)
	
	# Alternative: Check for bodies in thunder area using Area2D
	# This would require your thunder effect to have an Area2D component

func take_damage(damage: int):
	if is_dead:
		return
	
	print("Thunder block took ", damage, " damage. Health: ", current_health, " -> ", (current_health - damage))
	
	current_health -= damage
	current_health = max(0, current_health)
	
	update_sprite()  # Update sprite immediately after health change
	show_damage_effect()
	
	if current_health <= 0:
		destroy_block()

func update_sprite():
	if not sprite or is_dead:
		return
	
	# Determine texture based on health and thunder state
	var health_ratio = float(current_health) / float(max_health)
	var texture_key = "normal"
	
	# Health states: 30hp = normal, 20hp = crack1, 10hp = crack2, 0hp = dead
	if thunder_active:
		# Thunder is active - use attack versions
		if current_health > 20:  # 30-21 hp = normal attack
			texture_key = "attack"
		elif current_health > 10:  # 20-11 hp = crack1 attack
			texture_key = "attack_crack1"
		else:  # 10-1 hp = crack2 attack
			texture_key = "attack_crack2"
	else:
		# Thunder is inactive - use normal versions
		if current_health > 20:  # 30-21 hp = normal
			texture_key = "normal"
		elif current_health > 10:  # 20-11 hp = crack1
			texture_key = "crack1"
		else:  # 10-1 hp = crack2
			texture_key = "crack2"
	
	if textures.has(texture_key):
		sprite.texture = textures[texture_key]
		print("Thunder block health: ", current_health, "/", max_health, " - Using texture: ", texture_key)

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
	print("Thunder block destroyed! Awarding ", score_value, " points")
	
	# Deactivate thunder before dying
	if thunder_active:
		deactivate_thunder()
	
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
