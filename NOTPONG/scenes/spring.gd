extends Node2D

var velocity = 0.0
var force = 0.0
var height = 0.0
var target_height = 0.0
var index = 0
var motion_factor = 0.02
var collided_with = null

signal splash

@onready var collision = $Area2D/CollisionShape2D

func water_update(spring_constant, dampening):
	height = position.y
	var x = height - target_height
	var loss = -dampening * velocity
	force = -spring_constant * x + loss
	velocity += force
	position.y += velocity

func initialize(x_position, id):
	position.x = x_position
	# Wait one frame to ensure proper positioning
	await get_tree().process_frame
	height = position.y
	target_height = position.y
	velocity = 0.0
	index = id

func set_collision_width(value):
	var current_size = collision.shape.size
	var new_size = Vector2(value, current_size.y)
	collision.shape.size = new_size

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == collided_with:
		return
		
	collided_with = body	
	
	var speed = body.linear_velocity.y * motion_factor
	emit_signal("splash", index, speed)
