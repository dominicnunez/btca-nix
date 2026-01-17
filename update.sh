#!/usr/bin/env bash
set -euo pipefail

# npm package name
NPM_PACKAGE="btca"
VERSION_FILE="$(dirname "$0")/version.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the latest release version from npm registry
get_latest_version() {
  curl -s "https://registry.npmjs.org/${NPM_PACKAGE}/latest" | jq -r '.version // empty'
}

# Get the current version from version.json
get_current_version() {
  jq -r '.version' "$VERSION_FILE"
}

# Convert base32 hash to SRI format
hash_to_sri() {
  local hash="$1"
  nix hash convert --hash-algo sha256 --to sri "$hash"
}

# Fetch hash for npm tarball (single tarball for all platforms)
fetch_hash() {
  local version="$1"
  local url="https://registry.npmjs.org/${NPM_PACKAGE}/-/${NPM_PACKAGE}-${version}.tgz"

  echo -e "${YELLOW}Fetching hash for btca v${version}...${NC}" >&2
  local hash
  hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null)
  hash_to_sri "$hash"
}

# Update version.json with new version and hash (single tarball for all platforms)
update_version_file() {
  local new_version="$1"

  echo -e "${GREEN}Updating to version $new_version${NC}"

  # Fetch single hash for npm tarball (contains all platform binaries)
  local hash
  hash=$(fetch_hash "$new_version")

  # Update version.json with single hash
  jq --arg version "$new_version" \
     --arg hash "$hash" \
     '.version = $version | .hash = $hash' \
     "$VERSION_FILE" > "${VERSION_FILE}.tmp" && mv "${VERSION_FILE}.tmp" "$VERSION_FILE"

  echo -e "${GREEN}Successfully updated version.json${NC}"
}

# Main script
main() {
  local current_version latest_version

  current_version=$(get_current_version)
  latest_version=$(get_latest_version)

  if [[ -z "$latest_version" ]]; then
    echo -e "${RED}Failed to fetch latest version${NC}"
    exit 1
  fi

  echo "Current version: $current_version"
  echo "Latest version:  $latest_version"

  if [[ "$current_version" == "$latest_version" ]]; then
    echo -e "${GREEN}Already up to date${NC}"
    echo "UPDATE_NEEDED=false"
    exit 0
  fi

  echo -e "${YELLOW}Update available: $current_version -> $latest_version${NC}"
  echo "UPDATE_NEEDED=true"
  echo "NEW_VERSION=$latest_version"

  # If --update flag is passed, perform the update
  if [[ "${1:-}" == "--update" ]]; then
    update_version_file "$latest_version"
  else
    echo -e "${YELLOW}Run with --update to apply the update${NC}"
  fi
}

main "$@"
