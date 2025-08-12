class_name Player extends CharacterBody2D

# Movement settings
@export var speed: float = 600.0
@export var acceleration: float = 2000.0
@export var friction: float = 4000.0
@onready var health_bar: ProgressBar = %HealthBar


@onready var projectile_preview_main: Sprite2D
@onready var projectile_preview_mid: Sprite2D
@onready var projectile_preview_close: Sprite2D
# Teleport settings
@export var teleport_cooldown: float = 0.2
@export var play_area_size: Vector2 = Vector2(752, 648)  # Lägg till denna
@export var play_area_center: Vector2 = Vector2(576, 324)  # Lägg till denna
var top_wall_timer: float = 0.0
var top_wall_time_limit: float = 2.0  # 2 sekunder
var teleport_up_cooldown_timer: float = 0.0
var teleport_up_cooldown_duration: float = 4.0  # 4 sekunder cooldown
var can_teleport_up: bool = true

@onready var player_texture = preload("res://images/NewPlayer.png")
@onready var player_damaged_texture_1 = preload("res://images/NewPlayerDamaged1.png")
@onready var player_damaged_texture_2 = preload("res://images/NewPlayerDamaged2.png")
# Dash settings
@export var dash_distance: float = 75.0
@export var dash_cooldown: float = 1.5

# Shooting settings
@export var projectile_scene: PackedScene = load("res://scenes/obj/Projectile.tscn")
@export var projectile_speed: float = 500.0
@export var shoot_cooldown: float = 0.1

# Health settings
@export var max_health: int = 100
@export var damage_per_hit: int = 10

# Wall state tracking
enum WallSide { BOTTOM, TOP }
var current_wall: WallSide = WallSide.BOTTOM

# Internal variables
var teleport_timer: float = 0.0
var can_teleport: bool = true
var shoot_timer: float = 0.0
var can_shoot: bool = true
var current_health: int

# Dash variables
var dash_timer: float = 0.0
var can_dash: bool = true
var shift_released: bool = true

# Optional: Visual feedback
@onready var sprite: Sprite2D = $Sprite2D
var teleport_effect_duration: float = 0.1
var is_teleporting: bool = false

#DodgeDetector
@onready var dodge_detector: Area2D = $DodgeDetector
var perfect_dodge_active: bool = false
var perfect_dodge_timer: float = 0.0

# Signals
signal player_died

func _ready():
	# Set initial position and health
	global_position = Vector2(500, 200)
	current_health = max_health
	setup_projectile_preview()

func _physics_process(delta):
	handle_teleport_cooldown(delta)
	handle_shoot_cooldown(delta)
	handle_dash_cooldown(delta)  # Lägg till dash cooldown
	handle_movement(delta)
	handle_teleport_input()
	handle_top_wall_timer(delta)
	handle_teleport_up_cooldown(delta)
	handle_shoot_input()
	handle_dash_input()  # Lägg till dash input
	handle_teleport_effect(delta)
	handle_perfect_dodge_system(delta)
	update_projectile_preview()
	
	# Apply movement
	move_and_slide()

func handle_movement(delta):
	# Get input direction using the Input Map actions
	var input_dir = Input.get_axis("move_left", "move_right")
	
	# Apply movement based on current wall (only top and bottom)
	match current_wall:
		WallSide.BOTTOM:
			# Normal horizontal movement on bottom
			if input_dir != 0:
				# Kolla om vi byter riktning
				var changing_direction = (velocity.x > 0 and input_dir < 0) or (velocity.x < 0 and input_dir > 0)
				
				if changing_direction:
					# Mycket högre acceleration när vi byter riktning
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * 3 * delta)
				else:
					# Normal acceleration
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, friction * delta)
				
		WallSide.TOP:
			# Horizontal movement on top (samma logik)
			if input_dir != 0:
				# Kolla om vi byter riktning
				var changing_direction = (velocity.x > 0 and input_dir < 0) or (velocity.x < 0 and input_dir > 0)
				
				if changing_direction:
					# Mycket högre acceleration när vi byter riktning
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * 3 * delta)
				else:
					# Normal acceleration
					velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_teleport_input():
	if not can_teleport:
		return
	
	var teleport_direction = Vector2.ZERO
	
	# Use Input Map actions for teleporting
	if Input.is_action_just_pressed("teleport_up"):
		# Kolla om vi kan teleportera upp
		if current_wall == WallSide.TOP:
			print("Already on top wall - cannot teleport up again!")
			return
		
		if can_teleport_up:
			teleport_direction = Vector2(0, -1)
		else:
			print("Cannot teleport up - cooldown remaining: ", "%.1f" % teleport_up_cooldown_timer, " seconds")
			
	elif Input.is_action_just_pressed("teleport_down"):
		# Kan alltid teleportera ner
		teleport_direction = Vector2(0, 1)
	
	if teleport_direction != Vector2.ZERO:
		teleport_to_edge(teleport_direction)

func handle_shoot_input():
	if not can_shoot:
		return
	
	# Check for mouse click or shoot action
	if Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("ui_accept"):
		shoot_projectile()

# FIXED: Använd lokala variabler istället för Global
func teleport_to_edge(direction: Vector2):
	var new_position = global_position
	var half_size = play_area_size * 0.5
	var bounds = {
		"top": play_area_center.y - half_size.y,
		"bottom": play_area_center.y + half_size.y
	}
   
   # Spara nuvarande x-hastighet innan teleportering
	var current_x_velocity = velocity.x
   
   # Teleport to edge and update current wall (only up/down)
	if direction.y > 0:  # Teleport down
		new_position.y = bounds.bottom - 50
		current_wall = WallSide.BOTTOM
		top_wall_timer = 0.0  # Reset timer när vi går ner
   	
   	# STARTA COOLDOWN NÄR VI GÅR NER!
		start_teleport_up_cooldown()
		print("Teleported DOWN to bottom wall - UP cooldown started")
   	
	elif direction.y < 0:  # Teleport up
		new_position.y = bounds.top + 50
		current_wall = WallSide.TOP
		top_wall_timer = top_wall_time_limit  # Starta 2-sekunder timer
		print("Teleported UP to top wall - timer started (", top_wall_time_limit, " seconds)")
   
   # Apply teleportation
	global_position = new_position
   
   # Behåll x-hastigheten, nollställ bara y-hastigheten
	velocity = Vector2(current_x_velocity, 0)
   
	start_teleport_cooldown()
	start_teleport_effect()
   
   # Update sprite rotation based on wall
	update_sprite_rotation()
	
func start_teleport_up_cooldown():
	"""Start 4-second cooldown for teleporting up again"""
	can_teleport_up = false
	teleport_up_cooldown_timer = teleport_up_cooldown_duration
	print("Teleport UP cooldown started - ", teleport_up_cooldown_duration, " seconds")

func update_sprite():
	if sprite == null:
		print("ERROR: Sprite2D not found!")
		return
		
	if current_health > 60:
		sprite.texture = player_texture
	elif current_health <= 60 and current_health > 20:
		sprite.texture = player_damaged_texture_1
	elif current_health <= 20:
		sprite.texture = player_damaged_texture_2
		
func handle_teleport_up_cooldown(delta):
	"""Handle cooldown timer for teleporting up"""
	if can_teleport_up:
		return
		
	teleport_up_cooldown_timer -= delta
	
	if teleport_up_cooldown_timer <= 0.0:
		can_teleport_up = true
		teleport_up_cooldown_timer = 0.0
		print("✨ Teleport UP ready again!")

# Utility-funktioner för debugging:
func get_teleport_up_cooldown_remaining() -> float:
	"""Get remaining teleport up cooldown time"""
	if can_teleport_up:
		return 0.0
	return teleport_up_cooldown_timer

func can_go_up() -> bool:
	"""Check if player can teleport up"""
	return can_teleport_up and can_teleport

func handle_top_wall_timer(delta):
	"""Handle 2-second timer on top wall"""
	if current_wall != WallSide.TOP:
		return
		
	top_wall_timer -= delta
	
	# Om tiden är ute, teleportera automatiskt tillbaka
	if top_wall_timer <= 0.0 and can_teleport:
		print("Top wall time expired - auto teleporting to bottom!")
		
		# Teleportera direkt till botten
		var half_size = play_area_size * 0.5
		var bottom_y = play_area_center.y + half_size.y - 50
		
		var current_x_velocity = velocity.x
		global_position.y = bottom_y
		current_wall = WallSide.BOTTOM
		top_wall_timer = 0.0
		velocity = Vector2(current_x_velocity, 0)
		start_teleport_up_cooldown()
		start_teleport_cooldown()
		start_teleport_effect()
		update_sprite_rotation()
		
func start_teleport_cooldown():
	can_teleport = false
	teleport_timer = teleport_cooldown

func handle_teleport_cooldown(delta):
	if not can_teleport:
		teleport_timer -= delta
		if teleport_timer <= 0:
			can_teleport = true

func setup_perfect_dodge():
	# Anslut dodge detector signals
	if dodge_detector:
		dodge_detector.perfect_dodge_detected.connect(_on_perfect_dodge_detected)
	
	# Anslut perfect dodge system signals
	if PerfectDodgeSystem:
		PerfectDodgeSystem.time_slow_started.connect(_on_time_slow_started)
		PerfectDodgeSystem.time_slow_ended.connect(_on_time_slow_ended)

# Lägg till dessa funktioner i din Player.gd:

func _on_perfect_dodge_detected(enemy_attack):
	"""Kallas när en perfect dodge detekteras"""
	print("Perfect dodge performed against: ", enemy_attack.name)
	perfect_dodge_active = true
	
	# Visuell feedback
	show_perfect_dodge_effect()

func _on_time_slow_started():
	"""Kallas när time slow effekten börjar"""
	print("Time slow activated - damage multiplier active!")
	# Här kan du lägga till visuella effekter för slow motion

func _on_time_slow_ended():
	"""Kallas när time slow effekten slutar"""
	print("Time slow ended - back to normal")
	perfect_dodge_active = false

func show_perfect_dodge_effect():
	"""Visuell feedback för perfect dodge"""
	if not sprite:
		return
	
	# Blå glöd-effekt för att visa successful dodge
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Färgeffekt - blå glow
	tween.tween_property(sprite, "modulate", Color.CYAN, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)
	
	# Liten skala-effekt
	var original_scale = sprite.scale
	tween.tween_property(sprite, "scale", original_scale * 1.2, 0.1)
	tween.tween_property(sprite, "scale", original_scale, 0.4)

# Uppdatera din befintliga shoot_projectile() funktion för att använda damage multiplier:
func setup_projectile_preview():
	# Huvudcirkel (längst bort från spelaren)
	projectile_preview_main = Sprite2D.new()
	projectile_preview_main.texture = load("res://images/white_circle.svg")
	projectile_preview_main.scale = Vector2(0.15, 0.15)
	projectile_preview_main.modulate = Color(1, 1, 1, 0.6)
	projectile_preview_main.z_index = -1
	add_child(projectile_preview_main)
	
	# Mellanliggande cirkel
	projectile_preview_mid = Sprite2D.new()
	projectile_preview_mid.texture = load("res://images/white_circle.svg")
	projectile_preview_mid.scale = Vector2(0.12, 0.12)  # Mindre
	projectile_preview_mid.modulate = Color(1, 1, 1, 0.4)  # Mer transparent
	projectile_preview_mid.z_index = -1
	add_child(projectile_preview_mid)
	
	# Närmaste cirkel (närmast spelaren)
	projectile_preview_close = Sprite2D.new()
	projectile_preview_close.texture = load("res://images/white_circle.svg")
	projectile_preview_close.scale = Vector2(0.08, 0.08)  # Minst
	projectile_preview_close.modulate = Color(1, 1, 1, 0.25)  # Mest transparent
	projectile_preview_close.z_index = -1
	add_child(projectile_preview_close)

func update_projectile_preview():
	if not projectile_preview_main or not projectile_preview_mid or not projectile_preview_close:
		return
	
	# Beräkna riktning och positioner
	var mouse_pos = get_global_mouse_position()
	var shoot_direction = (mouse_pos - global_position).normalized()
	
	# Tre positioner med jämna mellanrum
	var main_position = global_position + (shoot_direction * 80)    # Längst bort
	var mid_position = global_position + (shoot_direction * 55)     # Mellanliggande
	var close_position = global_position + (shoot_direction * 30)   # Närmast spelaren
	
	# Uppdatera positioner
	projectile_preview_main.global_position = main_position
	projectile_preview_mid.global_position = mid_position
	projectile_preview_close.global_position = close_position
	
	# Visa/dölj alla baserat på om spelaren kan skjuta
	var should_show = can_shoot
	projectile_preview_main.visible = should_show
	projectile_preview_mid.visible = should_show
	projectile_preview_close.visible = should_show
	
func shoot_projectile():
	if not projectile_scene or not can_shoot:
		return
		
	print("=== SHOOTING PROJECTILE ===")
	
	# Get shoot direction toward mouse (din befintliga logik)
	var mouse_pos = get_global_mouse_position()
	var shoot_direction = (mouse_pos - global_position).normalized()
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	
	# Position it in front of player
	var spawn_position = global_position + (shoot_direction * 80)
	projectile.global_position = spawn_position
	
	print("Spawning projectile at: ", spawn_position)
	print("Shoot direction: ", shoot_direction)
	
	# Add to scene first
	get_tree().current_scene.add_child(projectile)
	
	# Wait one frame then initialize
	await get_tree().process_frame
	
	# NYTT: Kontrollera enhanced shots från dodge detector
	var damage_mult = 1.0
	if dodge_detector and "enhanced_shots_remaining" in dodge_detector and dodge_detector.enhanced_shots_remaining > 0:
		damage_mult = PerfectDodgeSystem.get_damage_multiplier() if PerfectDodgeSystem else 5.0
		dodge_detector.enhanced_shots_remaining -= 1
		print("Using enhanced shot! Remaining: ", dodge_detector.enhanced_shots_remaining)
	elif PerfectDodgeSystem and PerfectDodgeSystem.is_in_slow_motion():
		damage_mult = PerfectDodgeSystem.get_damage_multiplier()
		print("Shooting during slow motion! Damage multiplier: ", damage_mult)
	
	# Initialize the projectile med enhanced damage
	projectile.initialize(shoot_direction, projectile_speed)
	
	# Applicera damage multiplier
	if projectile.has_method("set_damage_multiplier"):
		projectile.set_damage_multiplier(damage_mult)
	elif "damage_multiplier" in projectile:
		projectile.damage_multiplier = damage_mult
	
	# Start cooldown
	start_shoot_cooldown()

# Lägg till i din _process() eller _physics_process() funktion:
func handle_perfect_dodge_system(delta):
	"""Hantera perfect dodge timing och effects"""
	if perfect_dodge_timer > 0:
		perfect_dodge_timer -= delta
		
func start_shoot_cooldown():
	can_shoot = false
	shoot_timer = shoot_cooldown

func handle_shoot_cooldown(delta):
	if not can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0:
			can_shoot = true

# DASH FUNCTIONS
func handle_dash_input():
	if not can_dash:
		return
		
	# Track shift key release
	if not Input.is_action_pressed("dash"):
		shift_released = true
	
	# Dash when shift pressed AND was previously released AND moving
	if Input.is_action_pressed("dash") and shift_released and can_dash:
		var dash_direction = Vector2.ZERO
		var old_position = global_position
		
		if Input.is_action_pressed("move_left"):
			dash_direction = Vector2(-1, 0)
			# Dash left
			global_position.x -= dash_distance
			var half_size = play_area_size * 0.5
			var left_bound = play_area_center.x - half_size.x + 25
			if global_position.x < left_bound:
				global_position.x = left_bound
			
		elif Input.is_action_pressed("move_right"):
			dash_direction = Vector2(1, 0)
			# Dash right  
			global_position.x += dash_distance
			var half_size = play_area_size * 0.5
			var right_bound = play_area_center.x + half_size.x - 25
			if global_position.x > right_bound:
				global_position.x = right_bound
		
		# Om vi dashade, starta cooldown och visa effekter
		if dash_direction != Vector2.ZERO:
			can_dash = false
			dash_timer = dash_cooldown
			shift_released = false
			
			# VISUELLA EFFEKTER!
			create_dash_effect()
			create_dash_afterimages(old_position, dash_direction)
			
			print("Dashed ", "left" if dash_direction.x < 0 else "right", "!")

func create_dash_effect():
	"""Visual effect for dash on player"""
	if not sprite:
		return
	update_sprite()
	# Flash effect - snabb cyan blink på spelaren
	var dash_tween = create_tween()
	dash_tween.set_parallel(true)
	
	# Quick flash sequence
	dash_tween.tween_property(sprite, "modulate", Color.CYAN, 0.05)
	dash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	dash_tween.tween_property(sprite, "modulate", Color.CYAN, 0.05)
	dash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	
	# Kort scale effect för att visa "speed"
	var original_scale = sprite.scale
	dash_tween.tween_property(sprite, "scale", original_scale * 1.2, 0.1)
	dash_tween.tween_property(sprite, "scale", original_scale, 0.1)

func create_dash_afterimages(start_pos: Vector2, dash_direction: Vector2):
	"""Create afterimage effect showing dash trail"""
	if not sprite:
		return
	
	# Create 3 afterimages spread out along the dash path
	var afterimage_count = 3
	var actual_dash_distance = abs(global_position.x - start_pos.x)
	
	for i in range(afterimage_count):
		# Create afterimage sprite
		var afterimage = Sprite2D.new()
		afterimage.texture = sprite.texture
		afterimage.scale = sprite.scale
		afterimage.rotation = sprite.rotation
		
		# Position along dash path
		var progress = float(i) / float(afterimage_count - 1)
		var afterimage_pos = start_pos + (dash_direction * actual_dash_distance * progress)
		afterimage.global_position = afterimage_pos
		
		# Set transparency (0.3, 0.5, 0.7)
		var alpha = 0.3 + (progress * 0.4)
		afterimage.modulate = Color(1.0, 1.0, 1.0, alpha)
		
		# Add to scene
		get_tree().current_scene.add_child(afterimage)
		
		# Animate afterimage - fade out
		var afterimage_tween = create_tween()
		afterimage_tween.set_parallel(true)
		
		# Fade out
		afterimage_tween.tween_property(afterimage, "modulate:a", 0.0, 0.2)
		
		# Scale down slightly
		afterimage_tween.tween_property(afterimage, "scale", sprite.scale * 0.8, 0.2)
		
		# Clean up
		afterimage_tween.tween_callback(func(): 
			if is_instance_valid(afterimage):
				afterimage.queue_free()
		).set_delay(0.2)
func handle_dash_cooldown(delta):
	if not can_dash:
		dash_timer -= delta
		if dash_timer <= 0:
			can_dash = true

func start_teleport_effect():
	is_teleporting = true
	if sprite:
		var tween = create_tween()
		tween.tween_method(set_sprite_modulate, Color.WHITE, Color.CYAN, 0.1)
		tween.tween_method(set_sprite_modulate, Color.CYAN, Color.WHITE, 0.1)

func handle_teleport_effect(delta):
	if is_teleporting:
		teleport_effect_duration -= delta
		if teleport_effect_duration <= 0:
			is_teleporting = false
			teleport_effect_duration = 0.1

func set_sprite_modulate(color: Color):
	if sprite:
		sprite.modulate = color

func update_sprite_rotation():
	if not sprite:
		return
	
	match current_wall:
		WallSide.BOTTOM:
			sprite.rotation = 0.0  # Normal orientation
		WallSide.TOP:
			sprite.rotation = PI  # Upside down
	
	var tween = create_tween()
	var target_rotation = 0.0
	
	match current_wall:
		WallSide.BOTTOM:
			target_rotation = 0.0  # Normal orientation
		WallSide.TOP:
			target_rotation = PI  # Upside down
	
	tween.tween_property(sprite, "rotation", target_rotation, 0.2)

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	health_bar.value = current_health
	# Visual damage feedback
	if sprite:
		var tween = create_tween()
		tween.tween_method(set_sprite_modulate, Color.WHITE, Color.RED, 0.1)
		tween.tween_method(set_sprite_modulate, Color.RED, Color.WHITE, 0.1)
	
	# Check if player died
	if current_health <= 0:
		player_died.emit()
		
	update_sprite()

func heal(amount: int):
	current_health += amount
	current_health = min(max_health, current_health)
	update_sprite()

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health
