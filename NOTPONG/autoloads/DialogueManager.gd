extends Node

@onready var text_box_scene = preload("res://ui/text box/text_box.tscn")

var dialog_lines: Array[String] = []
var current_line_index = 0

var text_box
var target_object: Node2D
var offset: Vector2 = Vector2(0, -50)

var is_dialog_active = false
var can_advance_line = false

func start_dialog(target: Node2D, lines: Array[String], offset_in: Vector2 = Vector2(0, -50)):
	if is_dialog_active:
		return
	
	if offset_in != Vector2(0, -50):
		offset = offset_in
	
	dialog_lines = lines
	target_object = target
	_show_text_box()
	
	is_dialog_active = true

func _show_text_box():
	text_box = text_box_scene.instantiate()
	text_box.finished_displaying.connect(_on_text_box_finished_displaying)
	
	add_child(text_box)
	
	update_text_box_position()
	text_box.display_text(dialog_lines[current_line_index])
	can_advance_line = false
	
func _process(_delta):
	# Update text box position every frame if dialog is active
	if is_dialog_active and text_box:
		if not is_instance_valid(target_object):
			end_dialog()
			return
			
		update_text_box_position()

func update_text_box_position():
	if not text_box or not target_object:
		return
	
	var screen_pos = target_object.global_position
	text_box.global_position = screen_pos + offset
		
func _on_text_box_finished_displaying():
	can_advance_line = true
	
func _unhandled_input(event) -> void:
	if (
		event.is_action_pressed("advance_dialog") &&
		is_dialog_active &&
		can_advance_line
	):
		text_box.queue_free()
		
		current_line_index += 1
		if current_line_index >= dialog_lines.size():
			end_dialog()
			return
		
		_show_text_box()

func end_dialog():
	is_dialog_active = false
	current_line_index = 0
	target_object = null
	if text_box:
		text_box.queue_free()
		text_box = null
