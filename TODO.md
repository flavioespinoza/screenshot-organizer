# Screenshot Organizer - TODO

Last Updated: Jan 08 2026

## Priority: High

- [ ] **Implement Custom Manifest Schema** - Read `manifest-schema.json` from watched directory and use it to customize GPT-4V extraction prompt
- [ ] **Fix duplicate entries in manifest** - Some files appear twice in `processed_files` array (e.g., `CleanShot 2026-01-08 at 07.19.45@2x.png`)

## Priority: Medium

- [ ] **Add search command** - `screenshot-organizer search "submission ID 299b42ee"` to grep the manifest
- [ ] **Import existing screenshots** - Batch organize and describe existing folders
- [ ] **Export to CSV** - Export manifest data for spreadsheet analysis
- [ ] **Deduplicate manifest entries** - Prevent same file from being processed twice

## Priority: Low

- [ ] **Web UI** - Browser-based interface for viewing and searching screenshots
- [ ] **Slack integration** - Auto-post organized screenshots to a Slack channel
- [ ] **Better error handling** - Graceful failures when OpenAI API is unavailable
- [ ] **Rate limiting** - Respect OpenAI API rate limits for batch processing

## Completed

- [x] Auto-organize screenshots into date folders
- [x] GPT-4V analysis with structured data extraction
- [x] Homebrew formula for easy installation
- [x] Custom directory support (`--dir` flag)
- [x] Multiple instance support
- [x] launchd daemon for background operation
- [x] Dev.to article published
- [x] LinkedIn and Twitter posts created

## Known Issues

1. **Duplicate manifest entries** - Files sometimes get added twice to `processed_files`
2. **No schema validation** - Custom schemas aren't validated before use
3. **No cleanup of orphaned entries** - If a file is deleted, manifest entry remains

## Notes

- Manifest is stored at `<watched-dir>/manifest.json`
- Logs at `~/Library/Logs/screenshot-organizer/<folder-name>/`
- Requires `OPENAI_API_KEY` environment variable
