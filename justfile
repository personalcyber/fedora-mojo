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

# Toggle a Chromebook-style keyboard layout on/off: top row becomes
# browser/media keys, and AltGr fills in the keys these keyboards lack
# outright (AltGr+Backspace = Delete, AltGr+arrows = Home/End/PgUp/PgDn).
# Uses xkeyboard-config's own upstream "chromebook" XKB model (set via
# localectl, so it applies to both X11 and Wayland/labwc sessions)
# rather than a hand-rolled remap -- it already defines exactly this.
chromebook-keyboard:
    #!/usr/bin/env bash
    set -euo pipefail
    current_layout="$(localectl status | awk -F': ' '/X11 Layout/{print $2}')"
    current_model="$(localectl status | awk -F': ' '/X11 Model/{print $2}')"
    # localectl prints the literal string "(unset)", not an empty value,
    # when nothing has been configured yet.
    if [ -z "$current_layout" ] || [ "$current_layout" = "(unset)" ]; then
        current_layout="us"
    fi
    if [ "$current_model" = "chromebook" ]; then
        sudo localectl set-x11-keymap "$current_layout" ""
        echo "Chromebook keyboard layout disabled. Standard layout restored."
    else
        sudo localectl set-x11-keymap "$current_layout" chromebook
        echo "Chromebook keyboard layout enabled: top row -> browser/media keys;"
        echo "AltGr+Backspace = Delete; AltGr+Up/Down/Left/Right = PgUp/PgDn/Home/End."
    fi
    echo "Log out and back in for the change to take effect."

# Add the bundled ArtCraft office apps (WordCraft, GridCraft, DeckCraft,
# PdfCraft) to your application menu. The AppImages themselves are always
# present at /usr/share/artcraft -- this just opts your own menu in, so
# the apps don't clutter every user's launcher unconditionally.
install-apps:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$HOME/.local/share/applications"
    shopt -s nullglob
    staged=(/usr/share/artcraft/desktop/*.desktop)
    if [ ${#staged[@]} -eq 0 ]; then
        echo "No ArtCraft apps are staged on this image." >&2
        exit 1
    fi
    for f in "${staged[@]}"; do
        cp "$f" "$HOME/.local/share/applications/"
        echo "Installed: $(basename "$f" .desktop)"
    done
    echo "ArtCraft apps added to your application menu."

# Factory-reset this machine's shared environment: deletes local
# (non-FreeIPA) user accounts, Flatpaks installed beyond the image
# baseline, every user's private Homebrew install, and this machine's
# Tailscale network join. FreeIPA-managed identities are never touched --
# FreeIPA is the system of record for this fleet, not this recipe.
# Destructive and irreversible; requires sudo and a typed confirmation.
reset-system:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(id -u)" -ne 0 ]; then
        echo "This resets the whole machine's shared environment -- run it with sudo." >&2
        exit 1
    fi

    echo "This will PERMANENTLY:"
    echo "  - delete all local (non-FreeIPA) user accounts and their home directories"
    echo "  - remove Flatpak apps installed beyond this image's baseline"
    echo "  - remove every user's private Homebrew install (~/.homebrew)"
    echo "  - leave this machine's Tailscale network"
    echo
    read -rp "Type RESET to continue: " confirm
    if [ "$confirm" != "RESET" ]; then
        echo "Aborted; nothing was changed."
        exit 1
    fi

    invoking_user="${SUDO_USER:-}"

    echo "==> Removing local (non-FreeIPA) user accounts..."
    while IFS=: read -r name _ uid _; do
        if [ "$uid" -lt 1000 ] || [ "$uid" -ge 60000 ]; then
            continue
        fi
        if [ "$name" = "$invoking_user" ]; then
            echo "  skipping $name (the account running this recipe)"
            continue
        fi
        echo "  removing $name"
        userdel -r "$name" 2>/dev/null || echo "    (failed to fully remove $name -- check for running processes)"
    done < <(getent -s files passwd)

    echo "==> Removing Flatpaks installed beyond the image baseline..."
    baseline_apps=$'com.github.tchx84.Flatseal\nit.mijorus.gearlever'
    for app in $(flatpak list --system --columns=application); do
        if ! grep -qxF "$app" <<< "$baseline_apps"; then
            echo "  removing $app"
            flatpak uninstall --system -y "$app" || true
        fi
    done
    flatpak uninstall --system --unused -y || true

    echo "==> Removing private Homebrew installs..."
    for home in /home/*; do
        [ -d "$home/.homebrew" ] || continue
        echo "  removing $home/.homebrew"
        rm -rf "$home/.homebrew"
    done

    echo "==> Leaving the Tailscale network..."
    tailscale down || true

    echo "Reset complete."

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
