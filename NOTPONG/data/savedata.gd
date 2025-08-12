class_name SaveData extends Resource

@export var high_score: int = 0
@export var player_name: String = "Player1"
@export var previous_names: Array[String] = []
@export var player_id: String = ""
@export var first_launch: bool = true

const SAVE_PATH: String = "user://save_data.tres"

func save() -> void:
	ResourceSaver.save(self, SAVE_PATH)
	
static func load_or_create() -> SaveData:
	var res:SaveData
	if FileAccess.file_exists(SAVE_PATH):
		res = load(SAVE_PATH) as SaveData
	else:
		res = SaveData.new()
	
	# Generate unique player ID if doesn't exist
	if res.player_id == "":
		res.player_id = generate_unique_player_id()
		res.save()
		
	return res
	
func change_username(new_name: String) -> bool:
	"""Change username and handle leaderboard updates"""
	var old_name = player_name
	
	if new_name == old_name:
		return false  # No change needed
	
	# Add old name to history if it's not already there
	if old_name != "Player1" and old_name not in previous_names:
		previous_names.append(old_name)
	
	# Update current name
	player_name = new_name
	save()
	
	print("Username changed from '", old_name, "' to '", new_name, "'")
	return true

func get_all_names() -> Array[String]:
	"""Get all names this player has used"""
	var all_names: Array[String] = []
	
	# Add previous names
	for name in previous_names:
		if name not in all_names:
			all_names.append(name)
	
	# Add current name
	if player_name not in all_names:
		all_names.append(player_name)
	
	return all_names

func is_first_launch() -> bool:
	"""Check if this is the first time the player has launched the game"""
	return first_launch

func mark_as_launched():
	"""Mark that the player has launched the game"""
	first_launch = false
	save()
	
static func generate_unique_player_id() -> String:
	"""Generate a unique player identifier"""
	var timestamp = str(Time.get_unix_time_from_system())
	var random_suffix = str(randi_range(1000, 9999))
	return "player_" + timestamp + "_" + random_suffix
