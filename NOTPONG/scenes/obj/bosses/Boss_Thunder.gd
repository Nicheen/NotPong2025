extends AnimatableBody2D
@export var max_health: int = 100  
@export var score_value: int = 300  
@export var enemy_type: String = "thunder"

# Thunder settings
@export var thunder_delay: float = 2.0  
@export var thunder_duration: float = 3.0  
@export var thunder_damage_per_second: float = 15.0
@export var thunder_damage_interval: float = 0.1


@export var should_start_dialogue: bool = false

# Movement and teleportation settings
@export var y_movement_range: float = 50.0  
@export var teleport_distance: float = 50.0  
var original_spawn_position: Vector2
var current_teleport_position: int = 0  
var hit_counter: int = 0  
var y_movement_timer: float = 0.0
var y_movement_speed: float = 30.0  
var y_direction: int = 1  
@export var min_teleport_position: int = -2  # Default minimum (2 steps left)
@export var max_teleport_position: int = 2   # Default maximum (2 steps right)
# Node references
@onready var sprite: Sprite2D = %Sprite2D
@onready var thunder_effect: Node2D = %VFX_Thunder
@onready var boss_collision: StaticBody2D = $Boss
@onready var cloud_collision: StaticBody2D = $Cloud

const lines: Array[String] = [
	"Lightning strikes twice!",
	"You cannot escape the storm!",
	"Thunder roars above!"
]
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
	
	if should_start_dialogue:
		print("Thunder boss starting dialogue")
		DialogueManager.start_dialog(self, lines, Vector2(0, -150))
	# Start dialogue if this is the center boss (check position)
	# Center position is around x=576, with some tolerance
	if abs(global_position.x - 576) < 10:
		print("Thunder boss (center) starting dialogue")
		DialogueManager.start_dialog(self, lines, Vector2(0, -150))
	
	# CRITICAL FIX: Set collision layers properly
	# Boss part should be on damage layer (2)
	if boss_collision:
		boss_collision.collision_layer = 2  # Damage layer - projectiles deal damage and are destroyed
		boss_collision.collision_mask = 0   # Don't detect anything
		print("Boss collision set to damage layer (2)")
		
		# Connect collision signal if not already connected
		if boss_collision.has_signal("body_entered") and not boss_collision.body_entered.is_connected(_on_boss_hit):
			boss_collision.body_entered.connect(_on_boss_hit)
	
	# Cloud part should be on bounce layer (4) like armoured boss
	if cloud_collision:
		cloud_collision.collision_layer = 4  # Bounce layer - projectiles bounce off
		cloud_collision.collision_mask = 0   # Don't detect anything  
		print("Cloud collision set to bounce layer (4)")
	
	# Set up thunder effect
	if thunder_effect:
		thunder_effect.setup_vertical_thunder(global_position)
		thunder_effect.visible = false
		
		# Method 2: Modulate specific components (more control)
		var lightning_line = thunder_effect.get_node_or_null("Lightning")
		if lightning_line:
			lightning_line.modulate = Color.PALE_TURQUOISE

		var sparks = thunder_effect.get_node_or_null("Sparks")
		if sparks:
			sparks.modulate = Color.MEDIUM_TURQUOISE
			
		var flare = thunder_effect.get_node_or_null("Flare") 
		if flare:
			flare.modulate = Color.MEDIUM_TURQUOISE

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
	
	# Check if we can move left (respecting the minimum limit)
	if current_teleport_position > min_teleport_position:  
		possible_directions.append(-1)
	
	# Check if we can move right (respecting the maximum limit)
	if current_teleport_position < max_teleport_position:   
		possible_directions.append(1)
	
	if possible_directions.size() == 0:
		print("Boss cannot teleport - at position limits (", min_teleport_position, " to ", max_teleport_position, ")")
		return
	
	# Choose a random valid direction
	var direction = possible_directions[randi() % possible_directions.size()]
	current_teleport_position += direction
	create_teleport_effect()
	
	var direction_text = "left" if direction == -1 else "right"
	print("Boss teleported ", direction_text, " - new position: ", current_teleport_position, 
		  " (limits: ", min_teleport_position, " to ", max_teleport_position, ")")

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

# NEW: Dedicated handler for boss hits (called by projectile's collision system)
func _on_boss_hit(body):
	"""Called when boss part is hit by a projectile"""
	if body.name.contains("Projectile"):
		print("Boss part hit by projectile - taking damage")
		# The projectile handles its own destruction when hitting damage layer
		# We just need to register the damage here
		# Damage is already applied by the projectile itself via take_damage

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
	if boss_collision:
		boss_collision.collision_layer = 0
		boss_collision.collision_mask = 0
	if cloud_collision:
		cloud_collision.collision_layer = 0
		cloud_collision.collision_mask = 0
	
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
