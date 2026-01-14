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
	components.append(OS.get_unique_id())

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
