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

@onready var line_2d: Line2D = %Line2D
@onready var casting_particles: GPUParticles2D = %CastingParticles2D
@onready var collision_particles: GPUParticles2D = %CollisionParticles2D
@onready var beam_particles: GPUParticles2D = %BeamParticles2D


func _ready() -> void:
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


func _physics_process(delta: float) -> void:
	target_position = target_position.move_toward(Vector2.RIGHT * max_length, cast_speed * delta)

	var laser_end_position := target_position
	force_raycast_update()

	if is_colliding():
		laser_end_position = to_local(get_collision_point())
		collision_particles.global_rotation = get_collision_normal().angle()
		collision_particles.position = laser_end_position

	line_2d.points[1] = laser_end_position

	var laser_start_position := line_2d.points[0]
	beam_particles.position = laser_start_position + (laser_end_position - laser_start_position) * 0.5
	beam_particles.process_material.emission_box_extents.x = laser_end_position.distance_to(laser_start_position) * 0.5

	collision_particles.emitting = is_colliding()
func ease_in_quint(x: float) -> float:
	return pow(x, 5)
func ease_out_quint(x: float) -> float:
	return 1.0 - pow(1.0 - x, 5)
	
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
