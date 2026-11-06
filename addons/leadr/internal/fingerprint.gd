class_name LeadrFingerprint
extends RefCounted
## Device fingerprinting for LEADR SDK.
##
## Generates a stable SHA256 hash from device characteristics.
## This is an internal class and should not be used directly.


## Gets or generates the device fingerprint.
## The fingerprint is cached after first generation.
static func get_or_generate() -> String:
	var cached := LeadrTokenStorage.get_fingerprint()
	if not cached.is_empty():
		return cached

	var fingerprint := generate()
	LeadrTokenStorage.set_fingerprint(fingerprint)
	return fingerprint


## Generates a new fingerprint from device characteristics.
## Returns a 64-character lowercase hex string (SHA256).
static func generate() -> String:
	var components := PackedStringArray()

	# Platform identifier (Windows, macOS, Linux, Android, iOS, etc.)
	components.append(OS.get_name())

	# Hardware identifier (device-specific ID)
	# OS.get_unique_id() returns empty on web/desktop platforms, use fallback
	var unique_id := OS.get_unique_id()
	if unique_id.is_empty():
		unique_id = _get_or_create_persistent_id()
	components.append(unique_id)

	# GPU identifier
	components.append(RenderingServer.get_video_adapter_name())

	# CPU identifier
	components.append(_get_processor_name())

	# Memory size (in bytes, converted to MB for stability)
	var memory_mb := OS.get_static_memory_usage() / (1024 * 1024)
	components.append(str(memory_mb))

	var combined := "|".join(components)
	return combined.sha256_text()


## Gets the processor name in a cross-platform way.
static func _get_processor_name() -> String:
	# OS.get_processor_name() was added in Godot 4.2
	if OS.has_method("get_processor_name"):
		return OS.call("get_processor_name")

	# Fallback for older versions
	return "unknown_cpu"


## Gets or creates a persistent device ID for platforms without OS.get_unique_id().
## Used as fallback on Web, Windows, macOS, Linux where get_unique_id() returns empty.
static func _get_or_create_persistent_id() -> String:
	var stored := LeadrTokenStorage.get_persistent_device_id()
	if not stored.is_empty():
		return stored

	var new_id := _generate_uuid_v4()
	LeadrTokenStorage.set_persistent_device_id(new_id)
	return new_id


## Generates a random UUID v4 (RFC 4122 compliant).
## Returns a 32-character lowercase hex string (no dashes).
static func _generate_uuid_v4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	for i in range(16):
		bytes.append(rng.randi() % 256)
	# Set version 4 (random) in bits 12-15 of time_hi_and_version
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	# Set variant (RFC 4122) in bits 6-7 of clock_seq_hi_and_reserved
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	return bytes.hex_encode()
