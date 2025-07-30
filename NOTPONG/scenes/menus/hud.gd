class_name HUD extends CanvasLayer

@onready var level: Label = %Level
@onready var score: Label = %Score
@onready var high_score: Label = %HighScore

func _ready() -> void:
	high_score.text = "High Score: " + str(Global.save_data.high_score)
	
func update_score(n:int):
	score.text = "Score: " + str(n)

func update_level(current_level:int):
	level.text = "Level: " + str(current_level)
