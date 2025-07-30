extends Control

func _ready():
	# Connect buttons using Godot 4.x syntax
	$VBoxContainer/btn_start.pressed.connect(_on_start_pressed)
	$VBoxContainer/btn_fullscreen.pressed.connect(_on_fullscreen_pressed)
	$VBoxContainer/btn_quit.pressed.connect(_on_quit_pressed)
	# If you add options button later:
	# $VBoxContainer/btn_options.pressed.connect(_on_options_pressed)
	
	# Update fullscreen button text on start
	update_fullscreen_button_text()

func _on_start_pressed():
	# Load your game scene - replace with your actual game scene path
	get_tree().change_scene_to_file("res://scenes/main.tscn")  # Inte bara "res://Game.tscn"ned!")

func _on_fullscreen_pressed():
	# Toggle between fullscreen and windowed mode
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	# Update button text to reflect current state
	update_fullscreen_button_text()

func update_fullscreen_button_text():
	# Update button text based on current window mode
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		$VBoxContainer/btn_fullscreen.text = "Windowed"
	else:
		$VBoxContainer/btn_fullscreen.text = "Fullscreen"

func _on_quit_pressed():
	get_tree().quit()

# Optional: If you add an options button
func _on_options_pressed():
	# Load options scene or show options popup
	print("Options pressed - implement later")
	# get_tree().change_scene_to_file("res://Options.tscn")
