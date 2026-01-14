class_name LeadrError
extends RefCounted
## Error details for failed LEADR API operations.
##
## Contains the HTTP status code, an error code string, and a human-readable message.
## Use [method from_response] to parse API error responses.

## HTTP status code (0 for network errors).
var status_code: int = 0

## Error code string from the API (e.g., "validation_error", "not_found").
var code: String = ""

## Human-readable error message.
var message: String = ""


func _init(p_status_code: int = 0, p_code: String = "", p_message: String = "") -> void:
	status_code = p_status_code
	code = p_code
	message = p_message


func _to_string() -> String:
	return "[%d] %s: %s" % [status_code, code, message]


## Creates an error from an HTTP response.
## Attempts to parse JSON error format from the API.
static func from_response(p_status_code: int, body: String) -> LeadrError:
	if body.is_empty():
		return LeadrError.new(p_status_code, "unknown", "Unknown error (empty response)")

	var json := JSON.new()
	var parse_result := json.parse(body)
	if parse_result != OK:
		return LeadrError.new(p_status_code, "parse_error", body.substr(0, 200))

	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return LeadrError.new(p_status_code, "unknown", body.substr(0, 200))

	var data: Dictionary = parsed

	# Handle {"error": "message"} format
	if data.has("error") and data["error"] is String:
		return LeadrError.new(p_status_code, "api_error", data["error"])

	# Handle {"error": {"code": "...", "message": "..."}} format
	if data.has("error") and data["error"] is Dictionary:
		var err_dict: Dictionary = data["error"]
		var err_code: String = err_dict.get("code", "api_error")
		var err_msg: String = err_dict.get("message", "Unknown error")
		return LeadrError.new(p_status_code, err_code, err_msg)

	# Handle {"detail": "message"} format (FastAPI)
	if data.has("detail"):
		var detail: Variant = data["detail"]
		if detail is String:
			return LeadrError.new(p_status_code, "api_error", detail)
		if detail is Array and detail.size() > 0:
			var first: Variant = detail[0]
			if first is Dictionary:
				var msg: String = first.get("msg", "Validation error")
				return LeadrError.new(p_status_code, "validation_error", msg)

	# Handle {"message": "..."} format
	if data.has("message") and data["message"] is String:
		return LeadrError.new(p_status_code, "api_error", data["message"])

	return LeadrError.new(p_status_code, "unknown", body.substr(0, 200))


## Creates a network error (status code 0).
static func network_error(p_message: String = "Network error") -> LeadrError:
	return LeadrError.new(0, "network_error", p_message)
