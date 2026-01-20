class_name LeadrSession
extends RefCounted
## Represents a LEADR device session.
##
## Sessions are created automatically when the first authenticated API call is made.
## You typically don't need to interact with sessions directly.

## Unique device identifier assigned by LEADR.
var device_id: String = ""

## The game ID this session belongs to.
var game_id: String = ""

## The account ID this session belongs to.
var account_id: String = ""

## SHA256 fingerprint of device characteristics.
var client_fingerprint: String = ""

## Platform string (e.g., "Windows", "Android", "iOS").
var platform: String = ""

## Session status: "active", "suspended", or "banned".
var status: String = ""

## Custom metadata attached to the session.
var metadata: Dictionary = {}

## Access token lifetime in seconds.
var expires_in: int = 0

## Access token (internal use only).
var access_token: String = ""

## Refresh token (internal use only).
var refresh_token: String = ""

## First time this device was seen.
var first_seen_at: String = ""

## Last time this device was seen.
var last_seen_at: String = ""


## Safely gets a string value from a dictionary, returning default if null or missing.
static func _get_str(data: Dictionary, key: String, default: String = "") -> String:
	var val = data.get(key)
	return val if val != null else default


## Safely gets a dictionary value, returning empty dict if null or missing.
static func _get_dict(data: Dictionary, key: String) -> Dictionary:
	var val = data.get(key)
	return val if val != null else {}


## Creates a Session from an API response dictionary.
static func from_dict(data: Dictionary) -> LeadrSession:
	var session := LeadrSession.new()

	session.access_token = _get_str(data, "access_token")
	session.refresh_token = _get_str(data, "refresh_token")
	session.expires_in = data.get("expires_in", 0)

	# Device info is nested
	var device: Dictionary = data.get("device", {})
	session.device_id = _get_str(device, "id")
	session.client_fingerprint = _get_str(device, "client_fingerprint")
	session.platform = _get_str(device, "platform")
	session.status = _get_str(device, "status")
	session.first_seen_at = _get_str(device, "first_seen_at")
	session.last_seen_at = _get_str(device, "last_seen_at")

	# Session info may be nested or at top level
	var session_data: Dictionary = data.get("session", data)
	session.game_id = _get_str(session_data, "game_id")
	session.account_id = _get_str(session_data, "account_id")
	session.metadata = _get_dict(session_data, "metadata")

	return session
