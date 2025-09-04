#!/bin/bash
#
# This script compares the value of one or more specified YAML fields in a file
# between two git branches (e.g., a PR branch and the base 'main' branch).
#
# It exits with 0 (success) if ANY of the specified fields have changed.
# It exits with 1 (failure) if NONE of the specified fields have changed.
#
# Usage:
#   ./check_fields.sh <file_path> <base_ref> <head_ref> <field1> [<field2> ...]
#
# Example:
#   ./check_fields.sh my_rule.var.yml main my-feature-branch description options

set -e # Exit immediately if a command exits with a non-zero status.

# --- Arguments ---
FILE_PATH="$1"
BASE_REF="$2"
HEAD_REF="$3"
shift 3 # Shift the first three arguments off, the rest are the fields to check
FIELDS_TO_CHECK=("$@")

# --- Function to extract a multi-line YAML value ---
# This function uses awk to parse the YAML file. It starts printing lines when
# it finds the specified key and stops when it encounters another key at the
# same or lesser indentation level.
get_yaml_value() {
    local ref="$1"
    local file="$2"
    local key="$3"
    
    git show "$ref:$file" | awk -v key="$key" '
        BEGIN { printing = 0; }
        $1 == key":" { 
            printing = 1; 
            # Get the indentation of the key
            match($0, /^ */);
            key_indent = RLENGTH;
            # Handle single-line values like "description: some value"
            sub(/^[^:]*:[ \t]*/, ""); 
            if (length($0) > 0) { print; }
            next;
        }
        printing {
            # Get the indentation of the current line
            match($0, /^ */);
            current_indent = RLENGTH;
            # Stop if the indentation is less than or equal to the key's indentation,
            # and the line is not empty.
            if (current_indent <= key_indent && length($0) > 0) {
                printing = 0;
            } else {
                print;
            }
        }
    '
}

# --- Main Logic ---
# Loop through each field we need to check. If we find a change in any
# of them, we can succeed immediately.
for field in "${FIELDS_TO_CHECK[@]}"; do
    BASE_VALUE=$(get_yaml_value "$BASE_REF" "$FILE_PATH" "$field")
    HEAD_VALUE=$(get_yaml_value "$HEAD_REF" "$FILE_PATH" "$field")

    if [ "$BASE_VALUE" != "$HEAD_VALUE" ]; then
        echo "Field '$field' in '$FILE_PATH' was updated."
        exit 0
    fi
done

# If the loop completes without finding any changes, it's an error.
echo "Error: None of the required fields (${FIELDS_TO_CHECK[*]}) were updated in '$FILE_PATH'."
exit 1
