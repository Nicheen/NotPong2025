class_name ProjectileEffectManager
extends Node

# Visual settings
var warp_intensity: float = 0.3
var warp_duration: float = 0.2

# References
var projectile: RigidBody2D
var sprite: Sprite2D
var original_scale: Vector2
var is_warping: bool = false

# Keep track of created effects for cleanup
var active_effects: Array[Node] = []

func _ready():
	# Get reference to parent projectile when component is ready
	# Components are children of the Components node, so we need get_parent().get_parent()
	projectile = get_parent().get_parent() as RigidBody2D
	sprite = projectile.get_node("Sprite2D")
	if sprite:
		original_scale = sprite.scale

func initialize():
	# No longer needed - _ready() handles the references
	pass

func create_explosion_effect(collision_point: Vector2, vel1: Vector2, vel2: Vector2):
	print("Creating explosion effect at: ", collision_point)
	
	# Get the scene tree to add effects to
	var scene_tree = get_tree()
	if not scene_tree:
		print("No scene tree available for effects")
		return
	
	var main_scene = scene_tree.current_scene
	if not main_scene:
		print("No main scene available for effects")
		return
	
	# Create effects that are completely independent of this projectile
	# We'll create a separate effect manager node that persists
	var effect_container = Node2D.new()
	effect_container.name = "ExplosionEffect_" + str(Time.get_unix_time_from_system())
	effect_container.global_position = collision_point
	main_scene.add_child(effect_container)
	
	# Create multiple effects with longer durations
	var piece_count = randi_range(8, 12)
	var average_velocity = (vel1 + vel2) * 0.5
	
	for i in range(piece_count):
		create_independent_flying_piece(collision_point, average_velocity, i, piece_count, effect_container)
	
	create_independent_flash(collision_point, effect_container)
	create_independent_ring(collision_point, effect_container)
	create_independent_shockwave(collision_point, effect_container)
	
	# Set up auto-cleanup for the container after all effects should be done
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 3.0  # Clean up after 3 seconds
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(effect_container):
			print("Cleaning up explosion effect container")
			effect_container.queue_free()
	)
	effect_container.add_child(cleanup_timer)
	cleanup_timer.start()
	
	print("Independent explosion effects created and will persist for 3 seconds")

func create_independent_flying_piece(start_pos: Vector2, base_velocity: Vector2, piece_index: int, piece_count: int, effect_container: Node2D):
	var piece = Sprite2D.new()
	piece.texture = sprite.texture
	piece.scale = Vector2(0.12, 0.12) * randf_range(0.8, 1.5)
	piece.modulate = Color(
		randf_range(0.8, 1.0),
		randf_range(0.6, 1.0),
		randf_range(0.4, 0.8),
		1.0
	)
	
	# Position with random offset
	piece.global_position = start_pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	
	# Add to effect container (not main scene)
	effect_container.add_child(piece)
	
	# Calculate explosion direction
	var angle = (TAU / piece_count) * piece_index + randf_range(-0.4, 0.4)
	var explosion_direction = Vector2(cos(angle), sin(angle))
	var final_direction = (explosion_direction * 0.8 + base_velocity.normalized() * 0.2).normalized()
	
	# Calculate flight parameters
	var flight_distance = randf_range(80, 150)
	var target_pos = start_pos + final_direction * flight_distance
	var flight_time = randf_range(0.8, 1.5)
	
	# Arc movement
	var mid_point = start_pos + final_direction * flight_distance * 0.5
	var arc_height = randf_range(30, 80)
	mid_point.y -= arc_height
	
	# Create independent tween from scene tree
	var piece_tween = get_tree().create_tween()
	piece_tween.set_parallel(true)
	
	# Curved movement using quadratic bezier
	piece_tween.tween_method(
		func(progress: float):
			if is_instance_valid(piece):
				var t = progress
				var pos = start_pos.lerp(mid_point, t).lerp(mid_point.lerp(target_pos, t), t)
				piece.global_position = pos,
		0.0, 1.0, flight_time
	)
	
	# Spinning and fading
	piece_tween.tween_property(piece, "rotation", randf_range(-PI*4, PI*4), flight_time)
	piece_tween.tween_property(piece, "modulate", Color.TRANSPARENT, flight_time * 0.9)
	piece_tween.tween_property(piece, "scale", Vector2.ZERO, flight_time * 0.8)
	
	# Auto cleanup
	piece_tween.finished.connect(func(): 
		if is_instance_valid(piece):
			piece.queue_free()
	)

func create_independent_flash(position: Vector2, effect_container: Node2D):
	var flash = Sprite2D.new()
	flash.texture = sprite.texture
	flash.scale = Vector2(0.5, 0.5)
	flash.modulate = Color.WHITE
	flash.global_position = position
	
	effect_container.add_child(flash)
	
	# Create independent tween
	var flash_tween = get_tree().create_tween()
	flash_tween.set_parallel(true)
	
	# Bright flash
	flash_tween.tween_property(flash, "modulate", Color.YELLOW * 3.0, 0.15)
	flash_tween.tween_property(flash, "scale", Vector2(1.2, 1.2), 0.15)
	
	# Fade out
	flash_tween.tween_property(flash, "modulate", Color.TRANSPARENT, 0.4)
	flash_tween.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.4)
	
	flash_tween.finished.connect(func(): 
		if is_instance_valid(flash):
			flash.queue_free()
	)

func create_independent_ring(position: Vector2, effect_container: Node2D):
	var ring = Node2D.new()
	ring.global_position = position
	effect_container.add_child(ring)
	
	# Create multiple lines to form a circle
	var line_count = 20
	var lines = []
	
	for i in range(line_count):
		var line = Line2D.new()
		line.width = 4.0
		line.default_color = Color.CYAN
		ring.add_child(line)
		lines.append(line)
		
		# Set up initial line points
		var angle = (TAU / line_count) * i
		var start_radius = 3.0
		var end_radius = 6.0
		line.points = PackedVector2Array([
			Vector2(cos(angle) * start_radius, sin(angle) * start_radius),
			Vector2(cos(angle) * end_radius, sin(angle) * end_radius)
		])
	
	# Create independent tween
	var ring_tween = get_tree().create_tween()
	ring_tween.set_parallel(true)
	
	# Expand the ring
	ring_tween.tween_method(
		func(radius: float):
			if is_instance_valid(ring):
				for i in range(lines.size()):
					if is_instance_valid(lines[i]):
						var angle = (TAU / line_count) * i
						var start_radius = radius * 0.8
						var end_radius = radius
						lines[i].points = PackedVector2Array([
							Vector2(cos(angle) * start_radius, sin(angle) * start_radius),
							Vector2(cos(angle) * end_radius, sin(angle) * end_radius)
						]),
		8.0, 80.0, 0.8
	)
	
	# Fade out the ring
	ring_tween.tween_method(
		func(alpha: float):
			if is_instance_valid(ring):
				for line in lines:
					if is_instance_valid(line):
						line.default_color = Color.CYAN * Color(1, 1, 1, alpha),
		1.0, 0.0, 0.6
	)
	
	ring_tween.finished.connect(func():
		if is_instance_valid(ring):
			ring.queue_free()
	)

func create_independent_shockwave(position: Vector2, effect_container: Node2D):
	var shockwave = ColorRect.new()
	shockwave.color = Color(1, 1, 0, 0.8)
	shockwave.size = Vector2(20, 20)
	shockwave.position = position - shockwave.size * 0.5
	
	effect_container.add_child(shockwave)
	
	# Create independent tween
	var shock_tween = get_tree().create_tween()
	shock_tween.set_parallel(true)
	
	# Expand rapidly
	shock_tween.tween_method(
		func(scale_factor: float):
			if is_instance_valid(shockwave):
				var new_size = Vector2(20, 20) * scale_factor
				shockwave.size = new_size
				shockwave.position = position - new_size * 0.5,
		1.0, 8.0, 0.3
	)
	
	# Fade out
	shock_tween.tween_property(shockwave, "color", Color(1, 1, 0, 0), 0.5)
	
	shock_tween.finished.connect(func():
		if is_instance_valid(shockwave):
			shockwave.queue_free()
	)

func cleanup_effect(effect: Node):
	if is_instance_valid(effect):
		# Remove from tracking array
		var index = active_effects.find(effect)
		if index >= 0:
			active_effects.remove_at(index)
		
		# Remove from scene
		if effect.get_parent():
			effect.get_parent().remove_child(effect)
		effect.queue_free()
		print("Cleaned up effect: ", effect.get_class())
	else:
		print("Effect already destroyed or invalid")

func start_warp_effect():
	if not sprite or is_warping:
		return
	
	is_warping = true
	
	var start_scale = sprite.scale
	var start_color = sprite.modulate
	var start_rotation = sprite.rotation
	
	# Create tween from scene tree
	var tween = projectile.get_tree().create_tween()
	tween.set_parallel(true)
	
	# Phase 1: Compress and flash
	tween.tween_property(sprite, "scale", original_scale * Vector2(1.5, 0.5), warp_duration * 0.2)
	tween.tween_property(sprite, "modulate", Color.CYAN, warp_duration * 0.2)
	tween.tween_property(sprite, "rotation", start_rotation + PI * 0.25, warp_duration * 0.2)
	
	# Phase 2: Expand and spin
	tween.tween_property(sprite, "scale", original_scale * Vector2(0.7, 1.3), warp_duration * 0.3)
	tween.tween_property(sprite, "modulate", Color.YELLOW, warp_duration * 0.3)
	tween.tween_property(sprite, "rotation", start_rotation + PI * 0.5, warp_duration * 0.3)
	
	# Phase 3: Return to normal
	tween.tween_property(sprite, "scale", original_scale, warp_duration * 0.5)
	tween.tween_property(sprite, "modulate", Color.WHITE, warp_duration * 0.5)
	tween.tween_property(sprite, "rotation", start_rotation, warp_duration * 0.5)
	
	await tween.finished
	
	# Force reset values
	if sprite and is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
		sprite.scale = original_scale
		sprite.modulate = Color.WHITE
		sprite.rotation = start_rotation
	
	is_warping = false

# Clean up any remaining effects when this component is destroyed
func _exit_tree():
	for effect in active_effects:
		if is_instance_valid(effect):
			if effect.get_parent():
				effect.get_parent().remove_child(effect)
			effect.queue_free()
	active_effects.clear()
	print("Effect manager cleaned up all effects")
