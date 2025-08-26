@tool
class_name SmoothPath extends Path2D

@export var spline_length = 8
@export var _smooth: bool: set = smooth
@export var _straighten: bool: set = straighten
@export var color: Color = Color(1,1,1,1)

func straighten(value: bool) -> void:
	if not value:
		return
	for i in range(curve.get_point_count()):
		curve.set_point_in(i, Vector2.ZERO)
		curve.set_point_out(i, Vector2.ZERO)

func smooth(value: bool) -> void:
	if not value:
		return
	var point_count = curve.get_point_count()
	for i in range(point_count):
		var spline = _get_spline(i)
		curve.set_point_in(i, -spline)
		curve.set_point_out(i, spline)

func _get_spline(i: int) -> Vector2:
	var last_point = _get_point(i - 1)
	var next_point = _get_point(i + 1)
	return last_point.direction_to(next_point) * spline_length

func _get_point(i: int) -> Vector2:
	var point_count = curve.get_point_count()
	i = wrapi(i, 0, point_count)  # ✅ Godot 4 wrapi uses exclusive max
	return curve.get_point_position(i)

func _draw() -> void:
	var points: PackedVector2Array = curve.get_baked_points()
	if points.size() > 1:
		draw_polyline(points, Color.LIGHT_YELLOW, 1.1, true)  # last arg = antialiased
