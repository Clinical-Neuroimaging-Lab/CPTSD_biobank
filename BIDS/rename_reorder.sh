#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

BASE="/Users/uqloestr/Library/CloudStorage/OneDrive-TheUniversityofQueensland/Desktop/raw_data"


# Mapping: old_id,new_id (in order)
MAPPING=$(cat <<'EOF'
UQPTSD002,sub-001
UQCPTSD001,sub-002
UQCPTSD003,sub-003
UQPTSD004,sub-004
UQCPTSD006,sub-005
UQCPTSD005,sub-006
UQCPTSD007,sub-007
UQCPTSD008,sub-008
UQCPTSD004,sub-009
UQCPTSD010,sub-010
UQCPTSD009,sub-011
UQCPTSD011,sub-012
UQPTSD003,sub-013
UQPTSD005,sub-014
UQPTSD006,sub-015
UQPTSD007,sub-016
UQPTSD008,sub-017
UQCPTSD017,sub-018
UQCPTSD015,sub-019
UQCPTSD018,sub-020
UQCPTSD014,sub-021
UQCPTSD016,sub-022
UQPTSD009,sub-023
UQCPTSD024,sub-024
EOF
)

echo "Planned mapping (in order):"
echo "$MAPPING" | awk -F, '{printf("  %-12s -> %s\n", $1, $2)}'
echo

run() { eval "$@"; }

echo "$MAPPING" | while IFS=, read -r src_id dst_id; do
  [ -z "${src_id:-}" ] && continue

  src_path="$BASE/$src_id"
  dst_path="$BASE/$dst_id"

  echo "----"
  echo "Processing: $src_id  ->  $dst_id"

  if [ ! -d "$src_path" ]; then
    echo "WARN: Source folder not found: $src_path (skipping)"
    continue
  fi

  # Count Research_* dirs directly under src_path
  research_count="$(find "$src_path" -maxdepth 1 -type d -name 'Research_*' | wc -l | tr -d ' ')"
  if [ "$research_count" -eq 0 ]; then
    echo "WARN: No Research_* folder found in $src_path (skipping cleanup, will only attempt rename)"
  elif [ "$research_count" -gt 1 ]; then
    echo "ERROR: Multiple Research_* folders found in $src_path:"
    find "$src_path" -maxdepth 1 -type d -name 'Research_*' -print | sed 's/^/  /'
    echo "Please resolve manually. Skipping this subject."
    continue
  else
    # Exactly one Research_* dir
    research_dir="$(find "$src_path" -maxdepth 1 -type d -name 'Research_*')"
    echo "Found Research folder: $research_dir"

    echo "Cleaning $src_path: removing non-Research_* items"
    # Remove everything except Research_* (handles hidden files via -print0)
    find "$src_path" -maxdepth 1 -mindepth 1 -print0 | while IFS= read -r -d '' item; do
      [ "$item" = "$research_dir" ] && continue
      run "rm -rf \"\$item\""
    done

    echo "Moving contents of $(basename "$research_dir") up one level"
    # Move all entries (including hidden) from Research_* up one level
    if [ "$(find "$research_dir" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" -gt 0 ]; then
      find "$research_dir" -maxdepth 1 -mindepth 1 -print0 | while IFS= read -r -d '' entry; do
        run "mv \"\$entry\" \"${src_path}/\""
      done
    fi

    echo "Removing empty Research folder"
    rmdir "$research_dir" 2>/dev/null || echo "Note: Research folder not empty (unexpected) or already removed."
  fi

  if [ -e "$dst_path" ]; then
    echo "ERROR: Destination already exists: $dst_path (skipping rename to avoid overwrite)"
    continue
  fi

  echo "Renaming: $src_path -> $dst_path"
  run "mv \"${src_path}\" \"${dst_path}\""
done

echo "----"
echo "Done."






