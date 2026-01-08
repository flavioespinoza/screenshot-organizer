# Screenshot Organizer

Auto-organize and analyze screenshots with GPT-4V vision.

## Motivation

This tool was born out of necessity. When uploading multiple submissions to a platform that didn't provide downloadable receipts, the only way to track what was submitted was to take screenshots. But screenshots pile up fast, and matching them back to specific submissions became a nightmare.

The core problem: **the platform's dashboard only showed their Submission ID, not our Project name**. When we logged into the submission platform, we saw a table of uploads with columns like "Submission ID", "Date", and "Status" - but no column for the filename we uploaded. So if we had 20 pending submissions, we couldn't tell which Submission ID belonged to which project.

The only place our Project ID appeared was on the upload confirmation screen (in the "File Uploaded" field like `my-project-id_12345678.zip`). So we started screenshotting every upload confirmation to create our own mapping.

Screenshot Organizer automates this by:
- **Auto-organizing** screenshots into date folders the moment they're taken
- **Extracting submission IDs** from the platform's confirmation screen
- **Extracting zip filenames** that contain your project ID (e.g., `my-project-id_12345678.zip`)
- **Storing everything** in a searchable `manifest.json` so you can match any submission to your project

Now every screenshot becomes a searchable record that links the platform's Submission ID to your Project ID via the uploaded filename.

## Features

- **Auto-organize** screenshots into date folders based on filename timestamps
- **Auto-analyze** with OpenAI GPT-4V to extract descriptions and structured data
- **Extract** submission IDs, error messages, platforms, statuses, and more
- **Store** everything in a searchable `manifest.json`
- **Run as daemon** via launchd for hands-free operation

## How It Works

1. **Drop a screenshot** into your screenshots directory
2. **fswatch detects** the new file
3. **Date extracted** from filename (e.g., `CleanShot 2026-01-08 at 04.03.48@2x.png`)
4. **File moved** to date folder (`2026-01-08/`)
5. **GPT-4V analyzes** the image in background
6. **Data stored** in `manifest.json`

**→ [Jump to Installation](#installation)**

## Manifest Structure

**Screenshot taken:** `CleanShot 2026-01-08 at 07.19.21@2x.png` → analyzed → stored in manifest:

![Screenshot Example](https://github.com/flavioespinoza/screenshot-organizer/blob/feature/custom-directory-support/docs/example-screenshot-v3.png?raw=true)

**What GPT-4V extracted and corrected:**

1. **Submission ID** → `299b42ee08de` (extracted from screenshot)
2. **Project ID** → `my-project-id_12345678` (extracted from "File Uploaded" field, maps to Submission ID above)
3. **Year** → `2026` (missing from screenshot, derived from filename)
4. **Timezone** → Converted to UTC (screenshot shows local time "7:19 AM", stored as `2026-01-08T14:19:21Z`)
5. **Full timestamp** → Reconstructed from filename `CleanShot 2026-01-08 at 07.19.21@2x.png`
6. **Date folder** → `2026-01-08/` (auto-organized based on extracted date)

```json
{
  "last_updated": "2026-01-08T14:19:25Z",
  "processed_files": [
    {
      "file": "CleanShot 2026-01-08 at 07.19.21@2x.png",
      "folder": "2026-01-08",
      "organized_at": "2026-01-08T14:19:23Z",
      "description": "The screenshot shows a confirmation message for a successful submission, including the email, timestamp, submission ID, and uploaded filename.",
      "extracted_data": {
        "submission_ids": ["299b42ee08de"],
        "zip_files": ["my-project-id_12345678.zip"],
        "statuses": [],
        "error_messages": [],
        "platforms": [],
        "other": {}
      },
      "described_at": "2026-01-08T14:19:25Z"
    }
  ],
  "pending_files": [],
  "date_folders": ["2026-01-08"]
}
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

## Supported Image Types

- PNG (`.png`)
- JPG/JPEG (`.jpg`, `.jpeg`)
- GIF (`.gif`)
- WebP (`.webp`)

## Git Integration

The `screenshots/` directory includes a `.gitignore` that:
- **Ignores** all image files (PNG, JPG, GIF, WebP)
- **Ignores** date folders containing screenshots
- **Tracks** only `manifest.json` (searchable metadata)

This keeps your repo clean while preserving the searchable manifest. Screenshots stay local.

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

## TODO: Homebrew Installation

- [ ] Create Homebrew formula (`screenshot-organizer.rb`)
- [ ] Set up Homebrew tap (`homebrew-screenshot-organizer`)
- [ ] Auto-install dependencies (`fswatch`, `jq`)
- [ ] Install script to `/usr/local/bin/screenshot-organizer`
- [ ] Install plist template to correct location
- [ ] Add `brew services` support for daemon management
- [ ] Post-install instructions for API key setup

**Goal:** Install with a single command:
```bash
brew install flavioespinoza/tap/screenshot-organizer
```

Then manage with:
```bash
brew services start screenshot-organizer
brew services stop screenshot-organizer
```

## License

MIT
