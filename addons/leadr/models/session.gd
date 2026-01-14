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


## Creates a Session from an API response dictionary.
static func from_dict(data: Dictionary) -> LeadrSession:
	var session := LeadrSession.new()

	session.access_token = data.get("access_token", "")
	session.refresh_token = data.get("refresh_token", "")
	session.expires_in = data.get("expires_in", 0)

	# Device info is nested
	var device: Dictionary = data.get("device", {})
	session.device_id = device.get("id", "")
	session.client_fingerprint = device.get("client_fingerprint", "")
	session.platform = device.get("platform", "")
	session.status = device.get("status", "")
	session.first_seen_at = device.get("first_seen_at", "")
	session.last_seen_at = device.get("last_seen_at", "")

	# Session info may be nested or at top level
	var session_data: Dictionary = data.get("session", data)
	session.game_id = session_data.get("game_id", "")
	session.account_id = session_data.get("account_id", "")
	session.metadata = session_data.get("metadata", {})

	return session
