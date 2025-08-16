# Enhanced Death Menu Script
extends Control

signal new_highscore

@onready var high_score_label = $Panel/HighScoreLabel
@onready var score_label = $Panel/VBoxContainer/ScoreLabel
@onready var submission_status = %SubmissionStatus
@onready var username_display = %UsernameDisplay

var final_score: int = 0
var score_submitted: bool = false
var animation_tween: Tween

func _ready():
	# Connect buttons
	$Panel/VBoxContainer/btn_restart.pressed.connect(_on_restart_pressed)
	$Panel/VBoxContainer/btn_main_menu.pressed.connect(_on_main_menu_pressed)
	$Panel/VBoxContainer/btn_quit.pressed.connect(_on_quit_pressed)
	
	# Hide death menu initially
	visible = false
	high_score_label.visible = false
	if submission_status:
		submission_status.visible = false
	
	# Set process mode to always process (so it works when game is paused)
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_death_menu(score: int = 0):
	"""Show death menu with enhanced score submission feedback"""
	final_score = score
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Update score display
	if score_label:
		score_label.text = "Final Score: " + str(final_score)
	
	# Show current username
	if username_display and Global.save_data.player_name:
		username_display.text = "Playing as: " + Global.save_data.player_name
		username_display.visible = true
	else:
		if username_display:
			username_display.visible = false
	
	# Check if it's a high score and submit
	check_and_submit_score()
	
	# Grab focus on restart button
	$Panel/VBoxContainer/btn_restart.grab_focus()

func check_and_submit_score():
	"""Enhanced score submission using the smart score manager"""
	if not Global.save_data.player_name or Global.save_data.player_name == "":
		show_submission_status("⚠️ No username set - score not submitted", Color.ORANGE)
		return
	
	if final_score <= 0:
		show_submission_status("Score too low for leaderboard", Color.GRAY)
		return
	
	# Check if it's a new personal high score
	if final_score > Global.save_data.high_score:
		show_new_highscore_label()
		Global.save_data.high_score = final_score
		Global.save_data.save()
	
	# Use smart score manager for submission
	submit_score_with_smart_manager()

func submit_score_with_smart_manager():
	"""Submit score using the smart score manager"""
	show_submission_status("📡 Submitting score...", Color.CYAN)
	
	# Check if SmartScoreManager exists
	if not has_node("/root/SmartScoreManager"):
		show_submission_status("❌ Score manager not found", Color.RED)
		return
	

	var result = await SmartScoreManager.submit_game_score(final_score)
	
	if result.success:
		show_submission_status("✅ " + result.message, Color.GREEN)
		score_submitted = true
	else:
		# Handle different types of "failures" that are actually OK
		if result.message == "Not a personal best":
			show_submission_status("📊 Score recorded (not a new personal best)", Color.YELLOW)
		elif result.message == "Score too low":
			show_submission_status("Score too low for global leaderboard", Color.GRAY)
		else:
			show_submission_status("❌ " + result.message, Color.RED)
	

func show_submission_status(message: String, color: Color):
	"""Show score submission status with animation"""
	if not submission_status:
		return
	
	submission_status.text = message
	submission_status.modulate = color
	submission_status.visible = true
	
	# Animate status message
	var status_tween = create_tween()
	status_tween.tween_property(submission_status, "scale", Vector2(1.1, 1.1), 0.2)
	status_tween.tween_property(submission_status, "scale", Vector2.ONE, 0.2)

func show_new_highscore_label():
	"""Show new highscore celebration"""
	if not high_score_label:
		return
		
	high_score_label.text = "🎉 NEW HIGH SCORE! 🎉"
	high_score_label.modulate = Color.GOLD
	high_score_label.visible = true
	
	# Animate high score label
	var celebration_tween = create_tween()
	celebration_tween.set_loops()
	celebration_tween.tween_property(high_score_label, "scale", Vector2(1.2, 1.2), 0.3)
	celebration_tween.tween_property(high_score_label, "scale", Vector2.ONE, 0.3)
	
	# Stop after a few cycles
	get_tree().create_timer(3.0).timeout.connect(func(): 
		if celebration_tween:
			celebration_tween.kill()
			high_score_label.scale = Vector2.ONE
	)

func hide_death_menu():
	"""Hide death menu with animation"""
	if animation_tween:
		animation_tween.kill()
	
	animation_tween = create_tween()
	animation_tween.parallel().tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	animation_tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), 0.3)
	
	await animation_tween.finished
	
	visible = false
	get_tree().paused = false

func _on_restart_pressed():
	print("Restarting game...")
	GlobalAudioManager.play_button_click()
	
	# Unpause before changing scene
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	print("Returning to main menu...")
	GlobalAudioManager.play_button_click()
	
	# Unpause before changing scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func _on_quit_pressed():
	print("Quitting game...")
	GlobalAudioManager.play_button_click()
	get_tree().quit()

# Enhanced scene file content for the death menu
# Add this to your death_menu.tscn as additional nodes:

# Add these new nodes to your existing death_menu.tscn:

# [node name="SubmissionStatus" type="Label" parent="Panel/VBoxContainer"]
# unique_name_in_owner = true
# layout_mode = 2
# theme_override_font_sizes/font_size = 12
# text = ""
# horizontal_alignment = 1
# autowrap_mode = 2

# [node name="UsernameDisplay" type="Label" parent="Panel/VBoxContainer"]
# unique_name_in_owner = true
# layout_mode = 2
# theme_override_font_sizes/font_size = 10
# text = "Playing as: PlayerName"
# horizontal_alignment = 1
# modulate = Color(0.8, 0.8, 0.8, 1)
