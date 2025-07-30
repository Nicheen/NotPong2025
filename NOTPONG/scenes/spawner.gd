class_name Spawner extends Node2D

@export var bounds:Bounds

var player_scene:PackedScene = preload("res://scenes/obj/Player.tscn")
var enemy_scene:PackedScene = preload("res://scenes/obj/Enemy.tscn")

func spawn_enemy():
	# 1 where to spawn it (position)
	var spawn_point:Vector2 = Vector2.ZERO
	spawn_point.x = randf_range(bounds.x_min + Global.GRID_SIZE, bounds.x_max - Global.GRID_SIZE)
	spawn_point.y = randf_range(bounds.y_min + Global.GRID_SIZE, bounds.y_max - Global.GRID_SIZE)
	
	spawn_point.x = floorf(spawn_point.x / Global.GRID_SIZE) * Global.GRID_SIZE
	spawn_point.y = floorf(spawn_point.y / Global.GRID_SIZE) * Global.GRID_SIZE
	
	var enemy = enemy_scene.instantiate()
	enemy.position = spawn_point
	
	get_parent().add_child(enemy)
	
func spawn_player(pos:Vector2):
	var player = player_scene.instantiate()
	player.position = pos
	get_parent().add_child(player)
