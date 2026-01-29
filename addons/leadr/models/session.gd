class_name LeadrSession
extends RefCounted
## Represents a LEADR identity session.
##
## Sessions are created automatically when the first authenticated API call is made.
## You typically don't need to interact with sessions directly.

## Identity kind enum.
enum IdentityKind { DEVICE, STEAM, CUSTOM }

## Unique identity identifier assigned by LEADR (e.g., "ide_...").
var identity_id: String = ""

## The game ID this session belongs to.
var game_id: String = ""

## The account ID this session belongs to.
var account_id: String = ""

## Identity kind.
var kind: IdentityKind = IdentityKind.DEVICE

## Optional display name for the identity.
var display_name: String = ""

## Whether this is a test mode session.
var test_mode: bool = false

## Access token lifetime in seconds.
var expires_in: int = 0

## Access token (internal use only).
var access_token: String = ""

## Refresh token (internal use only).
var refresh_token: String = ""


## Safely gets a string value from a dictionary, returning default if null or missing.
static func _get_str(data: Dictionary, key: String, default: String = "") -> String:
	var val = data.get(key)
	return val if val != null else default


## Parses an identity kind string from the API to the enum value.
static func _parse_identity_kind(value: String) -> IdentityKind:
	match value.to_upper():
		"DEVICE":
			return IdentityKind.DEVICE
		"STEAM":
			return IdentityKind.STEAM
		"CUSTOM":
			return IdentityKind.CUSTOM
		_:
			return IdentityKind.DEVICE


## Creates a Session from an API response dictionary.
static func from_dict(data: Dictionary) -> LeadrSession:
	var session := LeadrSession.new()

	session.access_token = _get_str(data, "access_token")
	session.refresh_token = _get_str(data, "refresh_token")
	session.expires_in = data.get("expires_in", 0)

	# New flat response structure
	session.identity_id = _get_str(data, "identity_id")
	session.game_id = _get_str(data, "game_id")
	session.account_id = _get_str(data, "account_id")
	session.kind = _parse_identity_kind(_get_str(data, "kind"))
	session.display_name = _get_str(data, "display_name")
	session.test_mode = data.get("test_mode", false)

	return session
