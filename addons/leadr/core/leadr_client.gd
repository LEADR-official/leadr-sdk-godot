class_name LeadrClient
extends Node
## Main client for the LEADR leaderboard API.
##
## This is the primary entry point for interacting with LEADR.
## Add this as an autoload singleton and call [method initialize] with your settings.
##
## Example:
## [codeblock]
## # In your game's _ready() or autoload
## Leadr.initialize_with_game_id("your-game-uuid")
##
## # Later, in your game code
## var result := await Leadr.get_scores("my-leaderboard", 10)
## if result.is_success:
##     for score in result.data.items:
##         print("#%d %s: %s" % [score.rank, score.player_name, score.get_display_value()])
## [/codeblock]

## Emitted when a session is successfully started.
signal session_started(session: LeadrSession)

## Emitted when there is an authentication error.
signal session_error(error: LeadrError)

var _http_client: LeadrHttpClient
var _auth_manager: LeadrAuthManager
var _game_id: String
var _base_url: String
var _debug_logging: bool
var _initialized: bool = false


## Initializes the client with a LeadrSettings resource.
func initialize(settings: LeadrSettings) -> void:
	var error := settings.validate()
	if not error.is_empty():
		push_error("LEADR: Invalid settings - %s" % error)
		return

	_initialize_internal(settings.game_id, settings.base_url, settings.debug_logging)


## Initializes the client with individual parameters.
func initialize_with_game_id(
	game_id: String, base_url: String = "https://api.leadrcloud.com", debug_logging: bool = false
) -> void:
	var settings := LeadrSettings.new()
	settings.game_id = game_id
	settings.base_url = base_url
	settings.debug_logging = debug_logging

	var error := settings.validate()
	if not error.is_empty():
		push_error("LEADR: Invalid settings - %s" % error)
		return

	_initialize_internal(game_id, base_url, debug_logging)


func _initialize_internal(game_id: String, base_url: String, debug_logging: bool) -> void:
	_game_id = game_id
	_base_url = base_url.rstrip("/")
	_debug_logging = debug_logging

	_http_client = LeadrHttpClient.new(_base_url, _debug_logging, self)
	_auth_manager = LeadrAuthManager.new(_http_client, _game_id, _debug_logging)

	_auth_manager.session_changed.connect(_on_session_changed)
	_auth_manager.auth_error.connect(_on_auth_error)

	_initialized = true

	if _debug_logging:
		print("[LEADR] Initialized with game_id: %s" % _game_id)


## Returns true if the client has been initialized.
func is_initialized() -> bool:
	return _initialized


# =============================================================================
# Board Operations
# =============================================================================


## Gets a list of boards for the configured game.
## Returns LeadrResult with LeadrPagedResult containing LeadrBoard items.
func get_boards(limit: int = 20) -> LeadrResult:
	return await _get_boards_internal(limit, "")


## Gets a single board by its slug.
## Returns LeadrResult with LeadrBoard.
func get_board(board_slug: String) -> LeadrResult:
	_ensure_initialized()

	var endpoint := (
		"v1/client/boards/%s?game_id=%s" % [board_slug.uri_encode(), _game_id.uri_encode()]
	)

	return await _auth_manager.execute_authenticated(
		func(headers: Dictionary): return await _http_client.get_async(endpoint, headers),
		func(json: Dictionary): return LeadrBoard.from_dict(json),
		false
	)


func _get_boards_internal(limit: int, cursor: String) -> LeadrResult:
	_ensure_initialized()

	var endpoint := (
		"v1/client/boards?game_id=%s&limit=%d" % [_game_id.uri_encode(), clampi(limit, 1, 100)]
	)
	if not cursor.is_empty():
		endpoint += "&cursor=%s" % cursor.uri_encode()

	# Create closure for pagination
	var fetch_page := func(c: String): return await _get_boards_internal(limit, c)

	return await _auth_manager.execute_authenticated(
		func(headers: Dictionary): return await _http_client.get_async(endpoint, headers),
		func(json: Dictionary): return LeadrPagedResult.from_dict(
			json, LeadrBoard.from_dict, fetch_page
		),
		false
	)


# =============================================================================
# Score Operations
# =============================================================================


## Gets scores for a board.
## [param board_id] - The board ID (not slug)
## [param limit] - Number of scores per page (1-100)
## [param sort] - Sort direction override ("ascending" or "descending")
## [param around_score_id] - Center results around this score ID
## [param around_score_value] - Center results around this score value
## Note: around_score_id and around_score_value are mutually exclusive.
## Returns LeadrResult with LeadrPagedResult containing LeadrScore items.
func get_scores(
	board_id: String,
	limit: int = 20,
	sort: String = "",
	around_score_id: String = "",
	around_score_value: float = NAN
) -> LeadrResult:
	return await _get_scores_internal(
		board_id, limit, sort, around_score_id, around_score_value, ""
	)


## Gets a single score by its ID.
## Returns LeadrResult with LeadrScore.
func get_score(score_id: String) -> LeadrResult:
	_ensure_initialized()

	var endpoint := "v1/client/scores/%s" % score_id.uri_encode()

	return await _auth_manager.execute_authenticated(
		func(headers: Dictionary): return await _http_client.get_async(endpoint, headers),
		func(json: Dictionary): return LeadrScore.from_dict(json),
		false
	)


## Submits a new score to a board.
## [param board_id] - The board ID (not slug)
## [param value] - The numeric score value
## [param player_name] - The player's display name
## [param value_display] - Optional formatted display string
## [param metadata] - Optional custom metadata dictionary
## Returns LeadrResult with LeadrScore (including assigned rank).
func submit_score(
	board_id: String,
	value: int,
	player_name: String,
	value_display: String = "",
	metadata: Dictionary = {}
) -> LeadrResult:
	_ensure_initialized()

	var body := {
		"board_id": board_id,
		"value": value,
		"player_name": player_name,
	}

	if not value_display.is_empty():
		body["value_display"] = value_display

	if not metadata.is_empty():
		body["metadata"] = metadata

	var endpoint := "v1/client/scores"

	return await _auth_manager.execute_authenticated(
		func(headers: Dictionary): return await _http_client.post_async(endpoint, body, headers),
		func(json: Dictionary): return LeadrScore.from_dict(json),
		true  # Requires nonce
	)


func _get_scores_internal(
	board_id: String,
	limit: int,
	sort: String,
	around_score_id: String,
	around_score_value: float,
	cursor: String
) -> LeadrResult:
	_ensure_initialized()

	var endpoint := (
		"v1/client/scores?board_id=%s&limit=%d" % [board_id.uri_encode(), clampi(limit, 1, 100)]
	)

	if not sort.is_empty():
		endpoint += "&sort=%s" % sort.uri_encode()

	# Around parameters (mutually exclusive with cursor)
	if cursor.is_empty():
		if not around_score_id.is_empty():
			endpoint += "&around_score_id=%s" % around_score_id.uri_encode()
		elif not is_nan(around_score_value):
			endpoint += "&around_score_value=%s" % str(around_score_value)

	if not cursor.is_empty():
		endpoint += "&cursor=%s" % cursor.uri_encode()

	# Create closure for pagination (only cursor-based, not "around")
	var fetch_page := func(c: String): return await _get_scores_internal(
		board_id, limit, sort, "", NAN, c
	)

	return await _auth_manager.execute_authenticated(
		func(headers: Dictionary): return await _http_client.get_async(endpoint, headers),
		func(json: Dictionary): return LeadrPagedResult.from_dict(
			json, LeadrScore.from_dict, fetch_page
		),
		false
	)


# =============================================================================
# Session Operations
# =============================================================================


## Manually starts a session.
## This is usually not needed as sessions are created automatically.
## Returns LeadrResult with LeadrSession.
func start_session() -> LeadrResult:
	_ensure_initialized()
	return await _auth_manager.start_session()


## Clears stored tokens and session data.
## Call this to force a new session on the next request.
func clear_session() -> void:
	LeadrTokenStorage.clear_tokens()


## Returns true if there is a stored session token.
func has_session() -> bool:
	return LeadrTokenStorage.has_token()


# =============================================================================
# Internal
# =============================================================================


func _ensure_initialized() -> void:
	assert(_initialized, "LEADR: Client not initialized. Call initialize() first.")


func _on_session_changed(session: LeadrSession) -> void:
	session_started.emit(session)


func _on_auth_error(error: LeadrError) -> void:
	session_error.emit(error)
