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

Install fswatch for file monitoring:
```bash
brew install fswatch
```

Install jq for JSON processing:
```bash
brew install jq
```

### Setup

1. Clone the repository:
```bash
git clone https://github.com/flavioespinoza/screenshot-organizer.git
```

```bash
cd screenshot-organizer
```

2. Set your OpenAI API key (add to ~/.zshrc for persistence):
```bash
export OPENAI_API_KEY="sk-your-key-here"
```

3. Install the launchd daemon:

Copy the plist template (edit to add your API key first):
```bash
cp com.screenshot-organizer.plist ~/Library/LaunchAgents/
```

Load the daemon (starts on login):
```bash
launchctl load ~/Library/LaunchAgents/com.screenshot-organizer.plist
```

## Usage

### Manual Commands

Check status - shows files needing organization and folder counts:
```bash
./screenshot-organizer.sh status
```

Organize all screenshots in root directory:
```bash
./screenshot-organizer.sh organize
```

Watch for new screenshots (runs continuously):
```bash
./screenshot-organizer.sh watch
```

Analyze all screenshots without descriptions:
```bash
./screenshot-organizer.sh describe
```

Analyze a specific screenshot:
```bash
./screenshot-organizer.sh describe <filename>
```

Show all descriptions:
```bash
./screenshot-organizer.sh descriptions
```

### Watching Custom Directories

You can pass a directory path to watch any folder.

Watch a specific directory:
```bash
./screenshot-organizer.sh watch ~/Desktop/Screenshots
```

Alternate syntax with --dir flag:
```bash
./screenshot-organizer.sh --dir ~/Desktop/Screenshots watch
```

Check status of a specific directory:
```bash
./screenshot-organizer.sh status ~/Pictures/Screens
```

### Running Multiple Instances

You can run multiple instances watching different directories simultaneously. Each directory gets its own `manifest.json` and separate log files.

Terminal 1 - watch Desktop screenshots:
```bash
./screenshot-organizer.sh watch ~/Desktop/Screenshots
```

Terminal 2 - watch another folder:
```bash
./screenshot-organizer.sh watch ~/Pictures/CleanShot
```

Logs are stored per-directory at `~/Library/Logs/screenshot-organizer/<folder-name>/`.

### Daemon Management

Check if running:
```bash
launchctl list | grep screenshot-organizer
```

View logs:
```bash
tail -f ~/Library/Logs/screenshot-organizer/organizer.log
```

Unload daemon:
```bash
launchctl unload ~/Library/LaunchAgents/com.screenshot-organizer.plist
```

Load daemon:
```bash
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
