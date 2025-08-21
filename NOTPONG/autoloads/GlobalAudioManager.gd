# GlobalAudioManager.gd - Autoload for managing audio across scenes
extends Node

# Audio players for global sounds
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# Current music track
var current_music: AudioStream
var music_position: float = 0.0

# Common sound effects - preload these
var ui_sounds = {
	"button_click": preload("res://audio/sfx/button_click.mp3"),
	"button_hover": preload("res://audio/sfx/button_hover.mp3"),
	"menu_open": preload("res://audio/sfx/menu_open.mp3"),
	"menu_close": preload("res://audio/sfx/menu_close.mp3"),
}

func _ready():
	var bus_layout = load("res://default_bus_layout.tres")
	if bus_layout:
		AudioServer.set_bus_layout(bus_layout)
	# Create global audio players
	music_player = AudioStreamPlayer.new()
	sfx_player = AudioStreamPlayer.new()
	
	# Set up audio players
	music_player.bus = "Music"
	sfx_player.bus = "SFX"

	# Add to scene tree
	add_child(music_player)
	add_child(sfx_player)
	
	# Connect to scene changes to persist music
	get_tree().tree_changed.connect(_on_scene_changed)
	
	play_music(preload("res://audio/music/music for game.mp3"))

func _on_scene_changed():
	# Store music position when scene changes
	if music_player.playing:
		music_position = music_player.get_playback_position()

# Play background music (persists across scenes)
func play_music(music: AudioStream, fade_in: bool = true, loop: bool = true):
	if current_music == music and music_player.playing:
		return  # Already playing this music
	
	current_music = music
	
	if fade_in and music_player.playing:
		# Fade out current music, then fade in new music
		await fade_out_music(0.5)
	
	music_player.stream = music
	if music_player.stream:
		music_player.stream.loop = loop
	
	if fade_in:
		music_player.volume_db = -80.0
		music_player.play()
		fade_in_music(1.0)
	else:
		music_player.volume_db = 0.0
		music_player.play()

# Stop music with optional fade out
func stop_music(fade_out: bool = true):
	if fade_out:
		await fade_out_music(1.0)
	else:
		music_player.stop()
	current_music = null

# Fade out music
func fade_out_music(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	await tween.finished
	music_player.stop()

# Fade in music
func fade_in_music(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", 0.0, duration)

# Play sound effect
func play_sfx(sound: AudioStream):
	if sound and sfx_player:
		sfx_player.stream = sound
		sfx_player.play()

# Play sound effect with volume, start_time, and end_time
func play_sfx_advanced(sound: AudioStream, volume_db: float = 0.0, start_time: float = 0.0, end_time: float = -1.0):
	if not sound or not sfx_player:
		return
	
	sfx_player.stream = sound
	sfx_player.volume_db = volume_db
	
	# Start playing from given position
	sfx_player.play(start_time)
	
	# If end_time is set, stop after reaching it
	if end_time > 0.0 and end_time > start_time:
		var duration = end_time - start_time
		var timer = get_tree().create_timer(duration)
		await timer.timeout
		if sfx_player.playing and sfx_player.stream == sound:
			sfx_player.stop()

# Play UI sounds
func play_ui_sound(sound_name: String):
	if sound_name in ui_sounds:
		play_sfx(ui_sounds[sound_name])

# Convenience functions for common UI sounds
func play_button_click():
	play_ui_sound("button_click")

func play_button_hover():
	play_ui_sound("button_hover")

func play_menu_open():
	play_ui_sound("menu_open")

func play_menu_close():
	play_ui_sound("menu_close")

# Pause/resume music (useful for pause menus)
func pause_music():
	music_player.stream_paused = true

func resume_music():
	music_player.stream_paused = false

# Get current music volume (useful for options menu)
func get_music_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(1)) * 100.0

# Set music volume (called from options menu)
func set_music_volume(volume: float):
	var db = linear_to_db(volume / 100.0)
	AudioServer.set_bus_volume_db(1, db)

# Usage examples:
# GlobalAudioManager.play_music(preload("res://audio/music/level1.ogg"))
# GlobalAudioManager.play_sfx(preload("res://audio/sfx/pickup.ogg"), -3.0)
# GlobalAudioManager.play_button_click()
