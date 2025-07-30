extends Node2D

@onready var lightning: Line2D = $Lightning
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var damage_area: Area2D = $DamageArea
@onready var damage_collision: CollisionShape2D = $DamageArea/CollisionShape2D
@onready var sparks: GPUParticles2D = $Sparks
@onready var flare: GPUParticles2D = $Flare
@onready var point_light: PointLight2D = $PointLight2D

# Thunder settings
@export var damage_amount: int = 20
@export var damage_interval: float = 0.5
@export var thunder_width: float = 150.0
@export var lightning_active_duration: float = 2.0  # How long lightning stays active
@export var lightning_inactive_duration_min: float = 2.0  # Min time between lightning cycles
@export var lightning_inactive_duration_max: float = 5.0  # Max time between lightning cycles

# Game boundaries (adjust these to match your game)
const TOP_BOUNDARY = 0
const BOTTOM_BOUNDARY = 648
const LEFT_BOUNDARY = 200
const RIGHT_BOUNDARY = 952

# Internal variables
var is_active: bool = false
var damage_timer: float = 0.0
var cycle_timer: float = 0.0
var players_in_area: Array[Node] = []
var should_cycle: bool = false
var is_lightning_active: bool = false
var current_inactive_duration: float = 0.0

func _ready():
	# Connect animation signals
	if animation_player.has_animation("start_animation"):
		animation_player.animation_finished.connect(_on_animation_finished)
	
	# Connect area signals for damage
	if damage_area:
		damage_area.body_entered.connect(_on_body_entered)
		damage_area.body_exited.connect(_on_body_exited)
	
	# Set collision layers - area detects players (layer 1)
	damage_area.collision_layer = 0
	damage_area.collision_mask = 1

func _process(delta):
	if is_active and players_in_area.size() > 0 and is_lightning_active:
		damage_timer += delta
		if damage_timer >= damage_interval:
			damage_players_in_area()
			damage_timer = 0.0
	
	# Handle lightning cycling
	if should_cycle:
		cycle_timer += delta
		
		if is_lightning_active:
			# Lightning is active - check if it should turn off
			if cycle_timer >= lightning_active_duration:
				end_lightning_cycle()
		else:
			# Lightning is inactive - check if it should turn on again
			if cycle_timer >= current_inactive_duration:
				start_lightning_cycle()

func setup_vertical_thunder():
	"""Set up a vertical thunder bolt from top to bottom of screen"""
	# Clear any existing positioning from the scene file
	position = Vector2.ZERO
	
	# Calculate positions in world coordinates
	var thunder_world_pos = global_position
	var start_world = Vector2(thunder_world_pos.x + 5, global_position.y + 15)
	var end_world = Vector2(thunder_world_pos.x + 5, BOTTOM_BOUNDARY - 9)
	
	# Convert to local coordinates relative to this thunder effect
	var start_local = to_local(start_world)
	var end_local = to_local(end_world)
	
	# Set the lightning line
	lightning.points = PackedVector2Array([start_local, end_local])
	lightning.width = thunder_width
	
	# Update damage area
	var rect_shape = damage_collision.shape as RectangleShape2D
	if rect_shape:
		var length = end_local.y - start_local.y
		rect_shape.size = Vector2(thunder_width * 0.5, length)
		damage_collision.position = Vector2(0, (start_local.y + end_local.y) * 0.5)
	
	# Position effects at the bottom impact point
	if sparks:
		sparks.position = end_local
	if flare:
		flare.position = end_local
	if point_light:
		point_light.position = end_local
	
	print("Thunder world pos: ", thunder_world_pos)
	print("Start world: ", start_world, " -> local: ", start_local)
	print("End world: ", end_world, " -> local: ", end_local)

func setup_horizontal_thunder():
	"""Set up a horizontal thunder bolt from left to right wall"""
	# Clear any existing positioning
	position = Vector2.ZERO
	
	# Calculate positions in world coordinates
	var thunder_world_pos = global_position
	var start_world = Vector2(LEFT_BOUNDARY, thunder_world_pos.y)
	var end_world = Vector2(RIGHT_BOUNDARY, thunder_world_pos.y)
	
	# Convert to local coordinates
	var start_local = to_local(start_world)
	var end_local = to_local(end_world)
	
	# Set the lightning line
	lightning.points = PackedVector2Array([start_local, end_local])
	lightning.width = thunder_width
	
	# Update damage area
	var rect_shape = damage_collision.shape as RectangleShape2D
	if rect_shape:
		var length = end_local.x - start_local.x
		rect_shape.size = Vector2(length, thunder_width * 0.5)
		damage_collision.position = Vector2((start_local.x + end_local.x) * 0.5, 0)
	
	# Position effects at the right impact point
	if sparks:
		sparks.position = end_local
	if flare:
		flare.position = end_local
	if point_light:
		point_light.position = end_local
	
	print("Horizontal thunder - Start: ", start_local, " End: ", end_local)

func start_thunder():
	"""Start the thunder cycling system"""
	is_active = true
	should_cycle = true
	visible = true
	
	# Start with the first lightning cycle
	start_lightning_cycle()
	print("Thunder cycling started")

func start_lightning_cycle():
	"""Start a new lightning active period"""
	is_lightning_active = true
	cycle_timer = 0.0
	
	# Show the lightning visually
	lightning.visible = true
	if sparks:
		sparks.emitting = true
	if flare:
		flare.emitting = true
	if point_light:
		point_light.energy = 2.0
	
	print("Lightning cycle started - will be active for ", lightning_active_duration, " seconds")

func end_lightning_cycle():
	"""End the current lightning cycle and start inactive period"""
	is_lightning_active = false
	cycle_timer = 0.0
	
	# Set random inactive duration between min and max
	current_inactive_duration = randf_range(lightning_inactive_duration_min, lightning_inactive_duration_max)
	
	# Just hide the lightning visually - DON'T play end animation during cycling
	lightning.visible = false
	if sparks:
		sparks.emitting = false
	if flare:
		flare.emitting = false
	if point_light:
		point_light.energy = 0.0
	
	print("Lightning cycle ended - will be inactive for ", current_inactive_duration, " seconds")

func end_thunder():
	"""Completely stop the thunder system"""
	should_cycle = false
	is_lightning_active = false
	
	if animation_player and animation_player.has_animation("end_animation"):
		animation_player.play("end_animation")
		print("Thunder system ending with animation")
	else:
		stop_thunder()

func stop_thunder():
	"""Immediately stop the thunder effect"""
	is_active = false
	should_cycle = false
	is_lightning_active = false
	players_in_area.clear()
	damage_timer = 0.0
	cycle_timer = 0.0
	visible = false
	print("Thunder system stopped")

func _on_animation_finished(animation_name: String):
	if animation_name == "start_animation":
		if should_cycle and not is_lightning_active:
			# This was the initial start animation - now begin cycling
			start_lightning_cycle()
			print("Initial animation completed - starting first lightning cycle")
		else:
			print("Lightning animation completed")
	

func _on_body_entered(body):
	if body.has_method("take_damage") and "player" in body.name.to_lower():
		if not body in players_in_area:
			players_in_area.append(body)
			print("Player entered thunder area")

func _on_body_exited(body):
	if body in players_in_area:
		players_in_area.erase(body)
		print("Player exited thunder area")

func damage_players_in_area():
	for player in players_in_area:
		if is_instance_valid(player) and player.has_method("take_damage"):
			player.take_damage(damage_amount)
			print("Thunder dealt ", damage_amount, " damage to player")

# Public methods for the laser block to use
func activate_vertical_thunder():
	"""Activate thunder as a vertical bolt"""
	setup_vertical_thunder()
	start_thunder()

func activate_horizontal_thunder():
	"""Activate thunder as a horizontal bolt"""
	setup_horizontal_thunder()
	start_thunder()

func deactivate_thunder():
	"""Deactivate the thunder effect"""
	end_thunder()
