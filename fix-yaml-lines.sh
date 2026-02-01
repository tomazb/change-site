#!/bin/bash
# Fix remaining line length issues in workflow files

# Function to break long lines in YAML files (requires GNU awk for match third-arg array)
fix_long_lines() {
  local file="$1"

  local awkcmd="awk"
  if command -v gawk >/dev/null 2>&1; then
    awkcmd="gawk"
  elif ! awk --version 2>/dev/null | grep -q GNU; then
    echo "Warning: GNU awk (gawk) required for $file processing" >&2
    return 1
  fi

  # Use GNU awk to break lines longer than 80 characters at appropriate points
  $awkcmd '
  length($0) > 80 && /run:/ {
    # For run commands, try to break at logical points
    if (match($0, /^([[:space:]]*)(.*run:[[:space:]]*\|?)(.*)/, arr)) {
      indent = arr[1]
      prefix = arr[2]
      command = arr[3]
      print indent prefix
      # Split long commands
      gsub(/&&/, " \\\n" indent "  &&", command)
      gsub(/\|\|/, " \\\n" indent "  ||", command)
      print indent "  " command
      next
    }
  }
  length($0) > 80 && /sed -i/ {
    # Break sed commands
    if (match($0, /^([[:space:]]*)(.*sed -i.*)/, arr)) {
      indent = arr[1]
      command = arr[2]
      gsub(/"[^"]*"/, "\\\n" indent "  &", command)
      print command
      next
    }
  }
  { print }
  ' "$file" > "${file}.tmp"
  if [[ -s "${file}.tmp" ]]; then
    mv "${file}.tmp" "$file"
  else
    echo "Error: Empty output for $file, keeping original" >&2
    rm -f "${file}.tmp"
    return 1
  fi
}

# Apply fixes to workflow files (nullglob so loop is empty if no matches)
shopt -s nullglob
for file in .github/workflows/*.yml; do
  if [[ ! -f "$file" ]]; then
    continue
  fi
  echo "Processing $file..."
  cp "$file" "${file}.bak"
  fix_long_lines "$file"
done
shopt -u nullglob
