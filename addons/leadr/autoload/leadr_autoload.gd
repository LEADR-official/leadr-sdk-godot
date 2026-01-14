extends LeadrClient
## Autoload helper for the LEADR SDK.
##
## Add this script as an autoload in Project Settings with the name "Leadr".
## If a LeadrSettings resource exists at "res://leadr_settings.tres",
## it will be loaded automatically.
##
## Setup:
## 1. Enable the LEADR SDK plugin in Project Settings > Plugins
## 2. Create a LeadrSettings resource: Right-click in FileSystem > New Resource > LeadrSettings
## 3. Configure your game_id in the resource
## 4. Save the resource as "res://leadr_settings.tres"
## 5. Add this script as an autoload: Project Settings > Autoload >
##    Path: "res://addons/leadr/autoload/leadr_autoload.gd", Name: "Leadr"
##
## Usage:
## [codeblock]
## # From anywhere in your game
## var result := await Leadr.get_boards()
## if result.is_success:
##     for board in result.data.items:
##         print(board.name)
## [/codeblock]

const SETTINGS_PATH := "res://leadr_settings.tres"


func _ready() -> void:
	# Auto-load settings if present
	if ResourceLoader.exists(SETTINGS_PATH):
		var settings: LeadrSettings = load(SETTINGS_PATH)
		if settings != null:
			initialize(settings)
			return

	# Log a helpful message if settings not found
	if OS.is_debug_build():
		push_warning(
			(
				"LEADR: No settings found at '%s'. " % SETTINGS_PATH
				+ "Create a LeadrSettings resource and save it there, "
				+ "or call Leadr.initialize_with_game_id() manually."
			)
		)
