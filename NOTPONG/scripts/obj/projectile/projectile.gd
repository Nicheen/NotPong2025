class_name Projectile extends RigidBody2D

# Core projectile settings
var direction: Vector2
var speed: float = 500.0
var lifetime: float = 8.0
var is_player_projectile: bool = false
var damage_multiplier: float = 1.0

# World boundaries - default to your game area
var world_bounds = Rect2(188, 0, 776, 648)  # Your actual play area bounds

# Components (now as Node references)
@onready var collision_handler: ProjectileCollisionHandler = $Components/CollisionHandler
@onready var boundary_handler: ProjectileBoundaryHandler = $Components/BoundaryHandler
@onready var effect_manager: ProjectileEffectManager = $Components/EffectManager

# Visual effects
@onready var sprite: Sprite2D = $Sprite2D
var original_scale: Vector2

# Debug info (optional) 	
@onready var debug_info: Node2D = $DebugInfo
@onready var velocity_label: Label = $DebugInfo/VelocityLabel
@onready var bounce_label: Label = $DebugInfo/BounceLabel
@onready var distance_label: Label = $DebugInfo/DistanceLabel

# Signals
signal hit_player
signal bounced(position: Vector2)
signal projectile_destroyed_by_collision(was_save: bool)

func _ready():
	setup_physics()
	setup_components()
	setup_auto_destroy()
	
	print("Projectile created - Layer: ", collision_layer, " Mask: ", collision_mask)
	print("World bounds set to: ", world_bounds)

func setup_physics():
	gravity_scale = 0
	linear_damp = 0
	contact_monitor = true
	max_contacts_reported = 10
	
	if sprite:
		original_scale = sprite.scale

func setup_components():
	# Initialize boundary handler with bounds immediately
	if boundary_handler:
		boundary_handler.initialize(world_bounds)
		print("Boundary handler initialized with bounds: ", world_bounds)
	
	# Connect collision signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func setup_auto_destroy():
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_destroy_projectile)
	add_child(timer)
	timer.start()

func initialize(shoot_direction: Vector2, projectile_speed: float, area_center: Vector2 = Vector2.ZERO, area_size: Vector2 = Vector2.ZERO, from_player: bool = true):
	direction = shoot_direction.normalized()
	speed = projectile_speed
	is_player_projectile = from_player
		
	# Update boundary handler with new bounds
	if boundary_handler:
		boundary_handler.update_bounds(world_bounds)
	
	# Set velocity
	linear_velocity = direction * speed
	print("Projectile initialized - From player: ", from_player, " Velocity: ", linear_velocity)

func _physics_process(delta):
	if boundary_handler:
		boundary_handler.check_boundaries()
		boundary_handler.maintain_minimum_velocity()
	update_debug_info()

func update_debug_info():
	# Update debug labels if they exist and debug is enabled
	if debug_info and debug_info.visible:
		if velocity_label:
			velocity_label.text = str(int(linear_velocity.length()))
		if bounce_label:
			bounce_label.text = str(collision_handler.current_bounces)
		if distance_label:
			distance_label.text = str(int(get_distance_to_bounds()))

func set_damage_multiplier(multiplier: float):
	"""Sätt damage multiplier för perfect dodge"""
	damage_multiplier = multiplier
	
	# Visuell feedback om enhanced damage
	if multiplier > 1.0:
		show_enhanced_projectile_effect()

func get_actual_damage() -> int:
	"""Få den faktiska skadan med multiplier - använd befintligt damage system"""
	# FIX 4: Istället för base_damage, returnera multiplier som ska användas
	# i befintliga take_damage calls
	var base_damage = 10
	return int(base_damage * damage_multiplier)  # 10 är standardskadan i ditt system

func show_enhanced_projectile_effect():
	"""Visuell effekt för enhanced projektiler under slow motion"""
	if not has_node("Sprite2D"):
		return
		
	var sprite = get_node("Sprite2D")
	
	# Guldglow för enhanced damage
	var tween = create_tween()
	tween.set_loops()  # Loop tills projektilen förstörs
	tween.tween_property(sprite, "modulate", Color.GOLD, 0.3)
	tween.tween_property(sprite, "modulate", Color.YELLOW, 0.3)

# Uppdatera din damage-funktion:
func deal_damage_to_target(target):
	"""Ge skada till målet med damage multiplier"""
	var actual_damage = get_actual_damage()
	
	if target.has_method("take_damage"):
		target.take_damage(actual_damage)
		
		# Visuell feedback för enhanced damage
		if damage_multiplier > 1.0:
			show_critical_hit_effect(target)
		
		print("Projectile dealt ", actual_damage, " damage (multiplier: ", damage_multiplier, ")")

# Uppdatera din collision handler för att använda damage multiplier:
func _on_body_entered(body):
	"""När projektilen träffar något"""
	# Kolla collision layer för att avgöra vad vi träffade
	var layer = body.collision_layer
	
	if layer & 1:  # Player layer
		if collision_handler:
			collision_handler.handle_player_hit(body)
	elif layer & 2:  # Damage layer  
		if collision_handler:
			collision_handler.handle_damaged_hit(body)
		# Använd vår enhanced damage system
		deal_damage_to_target(body)
	elif layer & 3:  # CollisionBounce layer
		if collision_handler:
			collision_handler.handle_player_hit(body)
	elif layer & 4:  # CollisionBounce + Damage layer
		if collision_handler:
			collision_handler.handle_damaged_bounce_hit(body)
		# Använd vår enhanced damage system
		deal_damage_to_target(body)
		
func handle_enemy_collision(enemy_body):
	"""Hantera kollision med enemy - använd enhanced damage"""
	var actual_damage = get_actual_damage()
	
	if enemy_body.has_method("take_damage"):
		enemy_body.take_damage(actual_damage)
		
		# Visuell feedback för enhanced damage
		if damage_multiplier > 1.0:
			show_critical_hit_effect(enemy_body)
		
		print("Projectile dealt ", actual_damage, " damage (multiplier: ", damage_multiplier, ")")
	
	# Förstör projektilen efter träff
	queue_free()
	
func show_critical_hit_effect(target):
	"""Extra visuell effekt för critical hits"""
	# Skapa floating damage text
	create_floating_damage_text(target.global_position, get_actual_damage())

func create_floating_damage_text(pos: Vector2, damage: int):
	"""Skapa floating damage text"""
	var label = Label.new()
	label.text = str(int(damage)) + "!"
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.GOLD)
	label.global_position = pos
	get_tree().current_scene.add_child(label)
	
	# Skapa tween från scene tree istället för create_tween()
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", pos + Vector2(0, -50), 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	
	# Ta bort efter animation
	tween.finished.connect(func(): 
		if is_instance_valid(label):
			label.queue_free()
	)

func toggle_debug_info():
	if debug_info:
		debug_info.visible = !debug_info.visible

func create_explosion_at(position: Vector2, velocity1: Vector2, velocity2: Vector2):
	if effect_manager:
		effect_manager.create_explosion_effect(position, velocity1, velocity2)

func get_distance_to_bounds() -> float:
	if boundary_handler:
		return boundary_handler.get_distance_to_bounds()
	return 999.0

func handle_bounce(new_velocity: Vector2, new_position: Vector2):
	if collision_handler:
		collision_handler.handle_bounce(new_velocity, new_position)
		GlobalAudioManager.play_sfx(preload("res://audio/noels/thud2.wav"))


func _destroy_projectile():
	print("Destroying projectile at position: ", global_position)
	queue_free()
	

func force_destroy():
	print("Force destroying projectile")
	queue_free()
	
