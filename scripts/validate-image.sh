#!/usr/bin/env bash
# Validation seam for fedora-mojo: asserts properties of a built image
# by running commands inside it via podman. No VM boot required.
set -euo pipefail

IMAGE="${1:?Usage: validate-image.sh <image-ref>}"

failures=0

check() {
  local description="$1"
  local command="$2"
  local output
  if output=$(podman run --rm "$IMAGE" bash -c "$command" 2>&1); then
    echo "PASS: $description"
  else
    echo "FAIL: $description"
    echo "$output" | sed 's/^/  /'
    failures=$((failures + 1))
  fi
}

check "Budgie desktop package present" \
  "rpm -q budgie-desktop-environment || rpm -q budgie-desktop"

check "ujust command present" \
  "command -v ujust"

check "ujust update recipe present" \
  "ujust --list | grep -qw update"

check "FreeIPA client package present" \
  "rpm -q freeipa-client"

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed."
  exit 1
fi

echo "All checks passed."
