class_name LeadrHttpClient
extends RefCounted
## HTTP client wrapper for LEADR SDK.
##
## Manages HTTPRequest nodes and provides async request methods with logging.
## This is an internal class and should not be used directly.


## Response data from an HTTP request.
class Response:
	extends RefCounted

	var status_code: int = 0
	var body: String = ""
	var is_network_error: bool = false

	static func from_request(p_status_code: int, p_body: String) -> Response:
		var response := Response.new()
		response.status_code = p_status_code
		response.body = p_body
		return response

	static func network_error() -> Response:
		var response := Response.new()
		response.is_network_error = true
		return response


var _base_url: String
var _debug_logging: bool
var _parent_node: Node


func _init(base_url: String, debug_logging: bool, parent_node: Node) -> void:
	_base_url = base_url.rstrip("/")
	_debug_logging = debug_logging
	_parent_node = parent_node


## Performs an async GET request.
func get_async(endpoint: String, headers: Dictionary = {}) -> Response:
	return await _request(HTTPClient.METHOD_GET, endpoint, "", headers)


## Performs an async POST request with JSON body.
func post_async(endpoint: String, body: Dictionary, headers: Dictionary = {}) -> Response:
	var json_body := JSON.stringify(body)
	headers["Content-Type"] = "application/json"
	return await _request(HTTPClient.METHOD_POST, endpoint, json_body, headers)


## Performs an async PATCH request with JSON body.
func patch_async(endpoint: String, body: Dictionary, headers: Dictionary = {}) -> Response:
	var json_body := JSON.stringify(body)
	headers["Content-Type"] = "application/json"
	return await _request(HTTPClient.METHOD_PATCH, endpoint, json_body, headers)


func _request(method: int, endpoint: String, body: String, headers: Dictionary) -> Response:
	var http_request := HTTPRequest.new()
	_parent_node.add_child(http_request)

	var url := _build_url(endpoint)
	var header_array := _build_headers(headers)
	var method_name := _method_to_string(method)

	_log_request(method_name, url, body)
	var start_time := Time.get_ticks_msec()

	var error: int
	if body.is_empty():
		error = http_request.request(url, header_array, method)
	else:
		error = http_request.request(url, header_array, method, body)

	if error != OK:
		http_request.queue_free()
		_log_error("Request failed to start: %s" % error_string(error))
		return Response.network_error()

	# Wait for the request to complete
	var result: Array = await http_request.request_completed

	var elapsed := Time.get_ticks_msec() - start_time
	http_request.queue_free()

	var result_code: int = result[0]
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		_log_error("Request failed: %s" % _result_to_string(result_code))
		return Response.network_error()

	var body_string := response_body.get_string_from_utf8()
	_log_response(response_code, elapsed, body_string)

	return Response.from_request(response_code, body_string)


func _build_url(endpoint: String) -> String:
	# Handle endpoints that already have query params
	var clean_endpoint := endpoint.lstrip("/")
	return "%s/%s" % [_base_url, clean_endpoint]


func _build_headers(headers: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for key: String in headers:
		result.append("%s: %s" % [key, headers[key]])
	return result


func _method_to_string(method: int) -> String:
	match method:
		HTTPClient.METHOD_GET:
			return "GET"
		HTTPClient.METHOD_POST:
			return "POST"
		HTTPClient.METHOD_PATCH:
			return "PATCH"
		HTTPClient.METHOD_DELETE:
			return "DELETE"
		_:
			return "UNKNOWN"


func _result_to_string(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "SUCCESS"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "CHUNKED_BODY_SIZE_MISMATCH"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "CANT_CONNECT"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "CANT_RESOLVE"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "CONNECTION_ERROR"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS_HANDSHAKE_ERROR"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "NO_RESPONSE"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "BODY_SIZE_LIMIT_EXCEEDED"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "BODY_DECOMPRESS_FAILED"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "REQUEST_FAILED"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "DOWNLOAD_FILE_CANT_OPEN"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "DOWNLOAD_FILE_WRITE_ERROR"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "REDIRECT_LIMIT_REACHED"
		HTTPRequest.RESULT_TIMEOUT:
			return "TIMEOUT"
		_:
			return "UNKNOWN (%d)" % result


func _log_request(method: String, url: String, body: String) -> void:
	if not _debug_logging:
		return

	var redacted_body := _redact_sensitive(body)
	var redacted_url := _redact_sensitive(url)

	if body.is_empty():
		print("[LEADR] -> %s %s" % [method, redacted_url])
	else:
		print("[LEADR] -> %s %s" % [method, redacted_url])
		print("  Body: %s" % _truncate(redacted_body, 500))


func _log_response(status_code: int, elapsed_ms: int, body: String) -> void:
	if not _debug_logging:
		return

	var redacted_body := _redact_sensitive(body)
	print("[LEADR] <- %d (%dms)" % [status_code, elapsed_ms])
	if not body.is_empty():
		print("  Body: %s" % _truncate(redacted_body, 500))


func _log_error(message: String) -> void:
	if not _debug_logging:
		return
	print("[LEADR] ERROR: %s" % message)


func _redact_sensitive(text: String) -> String:
	# Redact tokens, fingerprints, and other sensitive data
	var patterns := [
		["access_token", '"access_token":\\s*"[^"]+"', '"access_token": "[REDACTED]"'],
		["refresh_token", '"refresh_token":\\s*"[^"]+"', '"refresh_token": "[REDACTED]"'],
		[
			"client_fingerprint",
			'"client_fingerprint":\\s*"[^"]+"',
			'"client_fingerprint": "[REDACTED]"'
		],
		[
			"Authorization",
			"Authorization:\\s*Bearer\\s+[^\\s]+",
			"Authorization: Bearer [REDACTED]"
		],
	]

	var result := text
	for pattern_data: Array in patterns:
		var regex := RegEx.new()
		regex.compile(pattern_data[1])
		result = regex.sub(result, pattern_data[2], true)

	return result


func _truncate(text: String, max_length: int) -> String:
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length) + "..."
