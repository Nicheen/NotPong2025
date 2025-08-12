# Smart Score Manager - Add this as a new autoload script
# Create this as an autoload: SmartScoreManager

extends Node

# Track the last submitted score details
var last_submitted_score: int = 0
var last_submitted_name: String = ""

func submit_score_smartly(current_score: int) -> Dictionary:
	"""
	Submit score with smart username management.
	This handles username changes by updating existing entries instead of creating duplicates.
	"""
	if not Global.save_data or not Global.save_data.player_name:
		return {"success": false, "message": "No username set"}
	
	var current_name = Global.save_data.player_name
	var player_id = Global.save_data.player_id
	var all_previous_names = Global.save_data.get_all_names()
	
	print("Submitting score for: ", current_name)
	print("Player ID: ", player_id)
	print("All previous names: ", all_previous_names)
	
	# Check if we need to clean up old entries first
	if current_name != last_submitted_name and last_submitted_name != "":
		await cleanup_old_entries(all_previous_names, current_name)
	
	# Submit the new score
	var result = await submit_score_with_cleanup(current_name, current_score, player_id)
	
	# Update tracking
	if result.success:
		last_submitted_score = current_score
		last_submitted_name = current_name
	
	return result

func cleanup_old_entries(all_names: Array[String], current_name: String):
	"""Remove old leaderboard entries for previous usernames"""
	print("Cleaning up old leaderboard entries...")

	# Get current leaderboard
	var sw_result = await SilentWolf.Scores.get_scores().sw_get_scores_complete
	
	if not sw_result or not sw_result.has("scores"):
		print("Could not fetch leaderboard for cleanup")
		return
	
	var scores_to_remove = []
	
	# Find entries that match our old names
	for entry in sw_result.scores:
		var entry_name = entry.player_name
		
		# If this is one of our old names (but not current name), mark for removal
		if entry_name in all_names and entry_name != current_name:
			scores_to_remove.append(entry)
			print("Marking old entry for removal: ", entry_name, " - ", entry.score)
	
	# Remove old entries
	for entry in scores_to_remove:
		await remove_score_entry(entry)
		await get_tree().create_timer(0.2).timeout  # Small delay to prevent rate limiting
	
	if scores_to_remove.size() > 0:
		print("Cleaned up ", scores_to_remove.size(), " old entries")


func remove_score_entry(entry):
	"""Remove a specific score entry from the leaderboard"""
	# SilentWolf doesn't have a direct "remove by entry" method
	# We'll need to use the score_id if available, or skip this step
	if entry.has("score_id"):
		# This would be the ideal way, but SilentWolf API might not support this
		print("Would remove entry with ID: ", entry.score_id)
	else:
		print("Cannot remove entry - no score_id available")


func submit_score_with_cleanup(player_name: String, score: int, player_id: String) -> Dictionary:
	"""Submit score with additional metadata for tracking"""

	# Submit the score normally
	var result = await SilentWolf.Scores.save_score(player_name, score)
	
	if result:
		print("Score submitted successfully: ", player_name, " - ", score)
		return {"success": true, "message": "Score submitted!"}
	else:
		print("Score submission failed")
		return {"success": false, "message": "Failed to submit score"}

func get_player_best_score(all_names: Array[String]) -> int:
	"""Get the best score across all usernames for this player"""

	var sw_result = await SilentWolf.Scores.get_scores().sw_get_scores_complete
	
	if not sw_result or not sw_result.has("scores"):
		return 0
	
	var best_score = 0
	
	for entry in sw_result.scores:
		var entry_name = entry.player_name
		if entry_name in all_names:
			best_score = max(best_score, entry.score)
	
	return best_score


func handle_username_change(old_name: String, new_name: String):
	"""Handle username change by updating leaderboard entries"""
	print("Handling username change: ", old_name, " -> ", new_name)
	
	# Save the change in our save data
	Global.save_data.change_username(new_name)
	
	# The next score submission will handle cleanup
	print("Username change registered. Next score will update leaderboard.")

# Enhanced score submission for the main game
func submit_game_score(score: int) -> Dictionary:
	"""
	Main function to call from your game when submitting scores
	This handles all the smart username management
	"""
	print("=== SMART SCORE SUBMISSION ===")
	print("Score: ", score)
	
	# Only submit if score is worth submitting
	if score <= 0:
		return {"success": false, "message": "Score too low"}
	
	# Check if it's a personal best
	var all_names = Global.save_data.get_all_names()
	var previous_best = await get_player_best_score(all_names)
	
	print("Previous best across all names: ", previous_best)
	
	if score <= previous_best:
		print("Score not better than previous best, not submitting to global leaderboard")
		return {"success": false, "message": "Not a personal best"}
	
	# Submit the score
	var result = await submit_score_smartly(score)
	
	print("Submission result: ", result)
	return result
