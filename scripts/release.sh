#!/usr/bin/env bash
set -e

VERSION="$1"
if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/release.sh <version>"
  echo "Example: ./scripts/release.sh 0.1.5"
  exit 1
fi

# Update plugin.cfg
sed -i '' "s/^version=\".*\"/version=\"$VERSION\"/" addons/leadr/plugin.cfg

# Update version.gd
sed -i '' "s/^const VALUE := \".*\"/const VALUE := \"$VERSION\"/" addons/leadr/internal/version.gd

# Update project.godot
sed -i '' "s/^config\/version=\".*\"/config\/version=\"$VERSION\"/" project.godot

echo "Updated version to $VERSION in all files"

# Commit and tag
git add -A
git commit -m "Bump version to $VERSION"
git tag "v$VERSION"

# Create ZIP
./scripts/bundle.sh "v$VERSION"

echo ""
echo "Ready! Run these to publish:"
echo "  git push && git push --tags"
echo "  gh release create v$VERSION leadr-sdk-godot-v$VERSION.zip --title \"v$VERSION\" --generate-notes"
