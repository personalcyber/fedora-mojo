#!/usr/bin/env bash
# Build a bootable installer ISO from a published (or local) fedora-mojo
# image via bootc-image-builder. See README.md's "Build an installable
# ISO" section for the full explanation and config.toml.example for the
# bootstrap-user customization this expects.
set -euo pipefail

IMAGE="${1:-ghcr.io/personalcyber/fedora-mojo:latest}"
CONFIG="${2:-config.toml}"
OUTPUT_DIR="${3:-output}"

if [ ! -f "$CONFIG" ]; then
    echo "No $CONFIG found." >&2
    echo "Copy config.toml.example to $CONFIG and fill in a real SSH key" >&2
    echo "and/or password hash first -- see README.md for how to generate" >&2
    echo "one. config.toml is gitignored on purpose: never commit it." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# --privileged + the containers/storage bind mount are how
# bootc-image-builder works with loop devices and reuses the local image
# store; --security-opt is needed under SELinux enforcing, same as
# every published example of this command, and is a no-op otherwise.
exec sudo podman run --rm -it \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "$(pwd)/$OUTPUT_DIR:/output" \
    -v "$(pwd)/$CONFIG:/config.toml:ro" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type iso \
    --config /config.toml \
    "$IMAGE"
