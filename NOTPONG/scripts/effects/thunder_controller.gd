extends Node2D

@onready var lightning: Line2D = $Lightning
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var damage_area: Area2D = $DamageArea
@onready var damage_collision: CollisionShape2D = $DamageArea/CollisionShape2D

# Thunder settings
@export var damage_amount: int = 20
@export var damage_interval: float = 0.5  # Time between damage ticks
@export var thunder_width: float = 150.0   # Width of the lightning

# Internal variables
var is_active: bool = false
var damage_timer: float = 0.0
var players_in_area: Array[Node] = []

func _ready():
	# Set up damage area
	setup_damage_area()
	
	# Connect animation signals
	if animation_player.has_animation("start_animation"):
		animation_player.animation_finished.connect(_on_animation_finished)
	
	# Connect area signals for damage
	if damage_area:
		damage_area.body_entered.connect(_on_body_entered)
		damage_area.body_exited.connect(_on_body_exited)

func _process(delta):
	if is_active and players_in_area.size() > 0:
		damage_timer += delta
		if damage_timer >= damage_interval:
			damage_players_in_area()
			damage_timer = 0.0

func setup_damage_area():
	# Create damage area if it doesn't exist
	if not damage_area:
		damage_area = Area2D.new()
		damage_area.name = "DamageArea"
		add_child(damage_area)
		
		# Create collision shape
		damage_collision = CollisionShape2D.new()
		damage_area.add_child(damage_collision)
		
		var rect_shape = RectangleShape2D.new()
		damage_collision.shape = rect_shape
	
	# Set collision layers - area detects players (layer 1)
	damage_area.collision_layer = 0  # Area doesn't exist on any layer
	damage_area.collision_mask = 1   # Detects player (layer 1)

func setup_thunder_line(start_pos: Vector2, end_pos: Vector2):
	"""Configure the thunder line between two points"""
	if not lightning:
		print("ERROR: Lightning Line2D not found!")
		return
	
	# Set the line points
	lightning.points = PackedVector2Array([start_pos, end_pos])
	lightning.width = thunder_width
	
	# Update damage area to match the lightning
	update_damage_area_shape(start_pos, end_pos)
	
	print("Thunder line configured from ", start_pos, " to ", end_pos)

func setup_vertical_thunder(spawn_position: Vector2, play_area_height: float = 648.0):
	"""Set up a vertical thunder bolt from top to bottom"""
	var start_pos = Vector2(0, -spawn_position.y)      # Top of screen (relative to thunder)
	var end_pos = Vector2(0, play_area_height - spawn_position.y)  # Bottom of screen
	
	setup_thunder_line(start_pos, end_pos)

func setup_horizontal_thunder(spawn_position: Vector2, play_area_width: float = 752.0):
	"""Set up a horizontal thunder bolt from left to right"""
	var start_pos = Vector2(-spawn_position.x + 200, 0)  # Left wall (relative to thunder)
	var end_pos = Vector2(play_area_width - spawn_position.x + 200, 0)  # Right wall
	
	setup_thunder_line(start_pos, end_pos)

func update_damage_area_shape(start_pos: Vector2, end_pos: Vector2):
	"""Update the damage area to match the lightning bolt"""
	if not damage_collision or not damage_collision.shape:
		return
	
	var rect_shape = damage_collision.shape as RectangleShape2D
	if not rect_shape:
		rect_shape = RectangleShape2D.new()
		damage_collision.shape = rect_shape
	
	# Calculate the center point and size of the rectangle
	var center = (start_pos + end_pos) * 0.5
	var line_vector = end_pos - start_pos
	var length = line_vector.length()
	
	# Set damage area size and position
	if abs(line_vector.x) > abs(line_vector.y):
		# Horizontal line
		rect_shape.size = Vector2(length, thunder_width * 0.5)
	else:
		# Vertical line
		rect_shape.size = Vector2(thunder_width * 0.5, length)
	
	# Position the collision shape
	damage_collision.position = center

func start_thunder():
	"""Start the thunder effect with animation"""
	is_active = true
	
	if animation_player and animation_player.has_animation("start_animation"):
		animation_player.play("start_animation")
		print("Thunder started with animation")
	else:
		print("Thunder started without animation")

func end_thunder():
	"""End the thunder effect with animation"""
	if animation_player and animation_player.has_animation("end_animation"):
		animation_player.play("end_animation")
		print("Thunder ending with animation")
	else:
		stop_thunder()

func stop_thunder():
	"""Immediately stop the thunder effect"""
	is_active = false
	players_in_area.clear()
	damage_timer = 0.0
	
	# Hide the thunder effect
	visible = false
	print("Thunder stopped")

func _on_animation_finished(animation_name: String):
	"""Handle animation completion"""
	if animation_name == "start_animation":
		print("Thunder start animation completed")
		# Thunder is now fully active
	elif animation_name == "end_animation":
		print("Thunder end animation completed")
		stop_thunder()

func _on_body_entered(body):
	"""Handle when a body enters the damage area"""
	if body.has_method("take_damage") and "player" in body.name.to_lower():
		if not body in players_in_area:
			players_in_area.append(body)
			print("Player entered thunder area")

func _on_body_exited(body):
	"""Handle when a body exits the damage area"""
	if body in players_in_area:
		players_in_area.erase(body)
		print("Player exited thunder area")

func damage_players_in_area():
	"""Deal damage to all players in the thunder area"""
	for player in players_in_area:
		if is_instance_valid(player) and player.has_method("take_damage"):
			player.take_damage(damage_amount)
			print("Thunder dealt ", damage_amount, " damage to player")

# Public methods for the laser block to use
func activate_vertical_thunder():
	"""Activate thunder as a vertical bolt"""
	setup_vertical_thunder(global_position)
	start_thunder()

func activate_horizontal_thunder():
	"""Activate thunder as a horizontal bolt"""
	setup_horizontal_thunder(global_position)
	start_thunder()

func deactivate_thunder():
	"""Deactivate the thunder effect"""
	end_thunder()
