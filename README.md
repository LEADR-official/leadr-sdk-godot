# LEADR SDK for Godot

The official LEADR leaderboard SDK for Godot 4+.

[![CI](https://github.com/LEADR-official/leadr-sdk-godot/actions/workflows/ci.yml/badge.svg)](https://github.com/LEADR-official/leadr-sdk-godot/actions/workflows/ci.yml)

## Features

- Easy integration with the LEADR leaderboard API
- Automatic authentication and token management
- Built-in UI components for leaderboards and score submission
- Cursor-based pagination
- Device fingerprinting for anti-cheat
- Debug logging with sensitive data redaction

## Requirements

- Godot 4.3 or later
- A LEADR account and game ID from [leadr.gg](https://leadr.gg)

## Installation

### From Godot Asset Library

1. Open your project in Godot
2. Go to **AssetLib** tab
3. Search for "LEADR SDK"
4. Click **Download** and then **Install**

### Manual Installation

1. Download or clone this repository
2. Copy the `addons/leadr` folder into your project's `addons` directory
3. Enable the plugin: **Project > Project Settings > Plugins > LEADR SDK**

## Quick Start

### 1. Configure Settings

Create a `LeadrSettings` resource with your game ID:

1. In the FileSystem dock, right-click and select **New Resource**
2. Search for and select **LeadrSettings**
3. Set your `game_id` (get this from the LEADR dashboard)
4. Save as `res://leadr_settings.tres`

### 2. Add Autoload

Add the LEADR client as an autoload singleton:

1. Go to **Project > Project Settings > Autoload**
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

## API Reference

### LeadrClient

The main client for interacting with LEADR. Access via the `Leadr` autoload.

#### Initialization

```gdscript
# With settings resource
Leadr.initialize(settings)

# With parameters
Leadr.initialize_with_game_id("your-game-uuid", "https://api.leadrcloud.com", false)
```

#### Board Operations

```gdscript
# Get all boards (paginated)
var result := await Leadr.get_boards(limit)  # Returns LeadrPagedResult with LeadrBoard items

# Get a specific board by slug
var result := await Leadr.get_board("board-slug")  # Returns LeadrBoard
```

#### Score Operations

```gdscript
# Get scores for a board
var result := await Leadr.get_scores(
    board_id,           # Required: Board ID (not slug)
    limit,              # Optional: Scores per page (1-100, default 20)
    sort,               # Optional: "ascending" or "descending"
    around_score_id,    # Optional: Center around this score ID
    around_score_value  # Optional: Center around this value
)

# Get a single score
var result := await Leadr.get_score("scr_score_id")

# Submit a score
var result := await Leadr.submit_score(
    board_id,       # Required: Board ID
    value,          # Required: Numeric score value
    player_name,    # Required: Display name
    value_display,  # Optional: Formatted display string
    metadata        # Optional: Custom metadata dictionary
)
```

#### Session Management

```gdscript
# Sessions are created automatically, but you can manually manage them:
await Leadr.start_session()  # Start a new session
Leadr.clear_session()        # Clear stored tokens
Leadr.has_session()          # Check if session exists
```

### Result Pattern

All API methods return a `LeadrResult`:

```gdscript
var result := await Leadr.get_boards()

if result.is_success:
    var data = result.data  # The response data
else:
    var error: LeadrError = result.error
    print("Error [%d]: %s" % [error.status_code, error.message])
```

### Pagination

Paginated results return a `LeadrPagedResult`:

```gdscript
var result := await Leadr.get_scores("brd_123", 10)
if result.is_success:
    var page: LeadrPagedResult = result.data

    # Access items
    for score in page.items:
        print(score.player_name)

    # Navigate pages
    if page.has_next:
        var next_result := await page.next_page()

    if page.has_prev:
        var prev_result := await page.prev_page()
```

## UI Components

The SDK includes ready-to-use UI components.

### LeadrBoardView

Displays a complete leaderboard with pagination:

```gdscript
var board_view := preload("res://addons/leadr/ui/leadr_board_view.tscn").instantiate()
board_view.board = "my-leaderboard-slug"
board_view.scores_per_page = 10
board_view.auto_load = true
add_child(board_view)

# Listen for events
board_view.score_selected.connect(func(score): print("Selected: %s" % score.player_name))
board_view.error_occurred.connect(func(error): print("Error: %s" % error.message))
```

### LeadrScoreSubmitter

Form for submitting scores:

```gdscript
var submitter := preload("res://addons/leadr/ui/leadr_score_submitter.tscn").instantiate()
submitter.board = "my-leaderboard-slug"
submitter.show_score_input = false  # Set score programmatically
submitter.set_score(player_score)
add_child(submitter)

submitter.score_submitted.connect(func(score):
    print("Submitted! Rank: #%d" % score.rank))
```

### LeadrScoreEntry

Individual score row (used internally by LeadrBoardView):

```gdscript
var entry := preload("res://addons/leadr/ui/leadr_score_entry.tscn").instantiate()
entry.score = my_score
entry.show_rank = true
entry.show_date = true
```

## Domain Models

### LeadrBoard

```gdscript
var board: LeadrBoard
board.id             # Unique ID (e.g., "brd_...")
board.name           # Display name
board.slug           # URL-safe identifier
board.sort_direction # "ascending" or "descending"
board.keep_strategy  # "all", "highest", or "latest"
board.unit           # Score unit (e.g., "points", "seconds")
board.is_in_season() # Check if currently in season
```

### LeadrScore

```gdscript
var score: LeadrScore
score.id                  # Unique ID (e.g., "scr_...")
score.player_name         # Player's display name
score.value               # Raw numeric value
score.value_display       # Formatted display string
score.rank                # 1-indexed position
score.metadata            # Custom metadata dictionary
score.get_display_value() # Returns value_display or formatted value
score.get_relative_time() # Returns "5m ago", "2d ago", etc.
```

### LeadrSession

```gdscript
var session: LeadrSession
session.device_id          # Unique device ID
session.status             # "active", "suspended", or "banned"
session.platform           # Platform string (e.g., "Windows")
session.client_fingerprint # Device fingerprint hash
```

## Configuration

### LeadrSettings Resource

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `game_id` | String | *required* | Your LEADR game UUID |
| `base_url` | String | `https://api.leadrcloud.com` | API endpoint |
| `debug_logging` | bool | `false` | Enable verbose logging |

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

## License

Apache 2.0 - see [LICENSE](LICENSE) for details.

## Support

- Documentation: [docs.leadr.gg](https://docs.leadr.gg)
- Issues: [GitHub Issues](https://github.com/LEADR-official/leadr-sdk-godot/issues)
- Discord: [LEADR Community](https://discord.gg/leadr)
