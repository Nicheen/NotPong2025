class_name HUD extends CanvasLayer

@onready var level: Label = %Level
@onready var score: Label = %Score
@onready var high_score: Label = %HighScore
@onready var timer: Label = %Timer

func _ready() -> void:
	high_score.text = "High Score: " + str(Global.save_data.high_score)
	
func update_score(n:int):
	score.text = "Score: " + str(n)

func update_level(current_level:int):
	level.text = "Level: " + str(current_level)
	
func update_timer(current_time: float):
	var minutes = int(current_time) / 60
	var seconds = int(current_time) % 60
	var milliseconds = int((current_time - int(current_time)) * 1000)
	timer.text = "%02d:%02d.%03d" % [minutes, seconds, milliseconds]
