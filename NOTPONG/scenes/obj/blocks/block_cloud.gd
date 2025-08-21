extends StaticBody2D

# Cloud block settings - 4 lives, no regeneration
@export var max_health: int = 40  # 4 lives (4 hits of 10 damage each)
@export var score_value: int = 25  # Between blue and thunder blocks
@export var enemy_type: String = "cloud_block"

# Lightning attack settings (same as thunder block)
@export var lightning_delay: float = 3.0  # Längre väntetid innan första attack
@export var lightning_duration: float = 3.0  # How long lightning stays active
@export var lightning_damage_per_second: float = 15.0
@export var lightning_damage_interval: float = 0.1

# Visual settings
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var lightning_effect: Node2D = $VFX_Thunder

# All 12 cloud sprites based on health states and attack phases
var textures = {
	# Normal states (4 sprites based on health)
	"normal": preload("res://images/Cloud.png"),           # 4 lives (40-31 health)
	"normal_crack1": preload("res://images/CloudCrack1.png"),     # 3 lives (30-21 health) 
	"normal_crack2": preload("res://images/CloudCrack2.png"),     # 2 lives (20-11 health)
	"normal_crack3": preload("res://images/CloudCrack3.png"),     # 1 life (10-1 health)
	
	# Warning states - 2 seconds before attack (4 sprites)
	"warning": preload("res://images/CloudOpen.png"),           # 4 lives warning
	"warning_crack1": preload("res://images/CloudOpenCrack1.png"),     # 3 lives warning
	"warning_crack2": preload("res://images/CloudOpenCrack2.png"),     # 2 lives warning
	"warning_crack3": preload("res://images/CloudOpenCrack3.png"),     # 1 life warning
	
	# Attack states - during lightning (4 sprites) 
	"attack": preload("res://images/CloudWideOpen.png"),           # 4 lives attacking
	"attack_crack1": preload("res://images/CloudWideOpenCrack1.png"),     # 3 lives attacking
	"attack_crack2": preload("res://images/CloudWideOpenCrack2.png"),     # 2 lives attacking
	"attack_crack3": preload("res://images/CloudWideOpenCrack3.png")      # 1 life attacking
}

var current_health: int
var is_dead: bool = false
var original_color: Color

# Lightning attack variables
var lightning_timer: float = 0.0
var lightning_damage_timer: float = 0.0
var lightning_active: bool = false
var lightning_warning: bool = false
var lightning_has_started: bool = false

# Signals
signal block_died(score_points: int)
signal block_hit(damage: int)

func _ready():
	# Set up cloud block
	current_health = max_health
	
	# Store original sprite color and set same scale as block_blue
	if sprite:
		original_color = sprite.modulate
		sprite.scale = Vector2(1.563, 1.563)  # Same size as block_blue
	
	# Set up lightning effect - spawn 25px below cloud center instead of 50px
	if lightning_effect:
		# Calculate position 25px below the cloud center
		var lightning_start_pos = Vector2(global_position.x, global_position.y)
		lightning_effect.setup_vertical_thunder(lightning_start_pos)
		lightning_effect.visible = false
		
		# Connect to lightning controller signals
		if lightning_effect.has_signal("thunder_activated"):
			lightning_effect.thunder_activated.connect(_on_lightning_activated)
		if lightning_effect.has_signal("thunder_deactivated"):
			lightning_effect.thunder_deactivated.connect(_on_lightning_deactivated)
		
		print("Lightning effect configured for cloud block - spawning 25px below center")
	
	# Start lightning timer
	lightning_timer = 0.0
	
	print("Cloud Block created with ", max_health, " health (4 lives) at position: ", global_position)

func _physics_process(delta):
	if is_dead:
		return
	
	# Handle lightning timing
	lightning_timer += delta
	
	# Start warning phase after initial delay (3 seconds)
	if not lightning_warning and not lightning_has_started and lightning_timer >= lightning_delay:
		start_lightning_warning()
	
	# Start actual lightning after warning period (additional 2 seconds)
	if lightning_warning and not lightning_active and lightning_timer >= (lightning_delay + 2.0):
		start_lightning_attack()
	
	# Handle lightning damage while active
	if lightning_active:
		lightning_damage_timer += delta
		if lightning_damage_timer >= lightning_damage_interval:
			apply_lightning_damage()
			lightning_damage_timer = 0.0

func start_lightning_warning():
	"""Start the 2-second warning phase before lightning"""
	lightning_warning = true
	update_sprite()
	print("Cloud block starting lightning warning phase")

func start_lightning_attack():
	"""Start the actual lightning attack"""
	lightning_has_started = true
	lightning_warning = false
	
	if lightning_effect and lightning_effect.has_method("start_thunder"):
		lightning_effect.start_thunder()
		print("Cloud block lightning attack started")

func _on_lightning_activated():
	"""Called when the lightning controller activates"""
	lightning_active = true
	update_sprite()
	print("Cloud block received lightning activation signal")

func _on_lightning_deactivated():
	"""Called when the lightning controller deactivated"""
	lightning_active = false
	lightning_warning = false
	update_sprite()
	lightning_damage_timer = 0.0
	
	# Reset lightning timer for next cycle
	lightning_timer = 0.0
	lightning_has_started = false
	print("Cloud block lightning deactivated - resetting for next cycle")

func apply_lightning_damage():
	"""Apply continuous damage during lightning attack"""
	if not lightning_effect:
		return
	
	# Use same damage system as thunder block
	if lightning_effect.has_method("get_thunder_targets"):
		var targets = lightning_effect.get_thunder_targets()
		for target in targets:
			if target and target.has_method("take_damage"):
				var damage_amount = lightning_damage_per_second * lightning_damage_interval
				target.take_damage(damage_amount)
				print("Cloud lightning dealing ", damage_amount, " damage to ", target.name)

func take_damage(damage: int):
	if is_dead:
		return
	
	print("Cloud Block took ", damage, " damage (", current_health - damage, "/", max_health, " remaining)")
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# IMPORTANT: Force immediate sprite update when taking damage
	update_sprite()
	show_damage_effect()
	
	# Emit hit signal
	emit_signal("block_hit", damage)
	
	if current_health <= 0:
		destroy_block()

func is_alive() -> bool:
	"""Returnerar om cloud block fortfarande lever"""
	return not is_dead and current_health > 0
	
func update_sprite():
	if not sprite or is_dead:
		return
	
	# ALWAYS determine the health level first (this is most important)
	var health_level = ""
	if current_health > 30:      # 40-31 health = 4 lives
		health_level = ""
	elif current_health > 20:    # 30-21 health = 3 lives  
		health_level = "_crack1"
	elif current_health > 10:    # 20-11 health = 2 lives
		health_level = "_crack2"
	else:                        # 10-1 health = 1 life
		health_level = "_crack3"
	
	# Determine texture based on health and lightning state
	var texture_key = "normal"
	
	# Determine state (normal, warning, or attack) - but always include health level
	if lightning_active:
		# Lightning is active - use attack sprites with current health
		texture_key = "attack" + health_level
	elif lightning_warning:
		# Warning phase - use warning sprites with current health
		texture_key = "warning" + health_level
	else:
		# Normal state with current health
		texture_key = "normal" + health_level
	
	# Handle special case for full health (no suffix)
	if texture_key == "normal_":
		texture_key = "normal"
	elif texture_key == "warning_":
		texture_key = "warning"
	elif texture_key == "attack_":
		texture_key = "attack"
	
	# Apply the sprite immediately
	if textures.has(texture_key):
		sprite.texture = textures[texture_key]
		print("Cloud block health: ", current_health, "/", max_health, " - Using texture: ", texture_key)
	else:
		print("WARNING: Texture not found: ", texture_key)
		# Fallback to normal sprite if texture not found
		if textures.has("normal"):
			sprite.texture = textures["normal"]

func show_damage_effect():
	if not sprite:
		return
	
	# Flash red when hit (same as other blocks)
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
	
	# Pick a random sound and play it
	var random_sound = blop_sounds[randi() % blop_sounds.size()]
	GlobalAudioManager.play_sfx(random_sound)
	is_dead = true
	
	# Stop any active lightning
	if lightning_effect and lightning_effect.has_method("end_thunder"):
		lightning_effect.end_thunder()
	
	print("Cloud Block destroyed! Score: ", score_value)
	
	# Emit destruction signal
	emit_signal("block_died", score_value)
	
	# Queue for deletion
	queue_free()
