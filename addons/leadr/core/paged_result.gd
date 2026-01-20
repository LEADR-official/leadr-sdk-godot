class_name LeadrPagedResult
extends RefCounted
## Cursor-based paginated result from LEADR API.
##
## Provides access to items and navigation methods for fetching additional pages.
##
## Example:
## [codeblock]
## var result := await Leadr.get_scores("brd_123", 10)
## if result.is_success:
##     var page: LeadrPagedResult = result.data
##     for score in page.items:
##         print(score.player_name)
##
##     if page.has_next:
##         var next_result := await page.next_page()
## [/codeblock]

## Array of items in this page.
var items: Array = []

## Number of items in this page.
var count: int = 0

## Whether there is a next page available.
var has_next: bool = false

## Whether there is a previous page available.
var has_prev: bool = false

## Internal cursor for next page.
var _next_cursor: String = ""

## Internal cursor for previous page.
var _prev_cursor: String = ""

## Internal function to fetch pages.
var _fetch_page: Callable


## Safely gets a string value from a dictionary, returning default if null or missing.
static func _get_str(data: Dictionary, key: String, default: String = "") -> String:
	var val = data.get(key)
	return val if val != null else default


## Creates a PagedResult from an API response.
## [param json] - The API response dictionary
## [param item_parser] - Callable that takes a Dictionary and returns the parsed item
## [param fetch_page] - Callable that takes a cursor string and returns LeadrResult
static func from_dict(
	json: Dictionary, item_parser: Callable, fetch_page: Callable
) -> LeadrPagedResult:
	var result := LeadrPagedResult.new()

	# Parse items from "data" array
	var data_array: Variant = json.get("data", [])
	if data_array is Array:
		for item_data: Variant in data_array:
			if item_data is Dictionary:
				var parsed: Variant = item_parser.call(item_data)
				if parsed != null:
					result.items.append(parsed)

	# Parse pagination metadata
	var pagination: Variant = json.get("pagination", {})
	if pagination is Dictionary:
		result.count = pagination.get("count", result.items.size())
		result.has_next = pagination.get("has_next", false)
		result.has_prev = pagination.get("has_prev", false)
		result._next_cursor = _get_str(pagination, "next_cursor")
		result._prev_cursor = _get_str(pagination, "prev_cursor")
	else:
		result.count = result.items.size()

	result._fetch_page = fetch_page

	return result


## Fetches the next page of results.
## Returns LeadrResult with LeadrPagedResult on success.
func next_page() -> LeadrResult:
	if not has_next:
		return LeadrResult.failure_from(0, "no_next_page", "No next page available")

	if _next_cursor.is_empty():
		return LeadrResult.failure_from(0, "no_cursor", "No next cursor available")

	if not _fetch_page.is_valid():
		return LeadrResult.failure_from(0, "fetch_unavailable", "Page fetch function not available")

	return await _fetch_page.call(_next_cursor)


## Fetches the previous page of results.
## Returns LeadrResult with LeadrPagedResult on success.
func prev_page() -> LeadrResult:
	if not has_prev:
		return LeadrResult.failure_from(0, "no_prev_page", "No previous page available")

	if _prev_cursor.is_empty():
		return LeadrResult.failure_from(0, "no_cursor", "No previous cursor available")

	if not _fetch_page.is_valid():
		return LeadrResult.failure_from(0, "fetch_unavailable", "Page fetch function not available")

	return await _fetch_page.call(_prev_cursor)


## Returns the first item, or null if empty.
func first() -> Variant:
	return items[0] if items.size() > 0 else null


## Returns the last item, or null if empty.
func last() -> Variant:
	return items[items.size() - 1] if items.size() > 0 else null


## Returns true if the page is empty.
func is_empty() -> bool:
	return items.size() == 0
