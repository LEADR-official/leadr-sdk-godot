class_name LeadrPlayerNameCheckResult
extends RefCounted
## Result of checking player name availability.
##
## Used to check if a player name is available before gameplay begins
## on boards with unique_player_names enabled.

## The original name that was submitted for checking.
var name: String = ""

## The normalised name (lowercase, whitespace collapsed).
var normalised_name: String = ""

## Whether the name is available on all checked boards.
var available: bool = false

## List of boards where this name conflicts with an existing player.
var conflicts: Array[LeadrPlayerNameConflict] = []


## Creates a PlayerNameCheckResult from an API response dictionary.
static func from_dict(data: Dictionary) -> LeadrPlayerNameCheckResult:
	var result := LeadrPlayerNameCheckResult.new()

	result.name = data.get("name", "")
	result.normalised_name = data.get("normalised_name", "")
	result.available = data.get("available", false)

	var conflicts_data: Variant = data.get("conflicts", [])
	if conflicts_data is Array:
		for conflict: Variant in conflicts_data:
			if conflict is Dictionary:
				result.conflicts.append(LeadrPlayerNameConflict.from_dict(conflict))

	return result


## Represents a board where a player name conflicts.
class LeadrPlayerNameConflict:
	extends RefCounted

	## The ID of the board with the conflict.
	var board_id: String = ""

	## The name of the board with the conflict.
	var board_name: String = ""

	## Creates a PlayerNameConflict from a dictionary.
	static func from_dict(data: Dictionary) -> LeadrPlayerNameConflict:
		var c := LeadrPlayerNameConflict.new()
		c.board_id = data.get("board_id", "")
		c.board_name = data.get("board_name", "")
		return c
