#!/usr/bin/env sh
# Push mergecalib to GitHub. Run from the package root.
# The remote 'origin' is already set to:
#   https://github.com/makunxiang-cmd/mergecalib.git
set -e

REMOTE_URL="https://github.com/makunxiang-cmd/mergecalib.git"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository. Run this from the package root." >&2
  exit 1
fi

# Ensure the remote exists and is correct.
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE_URL"
else
  git remote add origin "$REMOTE_URL"
fi

# Ensure we are on main.
git branch -M main

echo "Pushing to $REMOTE_URL ..."
git push -u origin main
echo "Done. If prompted, authenticate with a GitHub PAT or 'gh auth login'."
