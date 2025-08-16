extends Control

@onready var options_menu = %OptionsMenu
@onready var username_entry = %UsernameEntry
@onready var scoreboard_list = %ScoreBoardList
@onready var loading_label = %LoadingLabel
@onready var refresh_button = %RefreshButton
@onready var fire_effect_scoreboard = %FireEffect
@onready var RefreshButtonTimeout = %RefreshButtonTimeout

# Animation tweens
var username_tween: Tween
var fire_effect_scoreboard_tween: Tween
var scoreboard_tween: Tween

func _ready():
	# Connect buttons using Godot 4.x syntax
	$VBoxContainer/btn_start.pressed.connect(_on_start_pressed)
	$VBoxContainer/btn_fullscreen.pressed.connect(_on_fullscreen_pressed)
	$VBoxContainer/btn_quit.pressed.connect(_on_quit_pressed)
	$VBoxContainer/btn_options.pressed.connect(_on_options_pressed)
	
	options_menu.visible = false
	
	# Setup username entry with current player name
	setup_username_entry()
	
	# Load leaderboard
	refresh_leaderboard()
	
	# Update fullscreen button text on start
	update_fullscreen_button_text()

func setup_username_entry():
	"""Setup username entry field with current player name and animations"""
	# Set current player name if it exists
	if Global.save_data.player_name and Global.save_data.player_name != "":
		username_entry.text = Global.save_data.player_name
		username_entry.placeholder_text = "Player name saved!"
	else:
		username_entry.placeholder_text = "Enter your player name"
	
	# Connect signals for better UX
	username_entry.text_changed.connect(_on_username_text_changed)
	username_entry.focus_entered.connect(_on_username_focus_entered)
	username_entry.focus_exited.connect(_on_username_focus_exited)
	
	# Initial styling
	username_entry.modulate = Color.WHITE

func _on_username_text_changed(new_text: String):
	"""Handle real-time username validation"""
	# Clean up text (remove invalid characters, limit length)
	var cleaned_text = clean_username(new_text)
	
	if cleaned_text != new_text:
		username_entry.text = cleaned_text
		username_entry.caret_column = cleaned_text.length()
	
	# Visual feedback based on validity
	if is_valid_username(cleaned_text):
		animate_username_valid()
	else:
		animate_username_invalid()

func clean_username(text: String) -> String:
	"""Clean username text - remove invalid chars and limit length"""
	# Remove special characters, keep only alphanumeric and basic symbols
	var cleaned = ""
	for character in text:
		if character.is_valid_int() or character.to_lower() in "abcdefghijklmnopqrstuvwxyz_-":
			cleaned += character
	
	# Limit to 16 characters
	if cleaned.length() > 16:
		cleaned = cleaned.substr(0, 16)
	
	return cleaned

func is_valid_username(text: String) -> bool:
	"""Check if username is valid"""
	return text.length() >= 3 and text.length() <= 16

func animate_username_valid():
	"""Animate username field for valid input"""
	if username_tween:
		username_tween.kill()
	
	username_tween = create_tween()
	username_tween.tween_property(username_entry, "modulate", Color.GREEN, 0.2)
	username_tween.tween_property(username_entry, "modulate", Color.WHITE, 0.3)

func animate_username_invalid():
	"""Animate username field for invalid input"""
	if username_tween:
		username_tween.kill()
	
	username_tween = create_tween()
	username_tween.tween_property(username_entry, "modulate", Color.RED, 0.1)
	username_tween.tween_property(username_entry, "modulate", Color.WHITE, 0.3)

func _on_username_focus_entered():
	"""Handle username field focus"""
	if username_tween:
		username_tween.kill()
	
	username_tween = create_tween()
	username_tween.tween_property(username_entry, "modulate", Color.CYAN, 0.2)

func _on_username_focus_exited():
	"""Handle username field losing focus"""
	if username_tween:
		username_tween.kill()
	
	username_tween = create_tween()
	username_tween.tween_property(username_entry, "modulate", Color.WHITE, 0.3)

func refresh_leaderboard():
	"""Refresh the leaderboard with loading animation"""
	show_loading_state(true)
	
	# Clear and load scores
	scoreboard_list.clear()
	
	var sw_result: Dictionary = await SilentWolf.Scores.get_scores().sw_get_scores_complete
	
	if sw_result.scores and sw_result.scores.size() > 0:
		populate_leaderboard(sw_result.scores)
	else:
		scoreboard_list.add_item("No scores yet - be the first!")
	
	show_loading_state(false)
	
	# Animate scoreboard back in
	scoreboard_tween = create_tween()
	scoreboard_tween.tween_property(scoreboard_list, "modulate", Color.WHITE, 0.3)

func populate_leaderboard(scores: Array):
	"""Populate leaderboard with scores and animations"""
	scoreboard_list.clear()
	var highlighted = false
	for i in range(min(scores.size(), 10)):  # Show top 10
		var entry = scores[i]
		var rank = i + 1
		var name = entry.player_name
		var score = entry.score
		
		# Add medal emoji for top 3
		var medal = ""
		match rank:
			1: medal = "1. "
			2: medal = "2. "
			3: medal = "3. "
			_: medal = str(rank) + ". "
		
		var score_text = "%s%s - %d" % [medal, name, score]
		scoreboard_list.add_item(score_text)
		
		# Highlight current player
		if name == Global.save_data.player_name and not highlighted:
			highlighted = true
			scoreboard_list.set_item_custom_bg_color(i, Color.DARK_GREEN)

func show_loading_state(loading: bool):
	"""Show/hide loading indicator"""
	if loading_label:
		loading_label.visible = loading
		if loading:
			animate_loading_text()
	
	if refresh_button:
		refresh_button.disabled = loading

func animate_loading_text():
	"""Animate loading text"""
	if not loading_label or not loading_label.visible:
		return
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(loading_label, "modulate", Color.CYAN, 0.5)
	tween.tween_property(loading_label, "modulate", Color.WHITE, 0.5)

func _on_start_pressed():
	# Validate username before starting
	var username = username_entry.text.strip_edges()
	if not is_valid_username(username):
		show_username_error()
		return
	
	# Save username
	Global.save_data.player_name = username
	Global.save_data.save()
	
	GlobalAudioManager.play_button_click()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func show_username_error():
	"""Show username validation error"""
	username_entry.grab_focus()
	
	# Flash red and shake
	if username_tween:
		username_tween.kill()
	
	username_tween = create_tween()
	username_tween.tween_property(username_entry, "modulate", Color.RED, 0.1)
	username_tween.tween_property(username_entry, "position", username_entry.position + Vector2(5, 0), 0.05)
	username_tween.tween_property(username_entry, "position", username_entry.position + Vector2(-5, 0), 0.05)
	username_tween.tween_property(username_entry, "position", username_entry.position, 0.05)
	username_tween.tween_property(username_entry, "modulate", Color.WHITE, 0.3)
	
	# Update placeholder text
	username_entry.placeholder_text = "Username must be 3-16 characters!"

func _on_fullscreen_pressed():
	GlobalAudioManager.play_button_click()
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	update_fullscreen_button_text()

func update_fullscreen_button_text():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		$VBoxContainer/btn_fullscreen.text = "Windowed"
	else:
		$VBoxContainer/btn_fullscreen.text = "Fullscreen"

func _on_quit_pressed():
	GlobalAudioManager.play_button_click()
	get_tree().quit()

func _on_options_pressed():
	GlobalAudioManager.play_button_click()
	options_menu.visible = true

func _on_username_entry_text_submitted(new_text: String) -> void:
	"""Handle Enter key pressed in username field"""
	var username = new_text.strip_edges()
	if is_valid_username(username):
		var old_name = Global.save_data.player_name
		
		# Handle username change properly
		var username_changed = Global.save_data.change_username(username)
		
		if username_changed:
			# Notify score manager about the change
			if has_node("/root/SmartScoreManager"):
				SmartScoreManager.handle_username_change(old_name, username)
			
			# Show success feedback
			animate_username_valid()
			username_entry.placeholder_text = "Username updated!"
			
			# Refresh leaderboard to show current player's entry
			refresh_leaderboard()
		else:
			username_entry.placeholder_text = "Same username!"
		
		username_entry.release_focus()
		print("Username processed: ", old_name, " -> ", username)
	else:
		show_username_error()

func _on_refresh_button_pressed():
	"""Simpler version with just basic spam protection"""
	
	if not RefreshButtonTimeout.is_stopped():
		_show_spam_feedback()
		return
	
	GlobalAudioManager.play_button_click()
	RefreshButtonTimeout.start()
	refresh_leaderboard()

func _show_spam_feedback():
	"""Red flash and shake effect for spam attempts"""
	# Red flash effect

	var flash_tween = create_tween()
	flash_tween.tween_property(refresh_button, "modulate", Color.RED, 0.1)
	flash_tween.tween_property(refresh_button, "modulate", Color.WHITE, 0.1)
	
	# Shake animation (separate tween)
	var shake_tween = create_tween()
	var original_pos = refresh_button.position
	shake_tween.tween_property(refresh_button, "position", original_pos + Vector2(-4, 0), 0.05)
	shake_tween.tween_property(refresh_button, "position", original_pos + Vector2(4, 0), 0.05)
	shake_tween.tween_property(refresh_button, "position", original_pos + Vector2(-2, 0), 0.05)
	shake_tween.tween_property(refresh_button, "position", original_pos, 0.05)
