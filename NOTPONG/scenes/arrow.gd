extends Node2D

# The vector to visualize
@export var vector: Vector2 = Vector2(1, 1)
@export var arrow_color: Color = Color.RED
@export var axis_color: Color = Color.GRAY
@export var arrow_thickness: float = 3.0
@export var axis_thickness: float = 1.0
@export var arrow_size: float = 10.0

func _draw():
	# Draw X and Y axes
	draw_line(Vector2.ZERO, Vector2(200, 0), axis_color, axis_thickness)
	draw_line(Vector2.ZERO, Vector2(0, 200), axis_color, axis_thickness)
	
	# Draw the vector arrow
	draw_arrow(Vector2.ZERO, vector * 50, arrow_color, arrow_thickness, arrow_size)

# Utility function to draw an arrow
func draw_arrow(from: Vector2, to: Vector2, color: Color, width: float, size: float):
	draw_line(from, to, color, width)
	
	var dir = (to - from).normalized()
	var perp = Vector2(-dir.y, dir.x) * size * 0.5
	draw_line(to, to - dir * size + perp, color, width)
	draw_line(to, to - dir * size - perp, color, width)
