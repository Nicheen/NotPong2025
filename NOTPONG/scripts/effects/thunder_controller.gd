extends Node2D

@onready var lightning: Line2D = $Lightning
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var damage_area: Area2D = $DamageArea
@onready var damage_collision: CollisionShape2D = $DamageArea/CollisionShape2D
@onready var sparks: GPUParticles2D = $Sparks
@onready var flare: GPUParticles2D = $Flare
@onready var point_light: PointLight2D = $PointLight2D

@onready var block_raycast: RayCast2D = %RayCast2D

# Thunder settings
@export var damage_amount: int = 20
@export var damage_interval: float = 0.5
@export var thunder_width: float = 150.0
@export var lightning_active_duration: float = 1.0  # How long lightning stays active
@export var lightning_inactive_duration_min: float = 2.0  # Min time between lightning cycles
@export var lightning_inactive_duration_max: float = 5.0  # Max time between lightning cycles

# Game boundaries (adjust these to match your game)
const TOP_BOUNDARY = 0
const BOTTOM_BOUNDARY = 648
const LEFT_BOUNDARY = 200
const RIGHT_BOUNDARY = 952

# Internal variables
var is_active: bool = false
var previous_thunder_end_position_y: float = 0.0
var damage_timer: float = 0.0
var cycle_timer: float = 0.0
var players_in_area: Array[Node] = []
var should_cycle: bool = false
var is_lightning_active: bool = false
var current_inactive_duration: float = 0.0

var destroyed_blocks: Array[Node] = []

# NEW: Signals to communicate with the thunder block
signal thunder_activated  # When lightning becomes active
signal thunder_deactivated  # When lightning becomes inactive

func _ready():
	# Connect animation signals
	if animation_player.has_animation("start_animation"):
		animation_player.animation_finished.connect(_on_animation_finished)
	
	# Connect area signals for damage
	if damage_area:
		damage_area.body_entered.connect(_on_body_entered)
		damage_area.body_exited.connect(_on_body_exited)
	
	if not block_raycast:
		block_raycast = RayCast2D.new()
		add_child(block_raycast)
	
	# Set collision layers - area detects players (layer 1)
	damage_area.collision_layer = 0
	damage_area.collision_mask = 1

func update_thunder_end_position(end_pos_y: float):
	var start_world = Vector2(global_position.x + 5, global_position.y + 25)
	var end_world = Vector2(global_position.x + 5, end_pos_y - 25)
	
	var start_local = to_local(start_world)
	var end_local = to_local(end_world)
	
	lightning.points = PackedVector2Array([start_local, end_local])
	# Position effects at the bottom impact point
	if sparks:
		sparks.position = end_local
	if flare:
		flare.position = end_local
	if point_light:
		point_light.position = end_local

# NEW: Check for blocks to destroy when thunder activates
func check_and_destroy_blocks():
	"""Check along the thunder path and destroy the first block hit"""
	if not block_raycast:
		print("[THUNDER] No block_raycast found, returning")
		return
	
	# Vertical thunder - cast downward
	print("[THUNDER] Set vertical raycast direction: ", block_raycast.target_position)
	
	print("[THUNDER] Thunder position: ", global_position)
	
	# Force raycast update
	block_raycast.force_raycast_update()
	print("[THUNDER] Raycast updated, checking collision...")
	
	# Check if we hit a block
	if block_raycast.is_colliding():
		print("[THUNDER] Raycast hit something!")
		var hit_body = block_raycast.get_collider()
		print("[THUNDER] Hit body: ", hit_body.name if hit_body else "null")
		
		# Make sure we haven't already destroyed this block
		if hit_body:
			print("[THUNDER] Destroying block: ", hit_body.name)
			
			# Destroy the block immediately
			if hit_body.has_method("take_laser_damage"):
				print("[THUNDER] Using take_laser_damage method")
				hit_body.take_laser_damage(20)  # High damage = instant kill
			elif hit_body.has_method("die_silently"):
				print("[THUNDER] Using die_silently method")
				hit_body.die_silently()
			elif hit_body.has_method("destroy_block"):
				print("[THUNDER] Using destroy_block method")
				hit_body.destroy_block()
			else:
				print("[THUNDER] No destruction method found on hit body")
				
			update_thunder_end_position(hit_body.global_position.y)
		else:
			if not hit_body:
				print("[THUNDER] Hit body is null")
			else:
				print("[THUNDER] Block already destroyed: ", hit_body.name)
	else:
		update_thunder_end_position(previous_thunder_end_position_y)
		print("[THUNDER] Raycast did not hit anything")
			
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
			check_and_destroy_blocks()
			# Lightning is active - check if it should turn off
			if cycle_timer >= lightning_active_duration:
				end_lightning_cycle()
		else:
			# Lightning is inactive - check if it should turn on again
			if cycle_timer >= current_inactive_duration:
				start_lightning_cycle()

func setup_vertical_thunder(pos: Vector2 = Vector2.ZERO):
	"""Set up a vertical thunder bolt from top to bottom of screen"""
	# Clear any existing positioning from the scene file
	position = Vector2.ZERO
	
	# Calculate positions in world coordinates
	var thunder_world_pos = pos
	var start_world = Vector2(thunder_world_pos.x + 5, global_position.y + 25)
	var end_world = Vector2(thunder_world_pos.x + 5, BOTTOM_BOUNDARY - 9)
	previous_thunder_end_position_y = BOTTOM_BOUNDARY + 25
	
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
	
	# NEW: Emit signal to tell the thunder block that lightning is active
	thunder_activated.emit()
	create_screen_shake()
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
	
	# NEW: Emit signal to tell the thunder block that lightning is inactive
	thunder_deactivated.emit()
	
	print("Lightning cycle ended - will be inactive for ", current_inactive_duration, " seconds")

func end_thunder():
	"""Completely stop the thunder system"""
	should_cycle = false
	is_lightning_active = false
	
	# NEW: Make sure we emit deactivated signal when stopping
	if is_lightning_active:
		thunder_deactivated.emit()
	
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
func activate_vertical_thunder(pos: Vector2 = global_position):
	"""Activate thunder as a vertical bolt"""
	setup_vertical_thunder(pos)
	start_thunder()

func activate_horizontal_thunder():
	"""Activate thunder as a horizontal bolt"""
	setup_horizontal_thunder()
	start_thunder()

func deactivate_thunder():
	"""Deactivate the thunder effect"""
	end_thunder()
	
func create_screen_shake():
	"""Enhanced screen shake"""
	var camera = find_camera_in_scene()
	if not camera:
		print("camera was not found, no camera shake applied!")
		return
	
	if camera.has_method("add_trauma"):
		camera.add_trauma(0.8)
	else:
		# Manual screen shake - create independent tween
		var original_pos = camera.global_position
		var shake_tween = get_tree().create_tween()
		
		# More intense shake with decay
		for i in range(12):
			var intensity = 8.0 * (1.0 - float(i) / 12.0)  # Decay over time
			var shake_offset = Vector2(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity)
			)
			shake_tween.tween_property(camera, "global_position", 
				original_pos + shake_offset, 0.04)
		
		shake_tween.tween_property(camera, "global_position", original_pos, 0.1)

func find_camera_in_scene():
	var scene_root = get_tree().current_scene
	return scene_root.find_child("Camera2D", true, false)
	
func get_thunder_targets() -> Array[Node]:
	"""Return list of targets currently being hit by thunder"""
	var targets: Array[Node] = []
	
	if is_lightning_active and block_raycast and block_raycast.is_colliding():
		var hit_body = block_raycast.get_collider()
		if hit_body and not hit_body in destroyed_blocks:
			targets.append(hit_body)
	
	# Also add any players in the damage area
	for player in players_in_area:
		if is_instance_valid(player):
			targets.append(player)
	
	return targets
