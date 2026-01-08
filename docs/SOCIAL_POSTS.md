# Screenshot Organizer
Jan 08 2026 - 8:30 AM (MST)

## LinkedIn Post

Just shipped a fun side project: Screenshot Organizer

I take a lot of screenshots for work - upload confirmations, error messages, submission receipts. They pile up fast, and finding the right one later is a nightmare.

So I built a tool that:
- Watches a folder for new screenshots
- Auto-organizes them into date folders based on the filename
- Uses GPT-4V to analyze each image and extract useful data (submission IDs, error messages, timestamps)
- Stores everything in a searchable manifest.json

Now when I need to find "that screenshot with the failed build from last Tuesday" - I just search the manifest instead of scrolling through hundreds of files.

Built with bash, fswatch, jq, and the OpenAI API. Installable via Homebrew:

brew tap flavioespinoza/tap
brew install screenshot-organizer

Open source: github.com/flavioespinoza/screenshot-organizer

#opensource #developer #productivity #automation #gpt4

---

## Dev.to Post

Copy everything below the dashed line for dev.to (front matter must be at the very top of the article):

---

```
---
title: I Built a Screenshot Organizer That Uses GPT-4V to Make My Chaos Searchable
published: false
tags: opensource, productivity, bash, openai
---
```

## The Problem

I take a ton of screenshots for work. Upload confirmations, error messages, build logs, payment receipts. My screenshots folder was a graveyard of `CleanShot 2026-01-08 at 04.33.31@2x.png` files that meant nothing to me two days later.

The worst part? I'd screenshot something important - like a submission confirmation with an ID I needed later - and then spend 10 minutes scrolling through thumbnails trying to find it.

## The Solution

I built [Screenshot Organizer](https://github.com/flavioespinoza/screenshot-organizer) - a CLI tool that watches a folder and automatically:

1. **Organizes screenshots into date folders** based on the filename timestamp
2. **Analyzes each image with GPT-4V** to extract a description and structured data
3. **Stores everything in a manifest.json** that's actually searchable

## How It Works

Drop a screenshot into your watched folder. The tool:

1. Parses the date from the filename (`CleanShot 2026-01-08 at 07.19.21@2x.png`)
2. Moves it to a date folder (`2026-01-08/`)
3. Sends the image to GPT-4V with a prompt asking for a description and any IDs, error messages, or status indicators
4. Saves the analysis to `manifest.json`

Now instead of opening 50 screenshots to find the one with submission ID `299b42ee08de`, I just grep the manifest.

## Installation

```bash
brew tap flavioespinoza/tap
brew install screenshot-organizer

# Set your OpenAI API key
export OPENAI_API_KEY="sk-your-key-here"

# Start watching
screenshot-organizer watch ~/Desktop/Screenshots
```

Or run it as a background daemon that starts on login.

## The Stack

Nothing fancy:
- **Bash** - the whole thing is a shell script
- **fswatch** - watches for new files
- **jq** - JSON processing
- **OpenAI API** - GPT-4V for image analysis

## What GPT-4V Extracts

The prompt asks GPT-4V to pull out:
- Submission IDs, task IDs, build IDs
- Error messages and warnings
- Status indicators (PASS/FAIL/PENDING)
- Any other relevant structured data

It's surprisingly good at reading text from screenshots and understanding context.

## Why Bash?

I wanted something with zero dependencies beyond what's already on most dev machines (plus fswatch and jq). No Node runtime, no Python virtual environment, no Docker. Just a script you can read and modify.

## Try It

GitHub: [github.com/flavioespinoza/screenshot-organizer](https://github.com/flavioespinoza/screenshot-organizer)

If you're drowning in screenshots like I was, give it a shot. PRs welcome.
