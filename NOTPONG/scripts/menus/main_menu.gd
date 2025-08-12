extends Control

@onready var options_menu = %OptionsMenu
@onready var username_entry = %UsernameEntry
@onready var scoreboard_list = %ScoreBoardList

func _ready():
	# Connect buttons using Godot 4.x syntax
	$VBoxContainer/btn_start.pressed.connect(_on_start_pressed)
	$VBoxContainer/btn_fullscreen.pressed.connect(_on_fullscreen_pressed)
	$VBoxContainer/btn_quit.pressed.connect(_on_quit_pressed)
	$VBoxContainer/btn_options.pressed.connect(_on_options_pressed)
	
	options_menu.visible = false
	
	var sw_result: Dictionary = await SilentWolf.Scores.get_scores().sw_get_scores_complete
	
	# Clear any existing items
	scoreboard_list.clear()

	# Iterate over each score entry
	for entry in sw_result.scores:
		var name = entry.player_name
		var score = entry.score
		scoreboard_list.add_item("%s - %d" % [name, score])
		print("Added: " + "%s - %d" % [name, score])
		
	print("Scores: " + str(sw_result.scores))
	# Update fullscreen button text on start
	update_fullscreen_button_text()

func _on_start_pressed():
	# Load your game scene - replace with your actual game scene path
	GlobalAudioManager.play_button_click()
	get_tree().change_scene_to_file("res://scenes/main.tscn")  # Inte bara "res://Game.tscn"ned!")

func _on_fullscreen_pressed():
	# Toggle between fullscreen and windowed mode
	GlobalAudioManager.play_button_click()
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
	GlobalAudioManager.play_button_click()
	get_tree().quit()

# Optional: If you add an options button
func _on_options_pressed():
	# Load options scene or show options popup
	GlobalAudioManager.play_button_click()
	options_menu.visible = true


func _on_username_entry_text_submitted(new_text: String) -> void:
	Global.save_data.player_name = new_text
	Global.save_data.save()
	print("Saved new player name as " + str(new_text))
