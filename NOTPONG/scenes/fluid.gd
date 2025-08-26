extends Node2D

@export var k = 0.015
@export var d = 0.03
@export var spread = 0.0002
var springs = []
var passes = 8
@export var distance_between_springs = 32
@export var spring_number = 6
@export var depth = 1000
@export var border_thickness = 1.1

var target_height = 0.0
var bottom = 0.0

@onready var water_polygon = $water_polygon
@onready var water_spring = preload("res://scenes/spring.tscn")
@onready var water_border = $Water_Border
@onready var collisionShape = $Area2D/CollisionShape2D
@onready var water_body_area = $Area2D

func _ready():
	target_height = global_position.y
	bottom = target_height + depth
	
	spread = spread / 1000
	
	for i in range(spring_number):
		var x_position = distance_between_springs * i
		var w = water_spring.instantiate() 
		
		add_child(w)
		springs.append(w)
		w.initialize(x_position, i)
		w.set_collision_width(distance_between_springs)
		w.connect("splash", splash)
	
	var total_length = distance_between_springs * (spring_number - 1)
	
	var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(total_length, depth)
	collisionShape.shape = rectangle
	water_body_area.position = Vector2(total_length / 2, depth / 2)
	
func _physics_process(delta):
	for i in springs:
		i.water_update(k, d)
	
	var left_deltas = []
	var right_deltas = []
	for i in range(springs.size()):
		left_deltas.append(0)
		right_deltas.append(0)
		
	for j in range(passes):
		for i in range(springs.size()):
			if i > 0:
				left_deltas[i] = spread * (springs[i].height - springs[i-1].height)
				springs[i-1].velocity += left_deltas[i]
			if i < springs.size() - 1:
				right_deltas[i] = spread * (springs[i].height - springs[i+1].height)
				springs[i+1].velocity += right_deltas[i]
	
	new_border()
	draw_water_body()
	
func splash(index, speed):
	if index >= 0 and index < springs.size():
		springs[index].velocity += speed

func draw_water_body():
	var curve = water_border.curve
	var points = Array(curve.get_baked_points())
	
	if points.size() < 2:
		return
		
	var water_polygon_points = points.duplicate()
		
	var last_point = water_polygon_points[-1]
	var first_point = water_polygon_points[0]
	
	water_polygon_points.append(Vector2(last_point.x, bottom))
	water_polygon_points.append(Vector2(first_point.x, bottom))

	water_polygon.polygon = PackedVector2Array(water_polygon_points)

func new_border():
	var curve = Curve2D.new()
	
	var surface_points = []
	for i in range(springs.size()):
		surface_points.append(springs[i].position)
		
	surface_points.sort_custom(func(a, b): return a.x < b.x)
	
	for i in range(surface_points.size()):
		curve.add_point(surface_points[i])
	
	water_border.curve = curve
	water_border.smooth(true)
	water_border.queue_redraw()


func _on_area_2d_body_entered(body: Node2D) -> void:
	print(body, "has entered", self)
