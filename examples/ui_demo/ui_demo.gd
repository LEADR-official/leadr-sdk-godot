extends Control
## UI Integration Demo
##
## This scene demonstrates how to use the LEADR UI components:
## - LeadrBoardView for displaying scores with pagination
## - LeadrScoreSubmitter for submitting new scores
##
## The board dropdown is dynamically populated from the API.
##
## Setup:
## 1. Enable the LEADR plugin in Project Settings > Plugins
## 2. Create res://leadr_settings.tres with your game_id
## 3. Add the Leadr autoload (addons/leadr/autoload/leadr_autoload.gd)

@onready var _board_dropdown: OptionButton = %BoardDropdown
@onready var _board_view: LeadrBoardView = %BoardView
@onready var _submitter: LeadrScoreSubmitter = %Submitter
@onready var _simulate_button: Button = %SimulateButton
@onready var _status_label: Label = %StatusLabel

var _boards: Array[LeadrBoard] = []


func _ready() -> void:
	# Connect signals
	_board_dropdown.item_selected.connect(_on_board_selected)
	_board_view.score_selected.connect(_on_score_selected)
	_board_view.error_occurred.connect(_on_error)
	_board_view.state_changed.connect(_on_board_view_state_changed)
	_submitter.score_submitted.connect(_on_score_submitted)
	_submitter.submission_failed.connect(_on_error)
	_simulate_button.pressed.connect(_on_simulate_pressed)

	# Load available boards
	_load_boards()


func _load_boards() -> void:
	_status_label.text = "Loading boards..."
	_board_dropdown.disabled = true

	if not Leadr.is_initialized():
		_status_label.text = "Error: Leadr not initialized"
		return

	var result := await Leadr.get_boards()

	if not result.is_success:
		_status_label.text = "Error: %s" % result.error.message
		return

	_boards.clear()
	_board_dropdown.clear()

	for board: LeadrBoard in result.data.items:
		_boards.append(board)
		_board_dropdown.add_item("%s (%s)" % [board.name, board.slug])

	_board_dropdown.disabled = false

	if _boards.is_empty():
		_status_label.text = "No boards found"
		return

	_status_label.text = "Select a board"

	# Auto-select first board
	_board_dropdown.select(0)
	_on_board_selected(0)


func _on_board_selected(index: int) -> void:
	if index < 0 or index >= _boards.size():
		return

	var board: LeadrBoard = _boards[index]

	# Update components with selected board
	_board_view.board = board.slug
	_submitter.board = board.slug

	# Load scores for the selected board
	_board_view.load_scores()
	_status_label.text = "Loading: %s" % board.name


func _on_board_view_state_changed(state: LeadrBoardView.State) -> void:
	match state:
		LeadrBoardView.State.LOADED:
			var board_name := (
				_boards[_board_dropdown.selected].name if _board_dropdown.selected >= 0 else "Board"
			)
			_status_label.text = "Loaded: %s" % board_name
		LeadrBoardView.State.EMPTY:
			_status_label.text = "No scores yet - be the first!"
		LeadrBoardView.State.ERROR:
			pass  # Error handler will update status


func _on_score_selected(score: LeadrScore) -> void:
	_status_label.text = (
		"Selected: #%d %s - %s" % [score.rank, score.player_name, score.get_display_value()]
	)


func _on_score_submitted(score: LeadrScore) -> void:
	_status_label.text = "Submitted! Rank: #%d" % score.rank

	# Refresh the board view to show the new score
	_board_view.refresh()

	# Highlight the submitted score after refresh
	await _board_view.page_loaded
	_board_view.highlight_score(score.id)


func _on_error(error: LeadrError) -> void:
	_status_label.text = "Error: %s" % error.message


func _on_simulate_pressed() -> void:
	var value := randi_range(1000, 10000)
	_submitter.set_score(value)
	_status_label.text = "Simulated score: %d" % value
