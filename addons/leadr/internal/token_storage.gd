class_name LeadrTokenStorage
extends RefCounted
## Persistent storage for LEADR authentication tokens and device fingerprint.
##
## Uses Godot's ConfigFile to persist data to the user:// directory.
## This is an internal class and should not be used directly.

const STORAGE_PATH := "user://leadr_credentials.cfg"
const SECTION := "leadr"

const KEY_FINGERPRINT := "client_fingerprint"
const KEY_ACCESS_TOKEN := "access_token"
const KEY_REFRESH_TOKEN := "refresh_token"
const KEY_EXPIRES_AT := "token_expires_at"
const KEY_TEST_MODE := "test_mode"


## Gets the stored client fingerprint, or empty string if not set.
static func get_fingerprint() -> String:
	return _get_value(KEY_FINGERPRINT, "")


## Sets the client fingerprint.
static func set_fingerprint(fingerprint: String) -> void:
	_set_value(KEY_FINGERPRINT, fingerprint)


## Gets the stored access token, or empty string if not set.
static func get_access_token() -> String:
	return _get_value(KEY_ACCESS_TOKEN, "")


## Gets the stored refresh token, or empty string if not set.
static func get_refresh_token() -> String:
	return _get_value(KEY_REFRESH_TOKEN, "")


## Gets the token expiration timestamp (Unix seconds), or 0 if not set.
static func get_expires_at() -> int:
	return _get_value(KEY_EXPIRES_AT, 0)


## Gets the stored test mode flag, or false if not set.
static func get_test_mode() -> bool:
	return _get_value(KEY_TEST_MODE, false)


## Sets the test mode flag.
static func set_test_mode(value: bool) -> void:
	_set_value(KEY_TEST_MODE, value)


## Saves authentication tokens.
static func save_tokens(access_token: String, refresh_token: String, expires_in: int) -> void:
	var expires_at := int(Time.get_unix_time_from_system()) + expires_in
	var config := _load_config()
	config.set_value(SECTION, KEY_ACCESS_TOKEN, access_token)
	config.set_value(SECTION, KEY_REFRESH_TOKEN, refresh_token)
	config.set_value(SECTION, KEY_EXPIRES_AT, expires_at)
	_save_config(config)


## Returns true if there is a stored access token.
static func has_token() -> bool:
	return not get_access_token().is_empty()


## Returns true if the stored token expires within the given threshold (seconds).
static func is_token_expiring_soon(threshold_seconds: int = 120) -> bool:
	var expires_at := get_expires_at()
	if expires_at == 0:
		return true
	var now := int(Time.get_unix_time_from_system())
	return (expires_at - now) <= threshold_seconds


## Returns true if the stored token has expired.
static func is_token_expired() -> bool:
	var expires_at := get_expires_at()
	if expires_at == 0:
		return true
	var now := int(Time.get_unix_time_from_system())
	return now >= expires_at


## Clears all stored tokens and test mode flag (but keeps fingerprint).
static func clear_tokens() -> void:
	var config := _load_config()
	config.set_value(SECTION, KEY_ACCESS_TOKEN, "")
	config.set_value(SECTION, KEY_REFRESH_TOKEN, "")
	config.set_value(SECTION, KEY_EXPIRES_AT, 0)
	config.set_value(SECTION, KEY_TEST_MODE, false)
	_save_config(config)


## Clears all stored data including fingerprint.
static func clear_all() -> void:
	var config := ConfigFile.new()
	_save_config(config)


static func _get_value(key: String, default: Variant) -> Variant:
	var config := _load_config()
	return config.get_value(SECTION, key, default)


static func _set_value(key: String, value: Variant) -> void:
	var config := _load_config()
	config.set_value(SECTION, key, value)
	_save_config(config)


static func _load_config() -> ConfigFile:
	var config := ConfigFile.new()
	var err := config.load(STORAGE_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("LEADR: Failed to load credentials file: %s" % error_string(err))
	return config


static func _save_config(config: ConfigFile) -> void:
	var err := config.save(STORAGE_PATH)
	if err != OK:
		push_error("LEADR: Failed to save credentials file: %s" % error_string(err))
