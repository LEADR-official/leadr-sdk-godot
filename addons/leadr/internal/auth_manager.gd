class_name LeadrAuthManager
extends RefCounted
## Manages authentication, token lifecycle, and nonces for LEADR SDK.
##
## This is an internal class and should not be used directly.
## It handles:
## - Automatic session creation on first authenticated request
## - Token refresh when expiring within 2 minutes
## - Automatic 401 retry after token refresh
## - Automatic nonce acquisition for mutations
## - Automatic 412 retry with fresh nonce

## Emitted when a session is started or refreshed.
signal session_changed(session: LeadrSession)

## Emitted when authentication fails.
signal auth_error(error: LeadrError)

## Token refresh threshold in seconds.
const REFRESH_THRESHOLD := 120

var _http_client: LeadrHttpClient
var _game_id: String
var _debug_logging: bool
var _is_refreshing: bool = false
var _refresh_waiters: Array[Callable] = []


func _init(http_client: LeadrHttpClient, game_id: String, debug_logging: bool) -> void:
	_http_client = http_client
	_game_id = game_id
	_debug_logging = debug_logging


## Starts a new session with the LEADR API.
## Returns LeadrResult with LeadrSession on success.
func start_session() -> LeadrResult:
	var fingerprint := LeadrFingerprint.get_or_generate()
	var platform := OS.get_name()

	var body := {
		"game_id": _game_id,
		"client_fingerprint": fingerprint,
		"platform": platform,
	}

	var response := await _http_client.post_async("v1/client/sessions", body)

	if response.is_network_error:
		return LeadrResult.failure(LeadrError.network_error())

	if response.status_code < 200 or response.status_code >= 300:
		return LeadrResult.failure(LeadrError.from_response(response.status_code, response.body))

	var json := JSON.new()
	if json.parse(response.body) != OK:
		return LeadrResult.failure_from(0, "parse_error", "Failed to parse session response")

	var data: Variant = json.data
	if not data is Dictionary:
		return LeadrResult.failure_from(0, "parse_error", "Invalid session response format")

	var session := LeadrSession.from_dict(data)

	# Store tokens
	LeadrTokenStorage.save_tokens(session.access_token, session.refresh_token, session.expires_in)

	session_changed.emit(session)
	return LeadrResult.success(session)


## Refreshes the access token using the stored refresh token.
## Returns LeadrResult with LeadrSession on success.
func refresh_token() -> LeadrResult:
	# If already refreshing, wait for it to complete
	if _is_refreshing:
		return await _wait_for_refresh()

	_is_refreshing = true

	var refresh_token := LeadrTokenStorage.get_refresh_token()
	if refresh_token.is_empty():
		_is_refreshing = false
		_notify_waiters(
			LeadrResult.failure_from(401, "no_refresh_token", "No refresh token available")
		)
		return LeadrResult.failure_from(401, "no_refresh_token", "No refresh token available")

	var headers := {"Authorization": "Bearer %s" % refresh_token}
	var response := await _http_client.post_async("v1/client/sessions/refresh", {}, headers)

	if response.is_network_error:
		_is_refreshing = false
		var result := LeadrResult.failure(LeadrError.network_error())
		_notify_waiters(result)
		return result

	if response.status_code < 200 or response.status_code >= 300:
		# Refresh failed - clear tokens and require new session
		LeadrTokenStorage.clear_tokens()
		_is_refreshing = false
		var result := LeadrResult.failure(
			LeadrError.from_response(response.status_code, response.body)
		)
		_notify_waiters(result)
		return result

	var json := JSON.new()
	if json.parse(response.body) != OK:
		_is_refreshing = false
		var result := LeadrResult.failure_from(0, "parse_error", "Failed to parse refresh response")
		_notify_waiters(result)
		return result

	var data: Variant = json.data
	if not data is Dictionary:
		_is_refreshing = false
		var result := LeadrResult.failure_from(0, "parse_error", "Invalid refresh response format")
		_notify_waiters(result)
		return result

	var session := LeadrSession.from_dict(data)

	# Store new tokens
	LeadrTokenStorage.save_tokens(session.access_token, session.refresh_token, session.expires_in)

	_is_refreshing = false
	session_changed.emit(session)

	var result := LeadrResult.success(session)
	_notify_waiters(result)
	return result


## Gets a fresh nonce for mutation requests.
## Returns the nonce string on success, empty string on failure.
func get_nonce() -> String:
	var access_token := LeadrTokenStorage.get_access_token()
	if access_token.is_empty():
		return ""

	var headers := {"Authorization": "Bearer %s" % access_token}
	var response := await _http_client.get_async("v1/client/nonce", headers)

	if response.is_network_error or response.status_code != 200:
		return ""

	var json := JSON.new()
	if json.parse(response.body) != OK:
		return ""

	var data: Variant = json.data
	if not data is Dictionary:
		return ""

	return data.get("nonce", "")


## Executes an authenticated request with automatic session/token management.
## [param request_fn] - Callable that takes headers Dictionary and returns Response
## [param parse_fn] - Callable that takes response body Dictionary and returns the result data
## [param requires_nonce] - Whether this request requires a nonce (mutations)
func execute_authenticated(
	request_fn: Callable, parse_fn: Callable, requires_nonce: bool = false
) -> LeadrResult:
	# Ensure we have a valid session
	if not LeadrTokenStorage.has_token():
		var session_result := await start_session()
		if not session_result.is_success:
			return session_result

	# Refresh if needed
	if LeadrTokenStorage.is_token_expiring_soon(REFRESH_THRESHOLD):
		var refresh_result := await refresh_token()
		if not refresh_result.is_success:
			# Try starting a new session
			var session_result := await start_session()
			if not session_result.is_success:
				return session_result

	# Build headers
	var access_token := LeadrTokenStorage.get_access_token()
	var headers := {"Authorization": "Bearer %s" % access_token}

	# Get nonce if required
	var nonce := ""
	if requires_nonce:
		nonce = await get_nonce()
		if nonce.is_empty():
			return LeadrResult.failure_from(0, "nonce_error", "Failed to get nonce")
		headers["leadr-client-nonce"] = nonce

	# Execute the request
	var response: LeadrHttpClient.Response = await request_fn.call(headers)

	if response.is_network_error:
		return LeadrResult.failure(LeadrError.network_error())

	# Handle 401 - refresh and retry once
	if response.status_code == 401:
		var refresh_result := await refresh_token()
		if not refresh_result.is_success:
			# Try new session
			var session_result := await start_session()
			if not session_result.is_success:
				auth_error.emit(session_result.error)
				return session_result

		# Retry with new token
		access_token = LeadrTokenStorage.get_access_token()
		headers["Authorization"] = "Bearer %s" % access_token

		if requires_nonce:
			nonce = await get_nonce()
			if nonce.is_empty():
				return LeadrResult.failure_from(
					0, "nonce_error", "Failed to get nonce after refresh"
				)
			headers["leadr-client-nonce"] = nonce

		response = await request_fn.call(headers)

		if response.is_network_error:
			return LeadrResult.failure(LeadrError.network_error())

	# Handle 412 (nonce invalid) - get fresh nonce and retry
	if response.status_code == 412 and requires_nonce:
		nonce = await get_nonce()
		if nonce.is_empty():
			return LeadrResult.failure_from(412, "nonce_error", "Failed to get fresh nonce")
		headers["leadr-client-nonce"] = nonce

		response = await request_fn.call(headers)

		if response.is_network_error:
			return LeadrResult.failure(LeadrError.network_error())

	# Check for error status codes
	if response.status_code < 200 or response.status_code >= 300:
		return LeadrResult.failure(LeadrError.from_response(response.status_code, response.body))

	# Parse response
	var json := JSON.new()
	if json.parse(response.body) != OK:
		return LeadrResult.failure_from(0, "parse_error", "Failed to parse response")

	var data: Variant = json.data
	if not data is Dictionary:
		return LeadrResult.failure_from(0, "parse_error", "Invalid response format")

	# Call the parser function
	var result: Variant = parse_fn.call(data)
	return LeadrResult.success(result)


func _wait_for_refresh() -> LeadrResult:
	# Create a signal to wait for
	var waiter_id := _refresh_waiters.size()
	var result_holder := {"result": null}

	var callback := func(result: LeadrResult): result_holder["result"] = result

	_refresh_waiters.append(callback)

	# Wait until we get a result
	while result_holder["result"] == null:
		await Engine.get_main_loop().process_frame

	return result_holder["result"]


func _notify_waiters(result: LeadrResult) -> void:
	var waiters := _refresh_waiters.duplicate()
	_refresh_waiters.clear()

	for callback: Callable in waiters:
		callback.call(result)
