@tool
class_name LeadrBoardView
extends Control
## Displays a complete leaderboard with pagination.
##
## This component handles loading scores, displaying them in a list,
## and navigating between pages.
##
## Example:
## [codeblock]
## var board_view = preload("res://addons/leadr/ui/leadr_board_view.tscn").instantiate()
## board_view.board = "my-leaderboard-slug"
## board_view.auto_load = true
## add_child(board_view)
## [/codeblock]

## Current state of the board view.
enum State { IDLE, LOADING, LOADED, EMPTY, ERROR }

## Emitted when a score entry is selected.
signal score_selected(score: LeadrScore)

## Emitted when the state changes.
signal state_changed(new_state: State)

## Emitted when an error occurs.
signal error_occurred(error: LeadrError)

## Emitted when a page is loaded.
signal page_loaded(page: LeadrPagedResult)

## Board slug to display. Set this before calling [method load_scores].
@export var board: String = ""

## Number of scores to show per page.
@export_range(1, 100) var scores_per_page: int = 10

## Whether to automatically load scores when added to the scene tree.
@export var auto_load: bool = false

## Whether to show pagination controls.
@export var show_pagination: bool = true

## Optional title override. If empty, uses the board name.
@export var title: String = ""

## Optional LeadrClient reference. If not set, uses the autoload singleton.
var client: LeadrClient

var _state: State = State.IDLE
var _current_page: LeadrPagedResult
var _current_page_number: int = 1
var _resolved_board: LeadrBoard
var _score_entries: Array[LeadrScoreEntry] = []
var _selected_score: LeadrScore

@onready var _title_label: Label = $VBoxContainer/Header/TitleLabel
@onready var _list_container: VBoxContainer = $VBoxContainer/ScrollContainer/ListContainer
@onready var _loading_container: CenterContainer = $VBoxContainer/LoadingContainer
@onready var _error_container: VBoxContainer = $VBoxContainer/ErrorContainer
@onready var _error_label: Label = $VBoxContainer/ErrorContainer/ErrorLabel
@onready var _empty_container: CenterContainer = $VBoxContainer/EmptyContainer
@onready var _pagination: HBoxContainer = $VBoxContainer/Footer/Pagination
@onready var _prev_button: Button = $VBoxContainer/Footer/Pagination/PrevButton
@onready var _page_info: Label = $VBoxContainer/Footer/Pagination/PageInfo
@onready var _next_button: Button = $VBoxContainer/Footer/Pagination/NextButton


func _ready() -> void:
	# Create UI structure if not in scene
	if not has_node("VBoxContainer"):
		_create_ui()

	_prev_button.pressed.connect(_on_prev_pressed)
	_next_button.pressed.connect(_on_next_pressed)

	if has_node("VBoxContainer/ErrorContainer/RetryButton"):
		$VBoxContainer/ErrorContainer/RetryButton.pressed.connect(_on_retry_pressed)

	_set_state(State.IDLE)

	if auto_load and not board.is_empty():
		load_scores()


func _create_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	header.name = "Header"
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 24)
	header.add_child(_title_label)

	# Scroll container
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.name = "ListContainer"
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_container)

	# Loading container
	_loading_container = CenterContainer.new()
	_loading_container.name = "LoadingContainer"
	_loading_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_loading_container.visible = false
	vbox.add_child(_loading_container)

	var loading_label := Label.new()
	loading_label.text = "Loading..."
	_loading_container.add_child(loading_label)

	# Error container
	_error_container = VBoxContainer.new()
	_error_container.name = "ErrorContainer"
	_error_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_error_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_error_container.visible = false
	vbox.add_child(_error_container)

	_error_label = Label.new()
	_error_label.name = "ErrorLabel"
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_container.add_child(_error_label)

	var retry_button := Button.new()
	retry_button.name = "RetryButton"
	retry_button.text = "Retry"
	retry_button.pressed.connect(_on_retry_pressed)
	_error_container.add_child(retry_button)

	# Empty container
	_empty_container = CenterContainer.new()
	_empty_container.name = "EmptyContainer"
	_empty_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_container.visible = false
	vbox.add_child(_empty_container)

	var empty_label := Label.new()
	empty_label.text = "No scores yet"
	_empty_container.add_child(empty_label)

	# Footer
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(footer)

	_pagination = HBoxContainer.new()
	_pagination.name = "Pagination"
	footer.add_child(_pagination)

	_prev_button = Button.new()
	_prev_button.name = "PrevButton"
	_prev_button.text = "< Previous"
	_prev_button.pressed.connect(_on_prev_pressed)
	_pagination.add_child(_prev_button)

	_page_info = Label.new()
	_page_info.name = "PageInfo"
	_page_info.custom_minimum_size = Vector2(100, 0)
	_page_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pagination.add_child(_page_info)

	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.text = "Next >"
	_next_button.pressed.connect(_on_next_pressed)
	_pagination.add_child(_next_button)


## Loads scores from the configured board.
func load_scores() -> void:
	if board.is_empty():
		_show_error("Board not configured")
		return

	_set_state(State.LOADING)
	_current_page_number = 1

	var leadr := _get_client()
	if leadr == null:
		_show_error("LEADR client not available")
		return

	# First, resolve the board slug
	var board_result := await leadr.get_board(board)
	if not board_result.is_success:
		_show_error(board_result.error.message)
		error_occurred.emit(board_result.error)
		return

	_resolved_board = board_result.data

	# Update title
	if title.is_empty():
		_title_label.text = _resolved_board.name
	else:
		_title_label.text = title

	# Fetch scores
	var scores_result := await leadr.get_scores(_resolved_board.id, scores_per_page)

	if scores_result.is_success:
		_current_page = scores_result.data
		_display_scores()

		if _current_page.is_empty():
			_set_state(State.EMPTY)
		else:
			_set_state(State.LOADED)

		page_loaded.emit(_current_page)
	else:
		_show_error(scores_result.error.message)
		error_occurred.emit(scores_result.error)


## Refreshes the current page of scores.
func refresh() -> void:
	load_scores()


## Clears the displayed scores.
func clear() -> void:
	_clear_entries()
	_current_page = null
	_resolved_board = null
	_set_state(State.IDLE)


## Returns the currently selected score, or null if none.
func get_selected_score() -> LeadrScore:
	return _selected_score


## Highlights a specific score (e.g., current player's score).
func highlight_score(score_id: String) -> void:
	for entry: LeadrScoreEntry in _score_entries:
		entry.is_highlighted = entry.score != null and entry.score.id == score_id


## Returns the current state.
func get_state() -> State:
	return _state


func _set_state(new_state: State) -> void:
	if _state == new_state:
		return

	_state = new_state
	_update_visibility()
	state_changed.emit(new_state)


func _update_visibility() -> void:
	var scroll := get_node_or_null("VBoxContainer/ScrollContainer")
	if scroll:
		scroll.visible = _state in [State.IDLE, State.LOADED]

	if _loading_container:
		_loading_container.visible = _state == State.LOADING

	if _error_container:
		_error_container.visible = _state == State.ERROR

	if _empty_container:
		_empty_container.visible = _state == State.EMPTY

	_update_pagination()


func _update_pagination() -> void:
	if not _pagination:
		return

	_pagination.visible = show_pagination and _state == State.LOADED and _current_page != null

	if _current_page:
		_prev_button.disabled = not _current_page.has_prev
		_next_button.disabled = not _current_page.has_next
		_page_info.text = "Page %d" % _current_page_number


func _display_scores() -> void:
	_clear_entries()

	if _current_page == null:
		return

	var entry_scene := preload("res://addons/leadr/ui/leadr_score_entry.tscn")

	for score: LeadrScore in _current_page.items:
		var entry: LeadrScoreEntry = entry_scene.instantiate()
		entry.score = score
		entry.clicked.connect(_on_entry_clicked.bind(entry))
		_list_container.add_child(entry)
		_score_entries.append(entry)


func _clear_entries() -> void:
	for entry: LeadrScoreEntry in _score_entries:
		entry.queue_free()
	_score_entries.clear()
	_selected_score = null


func _show_error(message: String) -> void:
	if _error_label:
		_error_label.text = message
	_set_state(State.ERROR)


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


func _on_entry_clicked(entry: LeadrScoreEntry) -> void:
	# Deselect previous
	for e: LeadrScoreEntry in _score_entries:
		e.is_selected = false

	# Select clicked entry
	entry.is_selected = true
	_selected_score = entry.score
	score_selected.emit(entry.score)


func _on_prev_pressed() -> void:
	if _current_page == null or not _current_page.has_prev:
		return

	_set_state(State.LOADING)

	var result := await _current_page.prev_page()

	if result.is_success:
		_current_page = result.data
		_current_page_number -= 1
		_display_scores()
		_set_state(State.LOADED)
		page_loaded.emit(_current_page)
	else:
		_show_error(result.error.message)
		error_occurred.emit(result.error)


func _on_next_pressed() -> void:
	if _current_page == null or not _current_page.has_next:
		return

	_set_state(State.LOADING)

	var result := await _current_page.next_page()

	if result.is_success:
		_current_page = result.data
		_current_page_number += 1
		_display_scores()
		_set_state(State.LOADED)
		page_loaded.emit(_current_page)
	else:
		_show_error(result.error.message)
		error_occurred.emit(result.error)


func _on_retry_pressed() -> void:
	load_scores()
