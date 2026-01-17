#!/usr/bin/env bash
set -euo pipefail

# REPLACE: Update these variables for your repository
REPO="my-org/myapp"
VERSION_FILE="$(dirname "$0")/version.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the latest release version from GitHub
# REPLACE: Adjust if your binary source uses a different release mechanism
get_latest_version() {
  local releases
  releases=$(curl -s "https://api.github.com/repos/$REPO/releases")

  # Filter for non-prerelease, non-draft releases and get the first one
  echo "$releases" | jq -r '
    [.[] | select(.prerelease == false and .draft == false)] |
    .[0].tag_name // empty
  ' | sed 's/^v//'
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

# Fetch hash for a specific platform
# REPLACE: Update URL pattern to match your binary source
fetch_hash() {
  local version="$1"
  local platform="$2"
  local ext="$3"
  local url="https://example.com/releases/v${version}/myapp-${platform}.${ext}"

  echo -e "${YELLOW}Fetching hash for $platform...${NC}" >&2
  local hash
  hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null)
  hash_to_sri "$hash"
}

# Update version.json with new version and hashes
update_version_file() {
  local new_version="$1"

  echo -e "${GREEN}Updating to version $new_version${NC}"

  # Fetch hashes for all platforms
  # REPLACE: Adjust platform names and extensions to match your binary source
  local hash_x86_64_linux hash_aarch64_linux hash_x86_64_darwin hash_aarch64_darwin

  hash_x86_64_linux=$(fetch_hash "$new_version" "linux-x64" "tar.gz")
  hash_aarch64_linux=$(fetch_hash "$new_version" "linux-arm64" "tar.gz")
  hash_x86_64_darwin=$(fetch_hash "$new_version" "darwin-x64" "zip")
  hash_aarch64_darwin=$(fetch_hash "$new_version" "darwin-arm64" "zip")

  # Update version.json
  jq --arg version "$new_version" \
     --arg x86_64_linux "$hash_x86_64_linux" \
     --arg aarch64_linux "$hash_aarch64_linux" \
     --arg x86_64_darwin "$hash_x86_64_darwin" \
     --arg aarch64_darwin "$hash_aarch64_darwin" \
     '.version = $version |
      .hashes["x86_64-linux"] = $x86_64_linux |
      .hashes["aarch64-linux"] = $aarch64_linux |
      .hashes["x86_64-darwin"] = $x86_64_darwin |
      .hashes["aarch64-darwin"] = $aarch64_darwin' \
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
