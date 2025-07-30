extends Control

func _ready():
	# Connect buttons
	$Panel/VBoxContainer/btn_restart.pressed.connect(_on_restart_pressed)
	$Panel/VBoxContainer/btn_main_menu.pressed.connect(_on_main_menu_pressed)
	$Panel/VBoxContainer/btn_quit.pressed.connect(_on_quit_pressed)
	
	# Hide death menu initially
	visible = false
	
	# Set process mode to always process (so it works when game is paused)
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_death_menu():
	visible = true
	get_tree().paused = true
	
	# Optional: Grab focus on restart button
	$Panel/VBoxContainer/btn_restart.grab_focus()

func hide_death_menu():
	visible = false
	get_tree().paused = false

func _on_restart_pressed():
	print("Restarting game...")
	
	# Unpause before changing scene
	get_tree().paused = false
	
	# Restart the current scene
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	print("Returning to main menu...")
	
	# Unpause before changing scene
	get_tree().paused = false
	
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func _on_quit_pressed():
	print("Quitting game...")
	get_tree().quit()
