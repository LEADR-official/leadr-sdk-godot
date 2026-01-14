@tool
class_name LeadrScoreSubmitter
extends Control
## Form component for submitting scores to a LEADR leaderboard.
##
## Provides player name input, optional score input, and submission handling.
##
## Example:
## [codeblock]
## var submitter = preload("res://addons/leadr/ui/leadr_score_submitter.tscn").instantiate()
## submitter.board = "my-leaderboard-slug"
## submitter.set_score(12345)  # Set score programmatically
## add_child(submitter)
##
## submitter.score_submitted.connect(func(score):
##     print("Submitted! Rank: #%d" % score.rank))
## [/codeblock]

## Current state of the submitter.
enum State { IDLE, SUBMITTING, SUCCESS, ERROR }

## Emitted when a score is successfully submitted.
signal score_submitted(score: LeadrScore)

## Emitted when submission fails.
signal submission_failed(error: LeadrError)

## Emitted when the state changes.
signal state_changed(new_state: State)

## Emitted when validation state changes.
signal validation_changed(is_valid: bool)

## Board slug to submit scores to.
@export var board: String = ""

## Minimum player name length.
@export_range(1, 50) var min_name_length: int = 1

## Maximum player name length.
@export_range(1, 50) var max_name_length: int = 20

## Whether to show the manual score input field.
## If false, use [method set_score] to set the score programmatically.
@export var show_score_input: bool = true:
	set(value):
		show_score_input = value
		if _score_input:
			_score_input.visible = value
			_score_label.visible = not value

## Whether to clear the form after successful submission.
@export var clear_on_success: bool = true

## Optional LeadrClient reference. If not set, uses the autoload singleton.
var client: LeadrClient

var _state: State = State.IDLE
var _score_value: int = 0
var _resolved_board: LeadrBoard
var _last_submitted_score: LeadrScore

@onready var _form: VBoxContainer = $Form
@onready var _score_label: Label = $Form/ScoreDisplay
@onready var _score_input: LineEdit = $Form/ScoreInput
@onready var _name_input: LineEdit = $Form/PlayerNameInput
@onready var _validation_label: Label = $Form/ValidationLabel
@onready var _submit_button: Button = $Form/SubmitButton
@onready var _feedback_container: VBoxContainer = $FeedbackContainer
@onready var _feedback_label: Label = $FeedbackContainer/FeedbackLabel


func _ready() -> void:
	# Create UI structure if not in scene
	if not has_node("Form"):
		_create_ui()

	_name_input.text_changed.connect(_on_name_changed)
	_submit_button.pressed.connect(_on_submit_pressed)

	if _score_input:
		_score_input.text_changed.connect(_on_score_input_changed)
		_score_input.visible = show_score_input

	if _score_label:
		_score_label.visible = not show_score_input

	_set_state(State.IDLE)
	_validate()


func _create_ui() -> void:
	_form = VBoxContainer.new()
	_form.name = "Form"
	add_child(_form)

	# Score display (for programmatic scores)
	_score_label = Label.new()
	_score_label.name = "ScoreDisplay"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 32)
	_score_label.visible = not show_score_input
	_form.add_child(_score_label)

	# Score input
	_score_input = LineEdit.new()
	_score_input.name = "ScoreInput"
	_score_input.placeholder_text = "Enter score..."
	_score_input.visible = show_score_input
	_score_input.text_changed.connect(_on_score_input_changed)
	_form.add_child(_score_input)

	# Player name input
	_name_input = LineEdit.new()
	_name_input.name = "PlayerNameInput"
	_name_input.placeholder_text = "Enter your name..."
	_name_input.max_length = max_name_length
	_name_input.text_changed.connect(_on_name_changed)
	_form.add_child(_name_input)

	# Validation label
	_validation_label = Label.new()
	_validation_label.name = "ValidationLabel"
	_validation_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	_form.add_child(_validation_label)

	# Submit button
	_submit_button = Button.new()
	_submit_button.name = "SubmitButton"
	_submit_button.text = "Submit Score"
	_submit_button.pressed.connect(_on_submit_pressed)
	_form.add_child(_submit_button)

	# Feedback container
	_feedback_container = VBoxContainer.new()
	_feedback_container.name = "FeedbackContainer"
	_feedback_container.visible = false
	add_child(_feedback_container)

	_feedback_label = Label.new()
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_container.add_child(_feedback_label)


## Sets the score value programmatically.
## Use this when the score is determined by the game (not user input).
func set_score(value: int) -> void:
	_score_value = value
	if _score_label:
		_score_label.text = str(value)
	_validate()


## Gets the current score value.
func get_score() -> int:
	return _score_value


## Sets the player name.
func set_player_name(player_name: String) -> void:
	if _name_input:
		_name_input.text = player_name
	_validate()


## Gets the current player name.
func get_player_name() -> String:
	return _name_input.text if _name_input else ""


## Returns the last successfully submitted score.
func get_last_submitted_score() -> LeadrScore:
	return _last_submitted_score


## Returns the current state.
func get_state() -> State:
	return _state


## Clears the form.
func clear_form() -> void:
	if _name_input:
		_name_input.text = ""
	if _score_input:
		_score_input.text = ""
	_score_value = 0
	if _score_label:
		_score_label.text = "0"
	_validate()


## Submits the score manually.
func submit() -> void:
	_on_submit_pressed()


func _set_state(new_state: State) -> void:
	if _state == new_state:
		return

	_state = new_state
	_update_visibility()
	state_changed.emit(new_state)


func _update_visibility() -> void:
	if _form:
		_form.visible = _state in [State.IDLE, State.ERROR]

	if _feedback_container:
		_feedback_container.visible = _state in [State.SUBMITTING, State.SUCCESS]

	if _submit_button:
		_submit_button.disabled = _state == State.SUBMITTING or not _is_valid()

	match _state:
		State.SUBMITTING:
			if _feedback_label:
				_feedback_label.text = "Submitting..."
		State.SUCCESS:
			if _feedback_label and _last_submitted_score:
				_feedback_label.text = "Score submitted! Rank: #%d" % _last_submitted_score.rank


func _validate() -> bool:
	var validation_error := _get_validation_error()

	if _validation_label:
		_validation_label.text = validation_error
		_validation_label.visible = not validation_error.is_empty()

	var is_valid := validation_error.is_empty()
	validation_changed.emit(is_valid)

	if _submit_button:
		_submit_button.disabled = not is_valid

	return is_valid


func _is_valid() -> bool:
	return _get_validation_error().is_empty()


func _get_validation_error() -> String:
	if board.is_empty():
		return "Board not configured"

	var player_name := get_player_name().strip_edges()
	if player_name.length() < min_name_length:
		return "Name must be at least %d character(s)" % min_name_length
	if player_name.length() > max_name_length:
		return "Name must be at most %d characters" % max_name_length

	var score := _get_score_value()
	if score < 0:
		return "Score must be a positive number"

	return ""


func _get_score_value() -> int:
	if show_score_input and _score_input:
		var text := _score_input.text.strip_edges()
		if text.is_valid_int():
			return text.to_int()
		return -1
	return _score_value


func _get_client() -> LeadrClient:
	if client != null:
		return client

	# Try to get from autoload
	if Engine.has_singleton("Leadr"):
		return Engine.get_singleton("Leadr") as LeadrClient

	# Try to find in scene tree
	var leadr := get_node_or_null("/root/Leadr")
	if leadr is LeadrClient:
		return leadr

	return null


func _on_name_changed(_new_text: String) -> void:
	_validate()


func _on_score_input_changed(_new_text: String) -> void:
	_validate()


func _on_submit_pressed() -> void:
	if not _validate():
		return

	_set_state(State.SUBMITTING)

	var leadr := _get_client()
	if leadr == null:
		_show_error("LEADR client not available")
		return

	# Resolve board if needed
	if _resolved_board == null or _resolved_board.slug != board:
		var board_result := await leadr.get_board(board)
		if not board_result.is_success:
			_show_error(board_result.error.message)
			submission_failed.emit(board_result.error)
			return
		_resolved_board = board_result.data

	# Submit score
	var score_value := _get_score_value()
	var player_name := get_player_name().strip_edges()

	var result := await leadr.submit_score(_resolved_board.id, score_value, player_name)

	if result.is_success:
		_last_submitted_score = result.data
		_set_state(State.SUCCESS)
		score_submitted.emit(_last_submitted_score)

		if clear_on_success:
			# Return to idle after a brief delay
			await get_tree().create_timer(2.0).timeout
			clear_form()
			_set_state(State.IDLE)
	else:
		_show_error(result.error.message)
		submission_failed.emit(result.error)


func _show_error(message: String) -> void:
	if _validation_label:
		_validation_label.text = message
		_validation_label.visible = true
	_set_state(State.ERROR)
