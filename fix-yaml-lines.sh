#!/bin/bash
# Fix remaining line length issues in workflow files

# Function to break long lines in YAML files
fix_long_lines() {
  local file="$1"
  
  # Use awk to break lines longer than 80 characters at appropriate points
  awk '
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
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# Apply fixes to workflow files
for file in .github/workflows/*.yml; do
  echo "Processing $file..."
  fix_long_lines "$file"
done
