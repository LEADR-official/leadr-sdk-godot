# LEADR SDK for Godot

The official LEADR leaderboard SDK for Godot 4+.

[![Godot v4+](https://img.shields.io/badge/Godot-v4+-478CBF?logo=godotengine&logoColor=white&style=for-the-badge)](https://godotengine.org)
[![CI](https://github.com/LEADR-official/leadr-sdk-godot/actions/workflows/ci.yml/badge.svg)](https://github.com/LEADR-official/leadr-sdk-godot/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

> **New to LEADR?** Follow the [Quick Start guide](https://docs.leadr.gg/latest/quick-start/)
> to create your account and set up your first leaderboard.

## Features

- **Easy integration** - Automatic authentication and token management
- **Anti-cheat Protection** - Server-side validation and rate limiting
- **Drop-in UI Components** - Built-in UI components for leaderboards and score submission

## Prerequisites

- Godot 4.3 or later
- A LEADR account and game ID - if you don't have these yet, follow the [Quick Start guide](https://docs.leadr.gg/latest/quick-start/) first

## Installation

### From Godot Asset Library

_Coming soon..._

### Manual Installation

1. Download or clone this repository
2. Copy the `addons/leadr` folder into your project's `addons` directory
3. Optionally copy the `examples` folder too
4. Enable the plugin: **Project > Project Settings > Plugins**, "☑️ On | LEADR SDK"

## Quick Start

### 1. Configure Settings

Create a `LeadrSettings` resource with your game ID:

1. In the FileSystem dock, right-click on res://addons/leadr/
1. Select **+ Create New > Resource...** to open the "Create New Resource" dialog
1. In the dialog, search for "LeadrSettings"
1. Select LeadrSettings and click **Create**
1. Save the file as `leadr_settings.tres`
3. Update `leadr_settings.tres` with your `game_id` (get this from the LEADR app)

### 2. Use the API

```gdscript
extends Node

func _ready() -> void:
    # Get leaderboards
    var boards_result := await Leadr.get_boards()
    if boards_result.is_success:
        for board in boards_result.data.items:
            print("Board: %s" % board.name)

    # Get scores for a specific board
    var scores_result := await Leadr.get_scores("brd_your_board_id", 10)
    if scores_result.is_success:
        for score in scores_result.data.items:
            print("#%d %s: %s" % [score.rank, score.player_name, score.get_display_value()])

    # Submit a score
    var submit_result := await Leadr.submit_score("brd_your_board_id", 12345, "Player Name")
    if submit_result.is_success:
        print("Score submitted! Rank: #%d" % submit_result.data.rank)
    else:
        print("Error: %s" % submit_result.error.message)
```

## Configuration

### LeadrSettings Resource

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `game_id` | String | *required* | Your LEADR game UUID |
| `base_url` | String | `https://api.leadrcloud.com` | API endpoint |
| `debug_logging` | bool | `false` | Enable verbose logging |
| `test_mode` | bool | `false` | Mark scores as test data |

## What's Next

- **[Full Integration Guide](https://docs.leadr.gg/latest/sdks/godot/)** - Complete documentation with UI components, advanced usage, and troubleshooting
- **[Examples](./examples/)** - Sample scenes demonstrating SDK features
- **[Join the Community!](https://discord.gg/RMUukcAxSZ){"target"="_blank"}** - Get support and inspiration on the LEADR Discord

## Need Help?

- [Discord](https://discord.gg/RMUukcAxSZ)
- [Full Documentation](https://docs.leadr.gg/latest/features)
- [Report an issue](https://github.com/LEADR-official/leadr-sdk-godot/issues)
