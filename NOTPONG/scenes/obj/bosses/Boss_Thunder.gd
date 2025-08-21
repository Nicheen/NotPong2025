extends AnimatableBody2D
@export var max_health: int = 100  
@export var score_value: int = 300  
@export var enemy_type: String = "thunder"

# Thunder settings
@export var thunder_delay: float = 2.0  
@export var thunder_duration: float = 3.0  
@export var thunder_damage_per_second: float = 15.0
@export var thunder_damage_interval: float = 0.1

# Movement and teleportation settings
@export var y_movement_range: float = 50.0  
@export var teleport_distance: float = 50.0  
var original_spawn_position: Vector2
var current_teleport_position: int = 0  
var hit_counter: int = 0  
var y_movement_timer: float = 0.0
var y_movement_speed: float = 30.0  
var y_direction: int = 1  

# Node references
@onready var sprite: Sprite2D = %Sprite2D
@onready var thunder_effect: Node2D = $VFX_Thunder
@onready var boss_collision: StaticBody2D = $Boss
@onready var cloud_collision: StaticBody2D = $Cloud

# Textures for different states
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
	original_spawn_position = global_position
	y_movement_timer = randf() * 2.0
	
	if sprite:
		original_color = sprite.modulate
		sprite.scale = Vector2(3.125, 3.125)
	
	thunder_timer = 0.0
	
	# Set up thunder effect
	if thunder_effect:
		thunder_effect.setup_vertical_thunder(global_position)
		thunder_effect.visible = false
		
		if thunder_effect.has_signal("thunder_activated"):
			thunder_effect.thunder_activated.connect(_on_thunder_activated)
		if thunder_effect.has_signal("thunder_deactivated"):
			thunder_effect.thunder_deactivated.connect(_on_thunder_deactivated)
		
		print("Thunder effect configured at position: ", global_position)
	
	print("Thunder boss created with ", max_health, " health at spawn position: ", original_spawn_position)

func _physics_process(delta):
	if is_dead:
		return
	
	handle_y_movement(delta)
	
	thunder_timer += delta
	
	if not thunder_has_started and thunder_timer >= thunder_delay:
		start_thunder_system()
	
	if thunder_active:
		thunder_damage_timer += delta
		if thunder_damage_timer >= thunder_damage_interval:
			apply_thunder_damage()
			thunder_damage_timer = 0.0

func handle_y_movement(delta):
	y_movement_timer += delta
	var y_offset = sin(y_movement_timer * y_movement_speed / 30.0) * y_movement_range
	var target_x = original_spawn_position.x + (current_teleport_position * teleport_distance)
	var target_y = original_spawn_position.y + y_offset
	global_position = Vector2(target_x, target_y)

func teleport_boss():
	var possible_directions = []
	
	if current_teleport_position > -2:  
		possible_directions.append(-1)
	if current_teleport_position < 2:   
		possible_directions.append(1)
	
	if possible_directions.size() == 0:
		print("Boss cannot teleport - at maximum range")
		return
	
	var direction = possible_directions[randi() % possible_directions.size()]
	current_teleport_position += direction
	create_teleport_effect()
	
	var direction_text = "left" if direction == -1 else "right"
	print("Boss teleported ", direction_text, " - new teleport position: ", current_teleport_position)

func create_teleport_effect():
	if not sprite:
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", original_color, 0.1)

func start_thunder_system():
	thunder_has_started = true
	
	if thunder_effect and thunder_effect.has_method("start_thunder"):
		if thunder_effect.has_method("setup_vertical_thunder"):
			thunder_effect.setup_vertical_thunder(global_position)
		thunder_effect.start_thunder()
		print("Thunder cycling system started on boss at position: ", global_position)

func _on_thunder_activated():
	thunder_active = true
	update_sprite()
	print("Boss thunder received activation signal - updating sprite")

func _on_thunder_deactivated():
	thunder_active = false
	update_sprite()
	thunder_damage_timer = 0.0  
	print("Boss thunder received deactivation signal - updating sprite")

func apply_thunder_damage():
	if not thunder_effect:
		return
	
	if thunder_effect.has_method("get_thunder_targets"):
		var targets = thunder_effect.get_thunder_targets()
		for target in targets:
			if target and target.has_method("take_damage"):
				var damage_amount = thunder_damage_per_second * thunder_damage_interval
				target.take_damage(damage_amount)
				print("Boss thunder dealing ", damage_amount, " damage to ", target.name)

# Use the original collision detection method with body_entered
func _on_body_entered(body):
	"""Handle collision with projectiles"""
	if not body.name.contains("Projectile"):
		return
	
	# Get the collision point to determine if it hit boss or cloud part
	var collision_point = body.global_position
	var boss_center = global_position
	
	# Simple check: if projectile is in upper half, it hit boss; lower half = cloud
	if collision_point.y < boss_center.y:
		# Hit boss part - take damage
		print("Projectile hit boss part")
		take_damage(10)
		if body.has_method("queue_free"):
			body.queue_free()
	else:
		# Hit cloud part - bounce
		print("Projectile hit cloud part - bouncing")
		if body.has_method("linear_velocity"):
			var current_velocity = body.linear_velocity
			var bounce_velocity = Vector2(current_velocity.x * 0.8, -abs(current_velocity.y) * 0.8)
			body.linear_velocity = bounce_velocity
			body.global_position += Vector2(0, -10)  # Separate to prevent multiple hits

func take_damage(damage: int):
	if is_dead:
		return
	
	print("Boss thunder took ", damage, " damage. Health: ", current_health, " -> ", (current_health - damage))
	
	current_health -= damage
	current_health = max(0, current_health)
	hit_counter += 1
	
	# Teleport every other hit
	if hit_counter % 2 == 0:
		teleport_boss()
	
	update_sprite()
	show_damage_effect()
	
	if current_health <= 0:
		destroy_block()

func update_sprite():
	if not sprite or is_dead:
		return
	
	var texture_key = "normal"
	
	if thunder_active:
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
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", original_color, 0.1)

func destroy_block():
	if is_dead:
		return
	
	var blop_sounds = [
		preload("res://audio/noels/blop1.wav"),
		preload("res://audio/noels/blop2.wav"),
		preload("res://audio/noels/blop3.wav")
	]
	
	var random_sound = blop_sounds[randi() % blop_sounds.size()]
	GlobalAudioManager.play_sfx(random_sound)
	is_dead = true
	print("Boss thunder destroyed! Awarding ", score_value, " points")
	
	if thunder_effect and thunder_effect.has_method("end_thunder"):
		thunder_effect.end_thunder()
	
	block_destroyed.emit(score_value)
	play_death_effect()

func play_death_effect():
	if not sprite:
		queue_free()
		return
	
	# Disable all collisions immediately
	collision_layer = 0
	collision_mask = 0
	
	var original_position = sprite.position
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2)
	tween.tween_method(
		func(pos): sprite.position = pos,
		original_position, 
		original_position, 
		0.2
	)
	
	await tween.finished
	queue_free()

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return not is_dead and current_health > 0
