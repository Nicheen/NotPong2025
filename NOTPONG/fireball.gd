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
	
	print("Fireball created")

func initialize(drop_direction: Vector2, speed: float):  # <- FIXAT STAVFEL
	"""Initialize the fireball with direction and speed"""
	direction = drop_direction.normalized()
	fireball_speed = speed
	
	# Set the velocity
	linear_velocity = direction * fireball_speed
	
	print("Fireball initialized - Direction: ", direction, " Speed: ", speed)

func _physics_process(delta):  # <- FIXAT STAVFEL
	# Check if fireball is out of bounds
	check_boundaries()

func check_boundaries():
	"""Check if fireball is outside world bounds and destroy it"""
	if not world_bounds.has_point(global_position):
		print("Fireball out of bounds, destroying")
		queue_free()

func _on_body_entered(body):  # <- FIXAT STAVFEL
	"""Handle collision with other bodies"""
	print("Fireball collided with: ", body.name)
	
	# Check if it hit the player
	if body.collision_layer == 1:  # Player layer
		hit_player(body)
	
	# Check if it hit a block (but don't bounce like projectiles do)
	elif body.collision_layer == 2:  # Block/enemy layer
		# Fireball is destroyed when hitting blocks (no bouncing)
		print("Fireball hit block, destroying")
		queue_free()

func hit_player(player):
	"""Handle hitting the player"""
	print("Fireball hit player!")
	
	# Deal damage to player
	if player.has_method("take_damage"):
		player.take_damage(damage)
		print("Player took ", damage, " damage from fireball")
	
	# Create explosion effect at impact point
	create_explosion_effect()
	
	# Destroy the fireball
	queue_free()

func create_explosion_effect():
	"""Create a visual explosion effect when fireball hits"""
	print("Creating fireball explosion effect")
	
	# You can add particle effects or visual effects here
	# For now, just a simple effect
	if sprite:
		sprite.modulate = Color.ORANGE_RED
		
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.1)
		tween.parallel().tween_property(sprite, "modulate", Color.TRANSPARENT, 0.1)
