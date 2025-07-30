extends Control

var is_paused: bool = false

func _ready():
	# Connect buttons
	$Panel/VBoxContainer/btn_resume.pressed.connect(_on_resume_pressed)
	$Panel/VBoxContainer/btn_options.pressed.connect(_on_options_pressed)
	$Panel/VBoxContainer/btn_main_menu.pressed.connect(_on_main_menu_pressed)
	$Panel/VBoxContainer/btn_quit.pressed.connect(_on_quit_pressed)
	
	# Hide pause menu initially
	visible = false
	
	# Set process mode to always process (so it works when game is paused)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	# Toggle pause when ESC is pressed
	if event.is_action_pressed("ui_cancel"):  # ESC key
		toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	
	if is_paused:
		show_pause_menu()
	else:
		hide_pause_menu()

func show_pause_menu():
	visible = true
	get_tree().paused = true
	
	# Optional: Grab focus on resume button
	$Panel/VBoxContainer/btn_resume.grab_focus()

func hide_pause_menu():
	visible = false
	get_tree().paused = false
	is_paused = false

func _on_resume_pressed():
	hide_pause_menu()

func _on_options_pressed():
	# Implement options menu later
	print("Options pressed - implement later")
	# You could show another menu here or change to options scene

func _on_main_menu_pressed():
	# Unpause before changing scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func _on_quit_pressed():
	get_tree().quit()
