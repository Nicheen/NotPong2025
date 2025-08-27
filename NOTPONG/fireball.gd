extends RigidBody2D

# Fireball settings  
@export var damage: int = 20
@export var fireball_speed: float = 200.0

# Visual components
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Fireball properties
var is_enemy_fireball: bool = true  # This damages the player
var direction: Vector2 = Vector2.ZERO

# World boundaries (set when initialized)
var world_bounds: Rect2

func _ready():
	# Set up fireball physics
	gravity_scale = 0  # No gravity, controlled movement
	contact_monitor = true
	max_contacts_reported = 10
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)
	
	# Set default world bounds
	world_bounds = Rect2(150, 0, 752, 648)
	
	print("🔥 Fireball created")

func initialize(drop_direction: Vector2, speed: float):
	"""Initialize the fireball with direction and speed"""
	direction = drop_direction.normalized()
	fireball_speed = speed
	
	# Set the velocity
	linear_velocity = direction * fireball_speed
	
	print("🔥 Fireball initialized - Direction: ", direction, " Speed: ", speed)

func _physics_process(delta):
	# Check if fireball is out of bounds
	check_boundaries()

func check_boundaries():
	"""Check if fireball is outside world bounds and destroy it"""
	if not world_bounds.has_point(global_position):
		print("🔥 Fireball out of bounds, destroying")
		queue_free()

func _on_body_entered(body):
	"""Handle collision with other bodies"""
	print("🔥 Fireball collided with: ", body.name, " (Layer: ", body.collision_layer, ")")
	
	# Check collision layers and handle accordingly
	match body.collision_layer:
		1:  # Player layer
			hit_player(body)
		2:  # Damage block layer (enemies/blocks)
			hit_block(body)
		4:  # Bounce layer (walls) - fireball destroys on walls
			print("🔥 Fireball hit wall, destroying")
			queue_free()
		8:  # Damage and bounce layer
			hit_block(body)
		_:
			print("🔥 Fireball hit unknown layer: ", body.collision_layer)
			# Destroy on any other collision to be safe
			queue_free()

func hit_player(player):
	"""Handle hitting the player"""
	print("🔥 Fireball hit player!")
	
	# Deal damage to player
	if player.has_method("take_damage"):
		player.take_damage(damage)
		print("🔥 Player took ", damage, " damage from fireball")
	
	# Create explosion effect at impact point
	create_explosion_effect()
	
	# Destroy the fireball
	queue_free()

func hit_block(block):
	"""Handle hitting a block or enemy"""
	print("🔥 Fireball hit block/enemy: ", block.name)
	
	# Deal damage to the block/enemy
	if block.has_method("take_damage"):
		block.take_damage(damage)
		print("🔥 Block/enemy took ", damage, " damage from fireball")
	elif block.has_method("take_laser_damage"):
		# Use laser damage method if regular take_damage doesn't exist
		block.take_laser_damage(damage)
		print("🔥 Block/enemy took ", damage, " laser damage from fireball")
	else:
		print("🔥 Warning: Block/enemy has no damage method!")
	
	# Create explosion effect
	create_explosion_effect()
	
	# Destroy the fireball after hitting block
	queue_free()

func create_explosion_effect():
	"""Create a visual explosion effect when fireball hits"""
	print("🔥 Creating fireball explosion effect")
	
	# Visual explosion effect
	if sprite:
		var original_scale = sprite.scale
		sprite.modulate = Color.ORANGE_RED
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", original_scale * 2.0, 0.1)
		tween.tween_property(sprite, "modulate", Color(1, 0.5, 0, 0), 0.1)  # Orange fade to transparent
