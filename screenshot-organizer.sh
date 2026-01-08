#!/bin/bash
# Screenshot Organizer - Analyzes and archives screenshots into date folders
# Watches the screenshots/ directory and automatically organizes new files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCREENSHOTS_DIR="$PROJECT_ROOT/screenshots"
LOG_DIR="$HOME/Library/Logs/screenshot-organizer"
MANIFEST="$SCREENSHOTS_DIR/manifest.json"

mkdir -p "$LOG_DIR"
mkdir -p "$SCREENSHOTS_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/organizer.log"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_DIR/error.log" >&2
}

# Initialize manifest if it doesn't exist
init_manifest() {
    if [[ ! -f "$MANIFEST" ]]; then
        cat > "$MANIFEST" << 'EOF'
{
    "last_updated": null,
    "processed_files": [],
    "pending_files": [],
    "date_folders": []
}
EOF
        log "Initialized manifest at $MANIFEST"
    fi
}

# Extract date from CleanShot filename (e.g., "CleanShot 2026-01-08 at 04.03.48@2x.png")
extract_date_from_filename() {
    local filename="$1"

    # CleanShot format: "CleanShot YYYY-MM-DD at HH.MM.SS@2x.png"
    if [[ "$filename" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # Screenshot format: "Screenshot YYYY-MM-DD at H.MM.SS AM/PM.png"
    if [[ "$filename" =~ Screenshot[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # Fallback: use file modification date
    return 1
}

# Get date from file metadata as fallback
get_file_date() {
    local file="$1"
    stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null || date +"%Y-%m-%d"
}

# Organize a single screenshot into its date folder
# NEW FLOW: Read image → Analyze → Add to manifest → Verify → THEN move to archive
organize_screenshot() {
    local file="$1"
    local filename=$(basename "$file")

    # Skip if file doesn't exist (already moved by previous event)
    if [[ ! -f "$file" ]]; then
        return 0
    fi

    # Skip hidden files and directories
    if [[ "$filename" == .* ]] || [[ -d "$file" ]]; then
        return 0
    fi

    # Skip non-image files
    if [[ ! "$filename" =~ \.(png|jpg|jpeg|gif|webp)$ ]]; then
        return 0
    fi

    log "Processing: $filename"

    # STEP 1: Analyze the image FIRST (while still in root)
    log "Step 1: Analyzing image..."
    local analysis_result
    analysis_result=$(analyze_screenshot_sync "$file")

    if [[ -z "$analysis_result" ]]; then
        error "Failed to analyze $filename - skipping"
        return 1
    fi

    # STEP 2: Extract date from filename or fallback to file date
    local date_folder
    date_folder=$(extract_date_from_filename "$filename") || date_folder=$(get_file_date "$file")

    # STEP 3: Add ALL metadata to manifest BEFORE moving
    log "Step 2: Adding to manifest with full metadata..."
    local description=$(echo "$analysis_result" | jq -r '.description // "No description"')
    local extracted_data=$(echo "$analysis_result" | jq -c '.extracted_data // {}')

    add_to_manifest_complete "$filename" "$date_folder" "$description" "$extracted_data"

    # STEP 4: Verify manifest was updated
    log "Step 3: Verifying manifest entry..."
    local verify=$(jq --arg f "$filename" '.processed_files[] | select(.file == $f) | .description' "$MANIFEST" 2>/dev/null)

    if [[ -z "$verify" ]] || [[ "$verify" == "null" ]]; then
        error "Manifest verification FAILED for $filename"
        return 1
    fi
    log "Manifest verified: $filename has description"

    # STEP 5: NOW move to date folder
    log "Step 4: Moving to archive folder..."
    local target_dir="$SCREENSHOTS_DIR/$date_folder"
    mkdir -p "$target_dir"

    local target_path="$target_dir/$filename"
    if [[ "$file" != "$target_path" ]]; then
        mv "$file" "$target_path"
        log "COMPLETE: $filename -> $date_folder/ (with full metadata)"
    fi
}

# Synchronous analyze - returns JSON result (not async)
analyze_screenshot_sync() {
    local file="$1"
    local filename=$(basename "$file")

    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
        return 1
    fi

    local prompt='Analyze this screenshot and extract information.

Respond ONLY with valid JSON in this exact format (no other text, no markdown):
{
  "description": "Brief 1-2 sentence description of what the screenshot shows",
  "extracted_data": {
    "submission_ids": ["list any submission IDs or UUIDs found"],
    "iteration_ids": ["list any iteration IDs found"],
    "task_ids": ["list any task IDs found"],
    "zip_files": ["list any zip filenames found"],
    "statuses": ["list any status indicators like PASS, FAIL, PENDING"],
    "error_messages": ["list any error messages found"],
    "build_ids": ["list any build IDs found"],
    "platforms": ["list any platform names like terminus, harbor, marlin"],
    "other": {}
  }
}

If a field has no data, use an empty array []. Always return valid JSON.'

    local result
    result=$(call_openai_vision "$file" "$prompt")

    if [[ -z "$result" ]]; then
        error "OpenAI API returned empty response for $filename"
        return 1
    fi

    # Try to parse directly as JSON
    if echo "$result" | jq . &>/dev/null; then
        echo "$result"
    else
        # Try to extract JSON from response
        local json_part=$(echo "$result" | grep -o '{.*}' | head -1)
        if [[ -n "$json_part" ]] && echo "$json_part" | jq . &>/dev/null; then
            echo "$json_part"
        else
            # Return minimal valid JSON
            echo '{"description": "'"$(echo "$result" | head -1 | tr -d '"')"'", "extracted_data": {}}'
        fi
    fi
}

# Add complete entry to manifest with ALL metadata at once
add_to_manifest_complete() {
    local filename="$1"
    local date_folder="$2"
    local description="$3"
    local extracted_data="$4"
    local temp_file=$(mktemp)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg file "$filename" \
       --arg folder "$date_folder" \
       --arg desc "$description" \
       --arg data "$extracted_data" \
       --arg ts "$timestamp" '
        .processed_files += [{
            "file": $file,
            "folder": $folder,
            "description": $desc,
            "extracted_data": ($data | fromjson? // {}),
            "organized_at": $ts,
            "described_at": $ts
        }] |
        .last_updated = $ts |
        if (.date_folders | index($folder)) == null then
            .date_folders += [$folder]
        else . end
    ' "$MANIFEST" > "$temp_file" && mv "$temp_file" "$MANIFEST"

    log "Manifest updated: $filename with description and extracted_data"
}

# Update manifest with organized file (legacy - kept for compatibility)
update_manifest() {
    local filename="$1"
    local date_folder="$2"
    local temp_file=$(mktemp)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg file "$filename" \
       --arg folder "$date_folder" \
       --arg ts "$timestamp" '
        .processed_files += [{"file": $file, "folder": $folder, "organized_at": $ts}] |
        .last_updated = $ts |
        if (.date_folders | index($folder)) == null then
            .date_folders += [$folder]
        else . end
    ' "$MANIFEST" > "$temp_file" && mv "$temp_file" "$MANIFEST"
}

# Update manifest with description for a file
update_manifest_description() {
    local filename="$1"
    local description="$2"
    local extracted_data="$3"
    local temp_file=$(mktemp)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg file "$filename" \
       --arg desc "$description" \
       --arg data "$extracted_data" \
       --arg ts "$timestamp" '
        .processed_files = [.processed_files[] |
            if .file == $file then
                . + {"description": $desc, "extracted_data": ($data | fromjson? // $data), "described_at": $ts}
            else . end
        ] |
        .last_updated = $ts
    ' "$MANIFEST" > "$temp_file" && mv "$temp_file" "$MANIFEST"
}

# Call OpenAI GPT-4V API with image (reuses pattern from tribal-knowledge-chief)
call_openai_vision() {
    local image_path="$1"
    local prompt="$2"

    # Use CHIEF_OPENAI_API_KEY or fall back to OPENAI_API_KEY
    local api_key="${CHIEF_OPENAI_API_KEY:-$OPENAI_API_KEY}"
    if [[ -z "$api_key" ]]; then
        error "CHIEF_OPENAI_API_KEY or OPENAI_API_KEY not set"
        return 1
    fi

    # Base64 encode the image to a temp file (avoids argument list too long)
    local temp_base64=$(mktemp)
    local temp_payload=$(mktemp)
    base64 -i "$image_path" > "$temp_base64"

    local media_type="image/png"
    if [[ "$image_path" == *.jpg ]] || [[ "$image_path" == *.jpeg ]]; then
        media_type="image/jpeg"
    elif [[ "$image_path" == *.webp ]]; then
        media_type="image/webp"
    elif [[ "$image_path" == *.gif ]]; then
        media_type="image/gif"
    fi

    # Build JSON payload using temp file for base64
    local base64_content=$(cat "$temp_base64")
    cat > "$temp_payload" << PAYLOAD_EOF
{
    "model": "gpt-4o-mini",
    "messages": [
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": $(echo "$prompt" | jq -Rs .)
                },
                {
                    "type": "image_url",
                    "image_url": {
                        "url": "data:${media_type};base64,${base64_content}"
                    }
                }
            ]
        }
    ],
    "max_tokens": 1000
}
PAYLOAD_EOF

    # Call API with payload from file
    local response=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d @"$temp_payload")

    # Cleanup temp files
    rm -f "$temp_base64" "$temp_payload"

    # Extract content from response
    echo "$response" | jq -r '.choices[0].message.content // empty'
}

# Analyze a screenshot using OpenAI GPT-4V and extract description + data
analyze_screenshot() {
    local file="$1"
    local filename=$(basename "$file")

    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
        return 1
    fi

    log "Analyzing: $filename"

    local prompt='Analyze this screenshot and extract information.

Respond ONLY with valid JSON in this exact format (no other text, no markdown):
{
  "description": "Brief 1-2 sentence description of what the screenshot shows",
  "extracted_data": {
    "submission_ids": ["list any submission IDs or UUIDs found"],
    "iteration_ids": ["list any iteration IDs found"],
    "task_ids": ["list any task IDs found"],
    "zip_files": ["list any zip filenames found"],
    "statuses": ["list any status indicators like PASS, FAIL, PENDING"],
    "error_messages": ["list any error messages found"],
    "build_ids": ["list any build IDs found"],
    "platforms": ["list any platform names like terminus, harbor"],
    "other": {}
  }
}

If a field has no data, use an empty array []. Always return valid JSON.'

    local result
    result=$(call_openai_vision "$file" "$prompt")

    if [[ -z "$result" ]]; then
        error "OpenAI API returned empty response for $filename"
        return 1
    fi

    # Parse the JSON response
    local description
    local extracted_data

    # Try to parse directly as JSON
    if echo "$result" | jq . &>/dev/null; then
        description=$(echo "$result" | jq -r '.description // "No description available"')
        extracted_data=$(echo "$result" | jq -c '.extracted_data // {}')
    else
        # Try to extract JSON from response (might have extra text)
        local json_part=$(echo "$result" | grep -o '{.*}' | head -1)
        if [[ -n "$json_part" ]] && echo "$json_part" | jq . &>/dev/null; then
            description=$(echo "$json_part" | jq -r '.description // "No description available"')
            extracted_data=$(echo "$json_part" | jq -c '.extracted_data // {}')
        else
            # Fallback: use the raw result as description
            description=$(echo "$result" | head -3 | tr '\n' ' ' | sed 's/  */ /g')
            extracted_data="{}"
        fi
    fi

    # Update manifest with description
    update_manifest_description "$filename" "$description" "$extracted_data"

    log "Analyzed: $filename - $description"
    echo "$description"
}

# Describe all screenshots that don't have descriptions
describe_all() {
    log "Analyzing screenshots without descriptions..."
    local count=0
    local analyzed=0

    # Get list of files without descriptions
    local files_without_desc
    files_without_desc=$(jq -r '.processed_files[] | select(.description == null) | .file' "$MANIFEST" 2>/dev/null)

    if [[ -z "$files_without_desc" ]]; then
        log "All screenshots already have descriptions"
        return 0
    fi

    while IFS= read -r filename; do
        if [[ -n "$filename" ]]; then
            # Find the file in date folders
            local folder
            folder=$(jq -r --arg f "$filename" '.processed_files[] | select(.file == $f) | .folder' "$MANIFEST")
            local filepath="$SCREENSHOTS_DIR/$folder/$filename"

            if [[ -f "$filepath" ]]; then
                analyze_screenshot "$filepath"
                ((analyzed++)) || true
            else
                error "File not found: $filepath"
            fi
            ((count++)) || true
        fi
    done <<< "$files_without_desc"

    log "Analyzed $analyzed of $count screenshot(s)"
}

# Describe a specific screenshot by filename or path
describe_one() {
    local input="$1"
    local filepath=""

    # Check if it's a full path
    if [[ -f "$input" ]]; then
        filepath="$input"
    else
        # Search for the file in screenshots directory
        filepath=$(find "$SCREENSHOTS_DIR" -name "$input" -type f 2>/dev/null | head -1)
    fi

    if [[ -z "$filepath" ]] || [[ ! -f "$filepath" ]]; then
        error "Screenshot not found: $input"
        return 1
    fi

    analyze_screenshot "$filepath"
}

# Show descriptions for all analyzed screenshots
show_descriptions() {
    echo "=== Screenshot Descriptions ==="
    echo ""

    jq -r '.processed_files[] | select(.description != null) |
        "[\(.folder)] \(.file)\n  Description: \(.description)\n  Data: \(.extracted_data | tostring)\n"
    ' "$MANIFEST" 2>/dev/null || echo "No descriptions found"
}

# Organize all screenshots in root directory
organize_all() {
    log "Organizing all screenshots in root directory..."
    local count=0

    for file in "$SCREENSHOTS_DIR"/*; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            # Skip manifest and hidden files
            if [[ "$filename" != "manifest.json" ]] && [[ "$filename" != .* ]]; then
                organize_screenshot "$file"
                ((count++)) || true
            fi
        fi
    done

    log "Organized $count screenshot(s)"
}

# Watch for new screenshots and organize them
watch_screenshots() {
    log "=== Screenshot Organizer starting ==="
    log "Watching: $SCREENSHOTS_DIR"

    # Check if fswatch is installed
    if ! command -v fswatch &> /dev/null; then
        log "ERROR: fswatch not installed. Run: brew install fswatch"
        exit 1
    fi

    # First, organize any existing files in root
    organize_all

    log "Starting file watch..."

    fswatch -0 --event Created --event Updated "$SCREENSHOTS_DIR" 2>/dev/null | while read -d "" file; do
        # Only process files directly in screenshots/ (not in subfolders)
        local dir=$(dirname "$file")
        if [[ "$dir" == "$SCREENSHOTS_DIR" ]]; then
            local filename=$(basename "$file")
            # Skip hidden files and manifest
            if [[ "$filename" != .* ]] && [[ "$filename" != "manifest.json" ]]; then
                # Small delay to ensure file is fully written
                sleep 0.5
                organize_screenshot "$file"
            fi
        fi
    done
}

# Show status of screenshots directory
show_status() {
    echo "=== Screenshot Organizer Status ==="
    echo ""
    echo "Screenshots directory: $SCREENSHOTS_DIR"
    echo ""

    # Count files in root (need organizing)
    local root_count=0
    for file in "$SCREENSHOTS_DIR"/*; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            if [[ "$filename" != "manifest.json" ]] && [[ "$filename" != .* ]]; then
                ((root_count++)) || true
            fi
        fi
    done
    echo "Files needing organization: $root_count"
    echo ""

    # List date folders and counts
    echo "Date folders:"
    for dir in "$SCREENSHOTS_DIR"/*/; do
        if [[ -d "$dir" ]]; then
            local folder=$(basename "$dir")
            local count=$(find "$dir" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | wc -l | tr -d ' ')
            echo "  $folder: $count files"
        fi
    done
}

# Main entry point
case "${1:-}" in
    watch)
        init_manifest
        watch_screenshots
        ;;
    organize)
        init_manifest
        organize_all
        ;;
    status)
        show_status
        ;;
    describe)
        init_manifest
        if [[ -n "${2:-}" ]]; then
            describe_one "$2"
        else
            describe_all
        fi
        ;;
    descriptions)
        show_descriptions
        ;;
    *)
        echo "Screenshot Organizer - Organize and analyze screenshots"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  watch           Watch for new screenshots and organize automatically"
        echo "  organize        Organize all existing screenshots in root directory"
        echo "  status          Show current status and folder counts"
        echo "  describe        Analyze all screenshots without descriptions (uses Claude)"
        echo "  describe <file> Analyze a specific screenshot by filename or path"
        echo "  descriptions    Show all screenshot descriptions from manifest"
        echo ""
        echo "Screenshots are organized by date extracted from filename"
        echo "(e.g., 'CleanShot 2026-01-08 at 04.03.48@2x.png' -> 2026-01-08/)"
        echo ""
        echo "The 'describe' command uses OpenAI GPT-4V to analyze images and extract:"
        echo "  - Submission IDs, Iteration IDs, Task IDs"
        echo "  - Zip file names, Build IDs"
        echo "  - Status indicators (PASS/FAIL/PENDING)"
        echo "  - Error messages and other relevant data"
        exit 1
        ;;
esac
