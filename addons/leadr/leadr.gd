@tool
extends EditorPlugin
## LEADR SDK Editor Plugin
##
## This plugin provides integration with the LEADR leaderboard API.
## Enable this plugin and add LeadrClient as an autoload to get started.


func _get_plugin_name() -> String:
	return "LEADR SDK"


func _enter_tree() -> void:
	add_autoload_singleton("Leadr", "res://addons/leadr/autoload/leadr_autoload.gd")


func _exit_tree() -> void:
	remove_autoload_singleton("Leadr")
