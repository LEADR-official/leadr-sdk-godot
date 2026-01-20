class_name LeadrScore
extends RefCounted
## Represents a score entry on a LEADR leaderboard.

## Unique score identifier (e.g., "scr_...").
var id: String = ""

## Account ID this score belongs to.
var account_id: String = ""

## Game ID this score belongs to.
var game_id: String = ""

## Board ID this score is on.
var board_id: String = ""

## Player's display name.
var player_name: String = ""

## Raw numeric score value.
var value: float = 0.0

## Formatted display string (e.g., "1:23.45" for time).
## If empty, use [member value] formatted as needed.
var value_display: String = ""

## Custom metadata attached to the score.
var metadata: Dictionary = {}

## 1-indexed rank on the leaderboard.
var rank: int = 0

## True if this is a placeholder score in "around" queries.
var is_placeholder: bool = false

## True if this score was submitted during a test session.
var is_test: bool = false

## When the score was created (ISO 8601).
var created_at: String = ""

## When the score was last updated (ISO 8601).
var updated_at: String = ""


## Safely gets a string value from a dictionary, returning default if null or missing.
static func _get_str(data: Dictionary, key: String, default: String = "") -> String:
	var val = data.get(key)
	return val if val != null else default


## Safely gets a dictionary value, returning empty dict if null or missing.
static func _get_dict(data: Dictionary, key: String) -> Dictionary:
	var val = data.get(key)
	return val if val != null else {}


## Creates a Score from an API response dictionary.
static func from_dict(data: Dictionary) -> LeadrScore:
	var score := LeadrScore.new()

	score.id = _get_str(data, "id")
	score.account_id = _get_str(data, "account_id")
	score.game_id = _get_str(data, "game_id")
	score.board_id = _get_str(data, "board_id")
	score.player_name = _get_str(data, "player_name")
	score.value = float(data.get("value", 0))
	score.value_display = _get_str(data, "value_display")
	score.metadata = _get_dict(data, "metadata")
	score.rank = int(data.get("rank", 0))
	score.is_placeholder = data.get("is_placeholder", false)
	score.is_test = data.get("is_test", false)
	score.created_at = _get_str(data, "created_at")
	score.updated_at = _get_str(data, "updated_at")

	return score


## Returns the display value, falling back to the raw value if not set.
func get_display_value() -> String:
	if not value_display.is_empty():
		return value_display
	# Format as integer if it's a whole number
	if value == floorf(value):
		return str(int(value))
	return str(value)


## Returns a relative time string (e.g., "5m ago", "2d ago").
func get_relative_time() -> String:
	if created_at.is_empty():
		return ""

	var created_unix := Time.get_unix_time_from_datetime_string(created_at)
	var now := Time.get_unix_time_from_system()
	var diff := int(now - created_unix)

	if diff < 60:
		return "Just now"
	if diff < 3600:
		return "%dm ago" % (diff / 60)
	if diff < 86400:
		return "%dh ago" % (diff / 3600)
	if diff < 604800:
		return "%dd ago" % (diff / 86400)
	if diff < 2592000:
		return "%dw ago" % (diff / 604800)
	return "%dmo ago" % (diff / 2592000)
