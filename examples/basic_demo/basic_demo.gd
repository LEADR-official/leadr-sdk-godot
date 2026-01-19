extends Node
## Basic LEADR SDK Demo
##
## This script demonstrates the core LEADR SDK functionality without any UI.
## Run this scene and check the Output panel for debug logs showing:
## - Fetching boards
## - Fetching a specific board by slug
## - Fetching top scores
## - Fetching scores "around" a specific value
## - Submitting a new score
##
## Setup:
## 1. Enable the LEADR plugin in Project Settings > Plugins
## 2. Create res://leadr_settings.tres with your game_id
## 3. Add the Leadr autoload (addons/leadr/autoload/leadr_autoload.gd)
## 4. Set board_slug below to one of your board slugs

## Change this to one of your board slugs from the LEADR dashboard.
@export var board_slug: String = "your-board-slug"

## Player name for the demo score submission.
@export var player_name: String = "DemoPlayer"

const LOG_PREFIX := "[BasicDemo]"


func _ready() -> void:
	_run_demo()


func _run_demo() -> void:
	_log("Starting LEADR SDK demo...")

	# Step 1: Check client is initialized
	if not Leadr.is_initialized():
		_log_error("Leadr client not initialized! Check your autoload setup.")
		return

	_log("Client initialized successfully")

	# Step 2: Fetch all boards
	_log("Fetching boards...")
	var boards_result := await Leadr.get_boards()

	if not boards_result.is_success:
		_log_error("Failed to fetch boards: %s" % boards_result.error.message)
		return

	var boards_page: LeadrPagedResult = boards_result.data
	var board_names: PackedStringArray = []
	for board: LeadrBoard in boards_page.items:
		board_names.append(board.name)

	_log("Found %d boards: %s" % [boards_page.count, ", ".join(board_names)])

	# Step 3: Fetch the configured board by slug
	_log("Fetching board: %s" % board_slug)
	var board_result := await Leadr.get_board(board_slug)

	if not board_result.is_success:
		_log_error("Failed to fetch board '%s': %s" % [board_slug, board_result.error.message])
		return

	var board: LeadrBoard = board_result.data
	_log("Board loaded: %s (id: %s, sort: %s)" % [board.name, board.id, board.sort_direction])

	# Step 4: Fetch top 10 scores
	_log("Fetching top 10 scores...")
	var scores_result := await Leadr.get_scores(board.id, 10)

	if not scores_result.is_success:
		_log_error("Failed to fetch scores: %s" % scores_result.error.message)
		return

	var scores_page: LeadrPagedResult = scores_result.data

	if scores_page.is_empty():
		_log("No scores found on this board yet")
	else:
		for score: LeadrScore in scores_page.items:
			_log("  #%d %s: %s" % [score.rank, score.player_name, score.get_display_value()])

	# Step 5: Generate a random score value
	var simulated_value := randi_range(1000, 10000)
	_log("Simulated score value: %d" % simulated_value)

	# Step 6: Fetch scores "around" that value to show context
	_log("Fetching scores around %d..." % simulated_value)
	var around_result := await Leadr.get_scores(board.id, 5, "", "", simulated_value)

	if not around_result.is_success:
		_log_error("Failed to fetch scores around value: %s" % around_result.error.message)
		return

	var around_page: LeadrPagedResult = around_result.data

	if around_page.is_empty():
		_log("No nearby scores found")
	else:
		_log("Scores around %d:" % simulated_value)
		for score: LeadrScore in around_page.items:
			_log("  #%d %s: %s" % [score.rank, score.player_name, score.get_display_value()])

	# Step 7: Submit the score
	_log("Submitting score: %d for %s..." % [simulated_value, player_name])
	var submit_result := await Leadr.submit_score(board.id, simulated_value, player_name)

	if not submit_result.is_success:
		_log_error("Failed to submit score: %s" % submit_result.error.message)
		return

	var submitted_score: LeadrScore = submit_result.data
	_log("Score submitted! Rank: #%d, ID: %s" % [submitted_score.rank, submitted_score.id])

	_log("Demo complete!")


func _log(message: String) -> void:
	print("%s %s" % [LOG_PREFIX, message])


func _log_error(message: String) -> void:
	push_error("%s %s" % [LOG_PREFIX, message])
