extends MarginContainer

@onready var label: Label = %Label
@onready var timer: Timer = %LetterDisplayTimer

const MAX_WIDTH = 256

var text = ""
var letter_index = 0

var letter_time = 0.03
var space_time = 0.06
var punctuation_time = 0.2

signal finished_displaying()

func display_text(text_to_display: String):
	text = text_to_display
	print("[TEXT] Starting display_text with: '", text_to_display, "'")
	print("[TEXT] Text length: ", text_to_display.length())
	
	# Connect timer signal if not already connected
	if not timer.timeout.is_connected(_on_letter_display_timer_timeout):
		timer.timeout.connect(_on_letter_display_timer_timeout)
		print("[TEXT] Connected timer timeout signal")
	
	# Set the text temporarily to measure size
	label.text = text_to_display
	
	# Force an immediate layout update
	await get_tree().process_frame
	print("[TEXT] After process_frame, size is: ", size)
	
	# Set minimum width
	custom_minimum_size.x = min(size.x, MAX_WIDTH)
	print("[TEXT] Set minimum width to: ", custom_minimum_size.x)
	
	# Handle text wrapping if needed
	if size.x > MAX_WIDTH:
		print("[TEXT] Text width exceeds MAX_WIDTH, enabling autowrap")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		# Wait for layout to update after autowrap
		await get_tree().process_frame
		await get_tree().process_frame
		
		custom_minimum_size.y = size.y
		print("[TEXT] Set minimum height to: ", custom_minimum_size.y)
	
	# Position the text box
	global_position.x -= size.x / 2
	global_position.y -= size.y + 24
	print("[TEXT] Positioned text box at: ", global_position)
	
	# Now start the typewriter effect
	label.text = ""
	letter_index = 0
	print("[TEXT] Cleared label text, reset letter_index to 0")
	print("[TEXT] Starting typewriter effect...")
	_display_letter()
	
func _display_letter():
	if letter_index >= text.length():
		print("[TEXT] ERROR: letter_index (", letter_index, ") >= text.length() (", text.length(), ")")
		return
	
	var current_char = text[letter_index]
	label.text += current_char
	print("[TEXT] Displaying letter ", letter_index + 1, "/", text.length(), ": '", current_char, "'")
	print("[TEXT] Current label text: '", label.text, "'")
	
	letter_index += 1
	GlobalAudioManager.play_sfx(preload("res://audio/speaking_voice.mp3"))
	
	if letter_index >= text.length():
		print("[TEXT] Finished displaying all letters!")
		print("[TEXT] Emitting finished_displaying signal")
		finished_displaying.emit()
		return
	
	var next_char = text[letter_index]
	print("[TEXT] Next character will be: '", next_char, "'")
	
	match next_char:
		"!", ".", ",", "?":
			print("[TEXT] Next char is punctuation, using punctuation_time: ", punctuation_time)
			timer.start(punctuation_time)
		" ":
			print("[TEXT] Next char is space, using space_time: ", space_time)
			timer.start(space_time)
		_:
			print("[TEXT] Next char is regular letter, using letter_time: ", letter_time)
			timer.start(letter_time)
	
	print("[TEXT] Timer started, waiting for timeout...")

func _on_letter_display_timer_timeout() -> void:
	print("[TEXT] Timer timeout triggered! Calling _display_letter()")
	_display_letter()
