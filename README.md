# Screenshot Organizer

Auto-organize and analyze screenshots with GPT-4V vision.

## Features

- **Auto-organize** screenshots into date folders based on filename timestamps
- **Auto-analyze** with OpenAI GPT-4V to extract descriptions and structured data
- **Extract** submission IDs, error messages, platforms, statuses, and more
- **Store** everything in a searchable `manifest.json`
- **Run as daemon** via launchd for hands-free operation

## Installation

### Prerequisites

```bash
# Install fswatch for file monitoring
brew install fswatch

# Install jq for JSON processing
brew install jq
```

### Setup

1. Clone the repository:
```bash
git clone https://github.com/flavioespinoza/screenshot-organizer.git
cd screenshot-organizer
```

2. Configure the screenshots directory (edit `screenshot-organizer.sh`):
```bash
SCREENSHOTS_DIR="$HOME/Screenshots"  # Change to your preferred location
```

3. Set your OpenAI API key:
```bash
export CHIEF_OPENAI_API_KEY="sk-your-key-here"
# Or add to ~/.zshrc
```

4. Install the launchd daemon:
```bash
# Edit the plist to add your API key
cp com.screenshot-organizer.plist ~/Library/LaunchAgents/

# Load the daemon (starts on login)
launchctl load ~/Library/LaunchAgents/com.screenshot-organizer.plist
```

## Usage

### Manual Commands

```bash
# Check status - shows files needing organization and folder counts
./screenshot-organizer.sh status

# Organize all screenshots in root directory
./screenshot-organizer.sh organize

# Watch for new screenshots (runs continuously)
./screenshot-organizer.sh watch

# Analyze all screenshots without descriptions
./screenshot-organizer.sh describe

# Analyze a specific screenshot
./screenshot-organizer.sh describe "CleanShot 2026-01-08 at 04.03.48@2x.png"

# Show all descriptions
./screenshot-organizer.sh descriptions
```

### Daemon Management

```bash
# Check if running
launchctl list | grep screenshot-organizer

# View logs
tail -f ~/Library/Logs/screenshot-organizer/organizer.log

# Restart daemon
launchctl unload ~/Library/LaunchAgents/com.screenshot-organizer.plist
launchctl load ~/Library/LaunchAgents/com.screenshot-organizer.plist
```

## How It Works

1. **Drop a screenshot** into your screenshots directory
2. **fswatch detects** the new file
3. **Date extracted** from filename (e.g., `CleanShot 2026-01-08 at 04.03.48@2x.png`)
4. **File moved** to date folder (`2026-01-08/`)
5. **GPT-4V analyzes** the image in background
6. **Data stored** in `manifest.json`

## Manifest Structure

```json
{
  "last_updated": "2026-01-08T13:41:27Z",
  "processed_files": [
    {
      "file": "CleanShot 2026-01-08 at 04.03.48@2x.png",
      "folder": "2026-01-08",
      "organized_at": "2026-01-08T11:09:18Z",
      "description": "Screenshot shows a submission interface...",
      "extracted_data": {
        "submission_ids": ["3789cdcd-a5b3-4b3c-a792-299b42ee08de"],
        "statuses": ["PASS", "FAIL"],
        "error_messages": ["..."],
        "platforms": ["Snorkel AI Experts Portal"],
        "other": {}
      },
      "described_at": "2026-01-08T13:32:09Z"
    }
  ],
  "pending_files": [],
  "date_folders": ["2026-01-08"]
}
```

## Extracted Data Fields

| Field | Description |
|-------|-------------|
| `submission_ids` | UUIDs and submission identifiers |
| `iteration_ids` | Iteration/version identifiers |
| `task_ids` | Task identifiers |
| `zip_files` | Zip filenames found |
| `statuses` | Status indicators (PASS, FAIL, PENDING) |
| `error_messages` | Error messages and warnings |
| `build_ids` | Build identifiers |
| `platforms` | Platform names (terminus, harbor, etc.) |
| `other` | Additional extracted data |

## Supported Filename Formats

- CleanShot: `CleanShot 2026-01-08 at 04.03.48@2x.png`
- macOS Screenshot: `Screenshot 2026-01-08 at 4.03.48 PM.png`
- Fallback: Uses file modification date

## License

MIT
