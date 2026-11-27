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

check_recipe_syntax() {
  local recipe="$1"
  check "ujust $recipe recipe present and syntactically valid" \
    "set -o pipefail; ujust --list | grep -qw '$recipe' && just --justfile /usr/share/fedora-mojo/justfile --show '$recipe' | awk -v r='$recipe:' '\$0==r{found=1; next} found' | bash -n"
}

check "Budgie desktop package present" \
  "rpm -q budgie-desktop-environment || rpm -q budgie-desktop"

check "ujust command present" \
  "command -v ujust"

check_recipe_syntax "update"

check "FreeIPA client package present" \
  "rpm -q freeipa-client"

check_recipe_syntax "brew-setup"

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed."
  exit 1
fi

echo "All checks passed."
