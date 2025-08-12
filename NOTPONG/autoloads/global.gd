extends Node

const GRID_SIZE: int = 32

var save_data:SaveData

func _ready():
	save_data = SaveData.load_or_create()
	
	SilentWolf.configure({
		"api_key": "jBhwvCZwPD7aOvNtI2eUk1vyNKI8v7KA4lUThVUS",
		"game_id": "NOTPONG",
		"log_level": 1
	})

	SilentWolf.configure_scores({
		"open_scene_on_close": "res://scenes/menus/main_menu.tscn"
	})
