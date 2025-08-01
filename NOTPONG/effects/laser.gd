## Casts a laser along a raycast, emitting particles on the impact point.
## Use `is_casting` to make the laser fire and stop.
## You can attach it to a weapon or a ship; the laser will rotate with its parent.
@tool
extends RayCast2D

## Speed at which the laser extends when first fired, in pixels per seconds.
@export var cast_speed := 7000.0
## Maximum length of the laser in pixels.
@export var max_length := 1400.0
@export var line_width: int = 10
## Distance in pixels from the origin to start drawing and firing the laser.
@export var start_distance := 40.0
## Base duration of the tween animation in seconds.
@export var growth_time := 0.1
@export var color := Color.WHITE: set = set_color

## If `true`, the laser is firing.
## It plays appearing and disappearing animations when it's not animating.
## See `appear()` and `disappear()` for more information.
@export var is_casting := false: set = set_is_casting

var tween: Tween = null
var current_hit_color := Color.WHITE
var original_particle_color := Color.WHITE

@onready var line_2d: Line2D = %Line2D
@onready var casting_particles: GPUParticles2D = %CastingParticles2D
@onready var collision_particles: GPUParticles2D = %CollisionParticles2D
@onready var beam_particles: GPUParticles2D = %BeamParticles2D
@onready var hit_particles: GPUParticles2D = %HitParticles2D

func _ready() -> void:
	store_original_particle_color()
	
	var core_texture = create_laser_core_texture(color)
	line_2d.texture = core_texture
	line_2d.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	set_color(color)
	set_is_casting(is_casting)
	line_2d.points[0] = Vector2.RIGHT * start_distance
	line_2d.points[1] = Vector2.ZERO
	line_2d.visible = false
	casting_particles.position = line_2d.points[0]

	if not Engine.is_editor_hint():
		set_physics_process(false)

func get_current_hit_color() -> Color:
	return current_hit_color
	
func store_original_particle_color():
	# Try to get color from collision particles' gradient or modulate
	if hit_particles:
		if hit_particles.process_material:
			var material = hit_particles.process_material as ParticleProcessMaterial
			if material and material.color_ramp and material.color_ramp.gradient:
				var gradient = material.color_ramp.gradient
				if gradient.colors.size() > 0:
					original_particle_color = gradient.colors[0]
					print("Stored original particle color from gradient: ", original_particle_color)
					return
		
		# Fallback to modulate if no gradient color found
		original_particle_color = hit_particles.modulate
		print("Stored original particle color from modulate: ", original_particle_color)
	else:
		print("Warning: collision_particles not found, using white as fallback")
		
func _physics_process(delta: float) -> void:
	target_position = target_position.move_toward(Vector2.RIGHT * max_length, cast_speed * delta)
	
	# Clamp laser to lava border - coordinates are relative to laser block spawn point
	# Y is horizontal (left/right), X is vertical (up/down)
	var max_distance_to_lava = 639 - global_position.y
	var laser_end_position := Vector2(min(target_position.x, max_distance_to_lava), min(target_position.y, max_length))
	
	# Check if we hit lava (reached max distance)
	var hit_lava = target_position.x >= max_distance_to_lava
	
	force_raycast_update()
	if is_colliding():
		laser_end_position = to_local(get_collision_point())
		collision_particles.global_rotation = get_collision_normal().angle()
		collision_particles.position = laser_end_position
		
		hit_particles.global_rotation = get_collision_normal().angle()
		hit_particles.position = laser_end_position + Vector2(10, 0)
		
		# Change particle velocity direction for object hits (not lava)
		var collision_material = collision_particles.process_material as ParticleProcessMaterial
		if collision_material:
			collision_material.direction = Vector3(1, 0, 0)  # Changed from (0, -1, 0) to (1, 0, 0)
		
		var hit_material = hit_particles.process_material as ParticleProcessMaterial
		if hit_material:
			hit_material.direction = Vector3(1, 0, 0)  # Changed from (0, -1, 0) to (1, 0, 0)
		
		var hit_body = get_collider()
		current_hit_color = get_object_color(hit_body)
		
		var material = hit_particles.process_material as ParticleProcessMaterial
		if material and material.color_ramp:
			update_gradient_colors(material.color_ramp, current_hit_color)
	elif hit_lava:
		# Hitting lava - show particles at lava border with default direction
		collision_particles.global_rotation = 0
		collision_particles.position = laser_end_position
		
		hit_particles.global_rotation = 0
		hit_particles.position = laser_end_position + Vector2(10, 0)
		
		# Reset particle velocity direction for lava hits (keep original direction)
		var collision_material = collision_particles.process_material as ParticleProcessMaterial
		if collision_material:
			collision_material.direction = Vector3(0, -1, 0)  # Original direction for lava
		
		var hit_material = hit_particles.process_material as ParticleProcessMaterial
		if hit_material:
			hit_material.direction = Vector3(0, -1, 0)  # Original direction for lava
	
	line_2d.points[1] = laser_end_position
	var laser_start_position := line_2d.points[0]
	beam_particles.position = laser_start_position + (laser_end_position - laser_start_position) * 0.5
	beam_particles.process_material.emission_box_extents.x = laser_end_position.distance_to(laser_start_position) * 0.5
	
	# Show particles if colliding with objects OR hitting lava
	collision_particles.emitting = is_colliding() or hit_lava
	hit_particles.emitting = is_colliding() or hit_lava
func update_gradient_colors(gradient_texture: GradientTexture1D, hit_color: Color):
	if not gradient_texture or not gradient_texture.gradient:
		return
	
	var gradient = gradient_texture.gradient
	var colors = gradient.colors
	
	colors[0] = hit_color  # Start with full hit color
		
	# Apply the updated colors
	gradient.colors = colors
	
func ease_in_quint(x: float) -> float:
	return pow(x, 5)
	
func ease_out_quint(x: float) -> float:
	return 1.0 - pow(1.0 - x, 5)
	
func get_texture_dominant_color(texture: Texture2D, modulate_color: Color) -> Color:
	if not texture:
		return original_particle_color
	
	# Get the texture as an Image
	var image = texture.get_image()
	if not image:
		return original_particle_color
	
	# Sample key pixels to determine dominant color
	var width = image.get_width()
	var height = image.get_height()
	
	# Sample from the top area since that's where the laser hits
	var sample_y = int(height * 0.2)  # Top 20% of the texture
	var sample_count = 0
	var total_color = Color.BLACK
	
	# Sample pixels across the width at the top area
	var step = max(1, width / 10)  # Sample 10 points across
	for x in range(0, width, step):
		var pixel_color = image.get_pixel(x, sample_y)
		
		# Skip transparent pixels
		if pixel_color.a > 0.1:
			total_color += pixel_color
			sample_count += 1
	
	# Calculate average color
	if sample_count > 0:
		total_color = total_color / sample_count
		# Apply modulate color
		total_color = total_color * modulate_color
		return total_color
	
	return modulate_color
	
func get_sprite_from_object(obj) -> Sprite2D:
	# Direct sprite check
	if obj is Sprite2D:
		return obj
	
	# Check if object has a Sprite2D child
	if obj.has_method("get_children"):
		for child in obj.get_children():
			if child is Sprite2D:
				return child
			# Check nested children
			var nested_sprite = get_sprite_from_object(child)
			if nested_sprite:
				return nested_sprite
	
	# Check for common sprite node names
	var common_names = ["Sprite2D", "sprite", "Sprite", "sprite_2d"]
	for name in common_names:
		if obj.has_node(name):
			var node = obj.get_node(name)
			if node is Sprite2D:
				return node
	
	return null
	
func get_object_color(hit_object) -> Color:
	if not hit_object:
		return original_particle_color
	
	# Try to get sprite from the hit object
	var sprite = get_sprite_from_object(hit_object)
	if not sprite:
		return original_particle_color
	
	# Get the texture color
	var texture_color = get_texture_dominant_color(sprite.texture, sprite.modulate)
	
	return texture_color
	
func create_laser_core_texture(base_color: Color) -> ImageTexture:
	var size = 64
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center_y = size / 2.0
	
	for x in range(size):
		for y in range(size):
			var distance_from_center = abs(y - center_y) / center_y
			distance_from_center = clamp(distance_from_center, 0.0, 1.0)
			
			# Alpha fades out toward the edges
			var alpha = 1.0 - ease_in_quint(distance_from_center)
			
			# Color goes from base to bright toward the edges
			var bright_color = base_color.lerp(Color.WHITE, 0.8)
			var color_mix = ease_in_quint(distance_from_center)
			var final_color = base_color.lerp(bright_color, color_mix)
			final_color.a = alpha
			
			image.set_pixel(x, y, final_color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture
	
func set_is_casting(new_value: bool) -> void:
	if is_casting == new_value:
		return
	is_casting = new_value
	set_physics_process(is_casting)

	if beam_particles == null:
		return

	beam_particles.emitting = is_casting
	casting_particles.emitting = is_casting

	if is_casting:
		var laser_start := Vector2.RIGHT * start_distance
		line_2d.points[0] = laser_start
		line_2d.points[1] = laser_start
		casting_particles.position = laser_start

		appear()
	else:
		target_position = Vector2.ZERO
		collision_particles.emitting = false
		hit_particles.emitting = false
		disappear()

func appear() -> void:
	line_2d.visible = true
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.tween_property(line_2d, "width", line_width, growth_time * 2.0).from(0.0)

func disappear() -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.tween_property(line_2d, "width", 0.0, growth_time).from_current()
	tween.tween_callback(line_2d.hide)

func set_color(new_color: Color) -> void:
	color = new_color
	
	if line_2d == null:
		return

	line_2d.modulate = new_color
	casting_particles.modulate = new_color
	collision_particles.modulate = new_color
	beam_particles.modulate = new_color
