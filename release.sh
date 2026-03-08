#!/bin/bash
set -e  # Abort immediately if any command fails

# release.sh — creates a versioned git tag and GitHub release.
#
# Usage:
#   1. Edit VERSION file  (e.g. echo "3.2.0" > VERSION)
#   2. Update CHANGELOG.md  with a matching ## v3.2.0 section
#   3. Run: ./release.sh
#
# Requirements:
#   - git  (already present)
#   - gh   (GitHub CLI — install with: brew install gh)
#   - Must be authenticated: gh auth login

VERSION=$(cat VERSION | tr -d '[:space:]')

if [ -z "$VERSION" ]; then
    echo "Error: VERSION file is empty."
    exit 1
fi

TAG="v$VERSION"

# Safety check: don't overwrite an existing tag
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Error: tag $TAG already exists. Update VERSION to a new value."
    exit 1
fi

echo "Releasing $TAG..."

git add VERSION CHANGELOG.md
git commit -m "chore(release): $TAG"
git tag -a "$TAG" -m "$TAG"
git push origin main --tags

gh release create "$TAG" \
    --title "$TAG" \
    --notes "See [CHANGELOG.md](./CHANGELOG.md) for release notes."

echo ""
echo "✓ Released $TAG"
echo "  → https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/$TAG"
