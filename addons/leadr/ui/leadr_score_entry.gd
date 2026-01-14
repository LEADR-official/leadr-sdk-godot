@tool
class_name LeadrScoreEntry
extends Control
## Displays a single score entry in a leaderboard.
##
## This component shows the rank, player name, score value, and timestamp.
## It can be selected and highlighted for the current player's score.

## Emitted when the entry is clicked.
signal clicked

## The score data to display.
var score: LeadrScore:
	set(value):
		score = value
		_update_display()

## Whether to show the rank column.
@export var show_rank: bool = true:
	set(value):
		show_rank = value
		if _rank_label:
			_rank_label.visible = value

## Whether to show the date column.
@export var show_date: bool = true:
	set(value):
		show_date = value
		if _date_label:
			_date_label.visible = value

## Whether this entry is currently selected.
var is_selected: bool = false:
	set(value):
		is_selected = value
		_update_style()

## Whether this entry is highlighted (e.g., current player's score).
var is_highlighted: bool = false:
	set(value):
		is_highlighted = value
		_update_style()

@onready var _container: HBoxContainer = $Container
@onready var _rank_label: Label = $Container/RankLabel
@onready var _name_label: Label = $Container/NameLabel
@onready var _value_label: Label = $Container/ValueLabel
@onready var _date_label: Label = $Container/DateLabel


func _ready() -> void:
	# Create UI structure if not in scene
	if not has_node("Container"):
		_create_ui()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_update_display()
	_update_style()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			clicked.emit()
			accept_event()


func _create_ui() -> void:
	custom_minimum_size = Vector2(0, 40)

	_container = HBoxContainer.new()
	_container.name = "Container"
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_container)

	# Rank label
	_rank_label = Label.new()
	_rank_label.name = "RankLabel"
	_rank_label.custom_minimum_size = Vector2(50, 0)
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(_rank_label)

	# Player name label
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_container.add_child(_name_label)

	# Value label
	_value_label = Label.new()
	_value_label.name = "ValueLabel"
	_value_label.custom_minimum_size = Vector2(100, 0)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_container.add_child(_value_label)

	# Date label
	_date_label = Label.new()
	_date_label.name = "DateLabel"
	_date_label.custom_minimum_size = Vector2(80, 0)
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_date_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_container.add_child(_date_label)


func _update_display() -> void:
	if not is_inside_tree():
		return

	if score == null:
		if _rank_label:
			_rank_label.text = ""
		if _name_label:
			_name_label.text = ""
		if _value_label:
			_value_label.text = ""
		if _date_label:
			_date_label.text = ""
		return

	if _rank_label:
		_rank_label.text = "#%d" % score.rank if score.rank > 0 else ""
		_rank_label.visible = show_rank

	if _name_label:
		_name_label.text = score.player_name

	if _value_label:
		_value_label.text = score.get_display_value()

	if _date_label:
		_date_label.text = score.get_relative_time()
		_date_label.visible = show_date


func _update_style() -> void:
	if not is_inside_tree():
		return

	# Apply different background colors based on state
	var bg_color := Color.TRANSPARENT

	if is_selected:
		bg_color = Color(0.3, 0.5, 0.8, 0.3)
	elif is_highlighted:
		bg_color = Color(0.8, 0.7, 0.2, 0.2)

	# Apply background via StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)


func _on_mouse_entered() -> void:
	if not is_selected:
		modulate = Color(1.1, 1.1, 1.1)


func _on_mouse_exited() -> void:
	modulate = Color.WHITE


## Sets the score data with a specific rank override.
func set_score(p_rank: int, p_score: LeadrScore) -> void:
	score = p_score
	if score and p_rank > 0:
		score.rank = p_rank
	_update_display()
