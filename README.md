# LEADR SDK for Godot

The official LEADR leaderboard SDK for Godot 4+.

[![Godot v4+](https://img.shields.io/badge/Godot-v4+-478CBF?logo=godotengine&logoColor=white&style=for-the-badge)](https://godotengine.org)
[![CI](https://github.com/LEADR-official/leadr-sdk-godot/actions/workflows/ci.yml/badge.svg)](https://github.com/LEADR-official/leadr-sdk-godot/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)


## Features

- **Easy integration** - Automatic authentication and token management
- **Anti-cheat Protection** - Server-side validation and rate limiting
- **Drop-in UI Components** - Built-in UI components for leaderboards and score submission

## Requirements

- Godot 4.3 or later
- A LEADR account and game ID

## Installation

### From Godot Asset Library

_Coming soon..._

### Manual Installation

1. Download or clone this repository
2. Copy the `addons/leadr` folder into your project's `addons` directory
3. Optionally copy the `examples` folder too
4. Enable the plugin: **Project > Project Settings > Plugins > LEADR SDK**

## Quick Start

### 1. Configure Settings

Create a `LeadrSettings` resource with your game ID:

1. In the FileSystem dock, right-click and select **New Resource**
2. Search for and select **LeadrSettings**
3. Set your `game_id` (get this from the LEADR dashboard)
4. Save as `res://leadr_settings.tres`

### 2. Add Autoload

Add the LEADR client as an autoload singleton:

1. Go to **Project > Project Settings > Globals > Autoload**
2. Add `res://addons/leadr/autoload/leadr_autoload.gd`
3. Set the name to `Leadr`
4. Click **Add**

### 3. Use the API

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

### Debug Logging

Enable debug logging to see HTTP requests and responses:

```gdscript
# In settings resource, set debug_logging = true
# Or programmatically:
Leadr.initialize_with_game_id("your-game-id", "", true)
```

Logs appear as:
```
[LEADR] -> GET https://api.leadrcloud.com/v1/client/boards?game_id=...
[LEADR] <- 200 (145ms)
  Body: {"data":[...],"pagination":{"has_next":true}}
```

Sensitive data (tokens, fingerprints) is automatically redacted.

## Development

### Setup

```bash
# Install pre-commit hooks
uv run pre-commit install

# Run formatting & linting
./scripts/fmt.sh
```

### Project Structure

```
addons/leadr/
├── plugin.cfg              # Plugin metadata
├── leadr.gd                # EditorPlugin entry
├── core/                   # Core SDK classes
│   ├── leadr_client.gd     # Main API client
│   ├── leadr_settings.gd   # Configuration resource
│   ├── leadr_result.gd     # Result pattern
│   ├── leadr_error.gd      # Error details
│   └── paged_result.gd     # Pagination
├── internal/               # Internal implementation
│   ├── auth_manager.gd     # Token lifecycle
│   ├── http_client.gd      # HTTP wrapper
│   ├── token_storage.gd    # Persistent storage
│   └── fingerprint.gd      # Device fingerprinting
├── models/                 # Domain models
│   ├── board.gd
│   ├── score.gd
│   └── session.gd
├── ui/                     # UI components
│   ├── leadr_board_view.*
│   ├── leadr_score_entry.*
│   └── leadr_score_submitter.*
└── autoload/
    └── leadr_autoload.gd   # Autoload helper
```

## Support

- Documentation: [docs.leadr.gg](https://docs.leadr.gg)
- Issues: [GitHub Issues](https://github.com/LEADR-official/leadr-sdk-godot/issues)
- Discord: [LEADR Community](https://discord.gg/leadr)
