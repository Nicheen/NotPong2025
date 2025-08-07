extends Control

# References to UI elements
@onready var master_volume_slider = %MasterVolumeSlider
@onready var master_volume_label = %MasterVolumeLabel
@onready var music_volume_slider = %MusicVolumeSlider  
@onready var music_volume_label = %MusicVolumeLabel
@onready var sfx_volume_slider = %SFXVolumeSlider
@onready var sfx_volume_label = %SFXVolumeLabel
@onready var back_button = %BackButton

# Audio bus indices
const MASTER_BUS = 0
const MUSIC_BUS = 1  
const SFX_BUS = 2

# Store the previous scene to return to
var previous_scene: String = ""

func _ready():
	# Load saved settings
	load_audio_settings()
	
	# Determine previous scene based on scene stack or a global variable
	# You might want to set this from the calling scene
	if get_tree().current_scene.scene_file_path.contains("main_menu"):
		previous_scene = "res://scenes/menus/main_menu.tscn"
	elif get_tree().current_scene.scene_file_path.contains("pause"):
		previous_scene = "res://scenes/menus/pause_menu.tscn"
	else:
		# Fallback - you might want to use a global variable instead
		previous_scene = "res://scenes/menus/main_menu.tscn"

func _on_master_volume_slider_value_changed(value: float) -> void:
	# Convert slider value (0-100) to decibels
	var db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(MASTER_BUS, db)
	
	# Update label
	master_volume_label.text = "Master Volume: " + str(int(value)) + "%"
	
	# Save setting
	save_audio_settings()

func _on_music_volume_slider_value_changed(value: float) -> void:
	var db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(MUSIC_BUS, db)
	
	music_volume_label.text = "Music Volume: " + str(int(value)) + "%"
	save_audio_settings()

func _on_sfx_volume_slider_value_changed(value: float) -> void:
	var db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(SFX_BUS, db)
	
	sfx_volume_label.text = "SFX Volume: " + str(int(value)) + "%"
	save_audio_settings()

func _on_back_button_pressed():
	# Return to the previous scene
	GlobalAudioManager.play_button_click()
	get_tree().change_scene_to_file(previous_scene)

func save_audio_settings():
	var config = ConfigFile.new()
	
	# Save volume levels as percentages (0-100)
	config.set_value("audio", "master_volume", master_volume_slider.value)
	config.set_value("audio", "music_volume", music_volume_slider.value)
	config.set_value("audio", "sfx_volume", sfx_volume_slider.value)
	
	config.save("user://settings.cfg")
	
func load_audio_settings():
	var config = ConfigFile.new()
	
	# Load settings file
	var err = config.load("user://settings.cfg")
	if err != OK:
		# File doesn't exist, use default values
		set_default_values()
		return
	
	# Load and apply saved values
	var master_vol = config.get_value("audio", "master_volume", 100.0)
	var music_vol = config.get_value("audio", "music_volume", 100.0)
	var sfx_vol = config.get_value("audio", "sfx_volume", 100.0)
	
	# Set slider values (this will trigger the volume change)
	master_volume_slider.value = master_vol
	music_volume_slider.value = music_vol
	sfx_volume_slider.value = sfx_vol
	
	# Update labels
	master_volume_label.text = "Master Volume: " + str(int(master_vol)) + "%"
	music_volume_label.text = "Music Volume: " + str(int(music_vol)) + "%"
	sfx_volume_label.text = "SFX Volume: " + str(int(sfx_vol)) + "%"
	
	# Apply to audio buses
	AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(master_vol / 100.0))
	AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(music_vol / 100.0))
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(sfx_vol / 100.0))

func set_default_values():
	master_volume_slider.value = 100.0
	music_volume_slider.value = 100.0
	sfx_volume_slider.value = 100.0
	
	master_volume_label.text = "Master Volume: 100%"
	music_volume_label.text = "Music Volume: 100%"
	sfx_volume_label.text = "SFX Volume: 100%"

# Alternative method: Use a global autoload to track previous scene
# You can create an autoload script called SceneManager and use:
# func _on_back_button_pressed():
#     SceneManager.go_to_previous_scene()
