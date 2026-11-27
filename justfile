# fedora-mojo ujust recipes

# Update the system to the latest image
update:
    sudo bootc upgrade

# Bootstrap a private Homebrew install for members of the "brew" group
brew-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! id -nG "$(whoami)" | tr ' ' '\n' | grep -qx brew; then
        echo "You are not a member of the 'brew' group — Homebrew access is restricted to brew-group members." >&2
        exit 1
    fi
    if [ -d "$HOME/.homebrew" ]; then
        echo "Homebrew is already installed at $HOME/.homebrew"
        exit 0
    fi
    # Pinned to an exact commit (tag 7.0.16's SHA — a git tag ref is not
    # immutable, unlike a commit SHA).
    mkdir "$HOME/.homebrew"
    (cd "$HOME/.homebrew" && git init -q && \
        git fetch --depth 1 -q https://github.com/Homebrew/brew 7ef183d10e7d6e5620d7124b744b1dfbf69fc108 && \
        git checkout -q FETCH_HEAD)
    echo "Homebrew installed at $HOME/.homebrew"
    echo "Add this to your shell profile to start using it:"
    echo "  eval \"\$($HOME/.homebrew/bin/brew shellenv)\""
    echo "Note: this is a private install outside Homebrew's standard prefix," >&2
    echo "so prebuilt bottles won't apply — most 'brew install' runs will build" >&2
    echo "from source and may be slower or fail for formulae needing extra" >&2
    echo "build dependencies. See docs/adr/0002-isolated-homebrew-per-brew-group-user.md." >&2

# Toggle a Chromebook-style keyboard layout (Search key, media top row) on/off
chromebook-keyboard:
    #!/usr/bin/env bash
    set -euo pipefail
    HWDB_FILE=/etc/udev/hwdb.d/99-chromebook-keyboard.hwdb
    if [ -f "$HWDB_FILE" ]; then
        sudo rm -f "$HWDB_FILE"
        echo "Chromebook keyboard layout disabled. Standard layout restored."
    else
        {
            echo 'evdev:atkbd:*'
            echo ' KEYBOARD_KEY_3a=search'
            echo ' KEYBOARD_KEY_3b=back'
            echo ' KEYBOARD_KEY_3c=forward'
            echo ' KEYBOARD_KEY_3d=refresh'
            echo ' KEYBOARD_KEY_3e=full_screen'
            echo ' KEYBOARD_KEY_3f=scale'
            echo ' KEYBOARD_KEY_40=brightnessdown'
            echo ' KEYBOARD_KEY_41=brightnessup'
            echo ' KEYBOARD_KEY_42=mute'
            echo ' KEYBOARD_KEY_43=volumedown'
            echo ' KEYBOARD_KEY_44=volumeup'
        } | sudo tee "$HWDB_FILE" > /dev/null
        echo "Chromebook keyboard layout enabled (Search key, media top row)."
    fi
    sudo systemd-hwdb update
    # Best-effort: applying live without a reboot can fail per-device (e.g.
    # permission-restricted sysfs paths); the hwdb update above already
    # landed, so a trigger failure here isn't fatal.
    sudo udevadm trigger --subsystem-match=input --action=change || true
    echo "Re-plug the keyboard or log out and back in if changes don't apply immediately."

# Join your Tailscale network. --operator lets you manage the
# connection afterwards without sudo; --shields-up blocks inbound
# connections from the tailnet by default, since this is a shared
# laptop fleet, not a set of servers meant to accept connections. Run
# `sudo tailscale up --shields-up=false` directly if you need inbound
# access (e.g. to SSH into this machine from elsewhere on the tailnet).
tailscale-up:
    sudo tailscale up --operator="$(whoami)" --shields-up

# Leave your Tailscale network
tailscale-down:
    sudo tailscale down
