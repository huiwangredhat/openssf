#!/bin/bash

# squash_commits.sh
# This script automates squashing multiple Git commits into a single one.
# Usage:
# sh squash_commits.sh $number_of_commits_to_squash [--keep-messages] --push


echo "Starting Git Commit Squasher Script..."

# Check for a clean working directory
if [[ -n $(git status --porcelain) ]]; then
  echo "Error: Your working directory is not clean."
  echo "Please commit or stash your changes before attempting to squash commits."
  exit 1
fi

# Check arguments
if [ $# -lt 2 ]; then
    echo "Please provide NUM_COMMITS_TO_SQUASH and --push as inputs."
    exit 1
fi

# Determine the rebase range and the type of squash operation (fixup or squash)
SQUASH_TYPE="fixup" # Default: 'fixup' (discards subsequent commit messages)
REBASE_RANGE=""
NUM_COMMITS_TO_SQUASH=0 # Used for validation
PERFORM_PUSH="false" # Flag to determine if a push should be attempted

# Parse command line arguments
if [[ "$1" == [0-9]* ]]; then
  NUM_COMMITS_TO_SQUASH=$1
  if [[ $NUM_COMMITS_TO_SQUASH -le 1 ]]; then
    echo "Nothing to squash. You need at least 2 commits to perform a squash operation."
    exit 0
  fi
  REBASE_RANGE="HEAD~$NUM_COMMITS_TO_SQUASH"
fi

export GIT_SEQUENCE_EDITOR="sed -i.bak '1s/^pick/pick/g; 2,\$s/^pick/squash/g'"
# Execute the interactive rebase
echo "Running git rebase -i $REBASE_RANGE..."
git rebase -i "$REBASE_RANGE"
if [[ "$PERFORM_PUSH" == "true" ]]; then
  echo "Attempting to push changes to remote..."
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  # Get upstream remote and branch if it exists, otherwise default to 'origin' and current branch
  UPSTREAM_INFO=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
  if [[ -n "$UPSTREAM_INFO" ]]; then
  UPSTREAM_REMOTE="${UPSTREAM_INFO%%/*}"
  UPSTREAM_BRANCH="${UPSTREAM_INFO#*/}"
  else
  UPSTREAM_REMOTE="origin"
  UPSTREAM_BRANCH="$CURRENT_BRANCH"
  fi

  echo "Pushing to $UPSTREAM_REMOTE/$UPSTREAM_BRANCH..."
  git push "$UPSTREAM_REMOTE" "$CURRENT_BRANCH" --force-with-lease

  if [[ $? -ne 0 ]]; then
  echo "Error: Git push failed. Please check your permissions and connectivity."
  echo "You may need to run 'git push --force-with-lease' manually."
  else
  echo "Successfully pushed squashed commits to remote."
  fi

# Clean up the backup file created by sed (optional)
rm -f "$(git rev-parse --git-dir)/rebase-merge/git-rebase-todo.bak"
echo "Script finished."
