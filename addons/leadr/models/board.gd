class_name LeadrBoard
extends RefCounted
## Represents a LEADR leaderboard.
##
## Boards define how scores are sorted, displayed, and retained.

## Unique board identifier (e.g., "brd_...").
var id: String = ""

## Account ID this board belongs to.
var account_id: String = ""

## Game ID this board belongs to.
var game_id: String = ""

## Display name of the board.
var name: String = ""

## URL-safe identifier for the board.
var slug: String = ""

## Short sharing code (e.g., "ABC123").
var short_code: String = ""

## Icon URL for the board.
var icon: String = ""

## Unit label for scores (e.g., "points", "seconds").
var unit: String = ""

## Whether the board is active.
var is_active: bool = true

## Whether the board is published and visible.
var is_published: bool = true

## Sort direction: "ascending" or "descending".
var sort_direction: String = "descending"

## Score retention strategy: "all", "highest", or "latest".
var keep_strategy: String = "all"

## Tags for categorizing the board.
var tags: PackedStringArray = PackedStringArray()

## Optional description of the board.
var description: String = ""

## Season start timestamp (ISO 8601), or empty if no season.
var starts_at: String = ""

## Season end timestamp (ISO 8601), or empty if no season.
var ends_at: String = ""

## When the board was created (ISO 8601).
var created_at: String = ""

## When the board was last updated (ISO 8601).
var updated_at: String = ""


## Safely gets a string value from a dictionary, returning default if null or missing.
static func _get_str(data: Dictionary, key: String, default: String = "") -> String:
	var val = data.get(key)
	return val if val != null else default


## Creates a Board from an API response dictionary.
static func from_dict(data: Dictionary) -> LeadrBoard:
	var board := LeadrBoard.new()

	board.id = _get_str(data, "id")
	board.account_id = _get_str(data, "account_id")
	board.game_id = _get_str(data, "game_id")
	board.name = _get_str(data, "name")
	board.slug = _get_str(data, "slug")
	board.short_code = _get_str(data, "short_code")
	board.icon = _get_str(data, "icon")
	board.unit = _get_str(data, "unit")
	board.is_active = data.get("is_active", true)
	board.is_published = data.get("is_published", true)
	board.sort_direction = _get_str(data, "sort_direction", "descending")
	board.keep_strategy = _get_str(data, "keep_strategy", "all")
	board.description = _get_str(data, "description")
	board.starts_at = _get_str(data, "starts_at")
	board.ends_at = _get_str(data, "ends_at")
	board.created_at = _get_str(data, "created_at")
	board.updated_at = _get_str(data, "updated_at")

	# Parse tags array
	var tags_data: Variant = data.get("tags", [])
	if tags_data is Array:
		for tag: Variant in tags_data:
			if tag is String:
				board.tags.append(tag)

	return board


## Returns true if the board is currently in season (or has no season restrictions).
func is_in_season() -> bool:
	if starts_at.is_empty() and ends_at.is_empty():
		return true

	var now := Time.get_unix_time_from_system()

	if not starts_at.is_empty():
		var start_unix := Time.get_unix_time_from_datetime_string(starts_at)
		if now < start_unix:
			return false

	if not ends_at.is_empty():
		var end_unix := Time.get_unix_time_from_datetime_string(ends_at)
		if now > end_unix:
			return false

	return true
