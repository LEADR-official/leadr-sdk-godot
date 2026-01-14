@tool
class_name LeadrSettings
extends Resource
## Configuration resource for the LEADR SDK.
##
## Create a LeadrSettings resource in the editor (right-click in FileSystem >
## New Resource > LeadrSettings) and configure your game_id.
##
## You can either pass this resource to [method LeadrClient.initialize] or
## save it as "res://leadr_settings.tres" for automatic loading by the autoload.

## The unique identifier for your game from the LEADR dashboard.
## This is required and must be a valid UUID.
@export var game_id: String = ""

## The base URL for the LEADR API.
## Only change this for self-hosted instances or local development.
@export var base_url: String = "https://api.leadrcloud.com"

## Enable verbose logging for debugging.
## When enabled, HTTP requests and responses are logged to the console.
## Sensitive data (tokens, fingerprints) is always redacted.
@export var debug_logging: bool = false

## UUID regex pattern for validation.
const UUID_PATTERN := "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"


## Validates the settings and returns an error message if invalid.
## Returns an empty string if valid.
func validate() -> String:
	if game_id.is_empty():
		return "game_id is required"

	var uuid_regex := RegEx.new()
	uuid_regex.compile(UUID_PATTERN)
	if not uuid_regex.search(game_id):
		return "game_id must be a valid UUID"

	if base_url.is_empty():
		return "base_url is required"

	if not base_url.begins_with("https://") and not base_url.begins_with("http://"):
		return "base_url must start with http:// or https://"

	# Only allow HTTP for localhost
	if base_url.begins_with("http://") and not _is_localhost(base_url):
		return "base_url must use HTTPS (HTTP only allowed for localhost)"

	return ""


## Returns true if the settings are valid.
func is_valid() -> bool:
	return validate().is_empty()


func _is_localhost(url: String) -> bool:
	var lower := url.to_lower()
	return (
		lower.contains("://localhost")
		or lower.contains("://127.0.0.1")
		or lower.contains("://0.0.0.0")
	)
