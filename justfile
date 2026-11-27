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

# Switch Budgie's panel layout to resemble Windows (bottom taskbar + start
# menu), macOS (top menu bar + bottom dock), or GNOME (single top bar).
# Takes effect immediately for most applets; log out and back in if the
# panel doesn't fully refresh on its own.
desktop-layout layout:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{layout}}" in
        windows|macos|gnome) ;;
        *)
            echo "Usage: ujust desktop-layout <windows|macos|gnome>" >&2
            exit 1
            ;;
    esac

    # Only the panels/applets subtrees are reset -- not all of
    # com.solus-project.budgie-panel -- so unrelated prefs (dark-theme,
    # notification-position, etc.) survive a layout switch.
    reset_panel_dconf() {
        dconf reset -f /com/solus-project/budgie-panel/panels/ 2>/dev/null || true
        dconf reset -f /com/solus-project/budgie-panel/applets/ 2>/dev/null || true
    }

    # budgie-panel mounts each panel/applet instance's GSettings at
    # .../panels/{UUID}/ and .../applets/{UUID}/ -- literal curly braces
    # around the uuid, not just the bare uuid (confirmed against
    # panel_plugin_manager_create_applet_path() and
    # Budgie.PanelManager.create_panel_path() in budgie-desktop's own
    # source). The stored *list* entries (the "panels" key and each
    # panel's "applets" key) stay bare uuids -- budgie-panel adds the
    # braces itself when turning a list entry into a settings path; only
    # the path these helpers write to needs them.
    write_panel() {
        local uuid="$1" location="$2" size="$3" dock="$4"; shift 4
        local path="/com/solus-project/budgie-panel/panels/{$uuid}"
        dconf write "$path/location" "'$location'"
        dconf write "$path/size" "$size"
        dconf write "$path/dock-mode" "$dock"
        local list="[" first=1
        for a in "$@"; do
            [ "$first" -eq 1 ] && first=0 || list+=", "
            list+="'$a'"
        done
        dconf write "$path/applets" "${list}]"
    }

    # budgie-panel resolves an applet by its "module" key first (falling
    # back to "name" only if module is unset), matching each plugin's own
    # .plugin keyfile "Module=" value -- NOT the plugin's directory name
    # (e.g. org.budgie-desktop.applet.budgie-menu) and NOT its .plugin
    # filename (e.g. BudgieMenu.plugin). Confirmed against each shipped
    # .plugin file rather than assumed.
    applet_module() {
        case "$1" in
            budgie-menu)   echo "budgiemenuapplet.so" ;;
            icon-tasklist) echo "icontasklistapplet.so" ;;
            tray)          echo "trayapplet.so" ;;
            status)        echo "statusapplet.so" ;;
            raven-trigger) echo "raventriggerapplet.so" ;;
            clock)         echo "clockapplet.so" ;;
            *) echo "desktop-layout: unknown applet '$1'" >&2; exit 1 ;;
        esac
    }

    applet_name() {
        case "$1" in
            budgie-menu)   echo "Budgie Menu" ;;
            icon-tasklist) echo "Icon Task List" ;;
            tray)          echo "System Tray" ;;
            status)        echo "Status Indicator" ;;
            raven-trigger) echo "Raven Trigger" ;;
            clock)         echo "Clock" ;;
            *) echo "desktop-layout: unknown applet '$1'" >&2; exit 1 ;;
        esac
    }

    write_applet() {
        local path="/com/solus-project/budgie-panel/applets/{$1}"
        local module name
        module="$(applet_module "$2")"
        name="$(applet_name "$2")"
        dconf write "$path/module" "'$module'"
        dconf write "$path/name" "'$name'"
        dconf write "$path/alignment" "'$3'"
        dconf write "$path/position" "$4"
    }

    reset_panel_dconf

    case "{{layout}}" in
        windows)
            p1=$(uuidgen)
            a_menu=$(uuidgen); a_tasks=$(uuidgen); a_tray=$(uuidgen); a_status=$(uuidgen); a_raven=$(uuidgen); a_clock=$(uuidgen)
            write_applet "$a_menu" budgie-menu start 0
            write_applet "$a_tasks" icon-tasklist start 1
            write_applet "$a_tray" tray end 0
            write_applet "$a_status" status end 1
            write_applet "$a_raven" raven-trigger end 2
            write_applet "$a_clock" clock end 3
            write_panel "$p1" bottom 46 false "$a_menu" "$a_tasks" "$a_tray" "$a_status" "$a_raven" "$a_clock"
            dconf write /com/solus-project/budgie-panel/panels "['$p1']"
            ;;
        macos)
            p1=$(uuidgen); p2=$(uuidgen)
            a_menu=$(uuidgen); a_tray=$(uuidgen); a_status=$(uuidgen); a_raven=$(uuidgen); a_clock=$(uuidgen); a_dock=$(uuidgen)
            write_applet "$a_menu" budgie-menu start 0
            write_applet "$a_tray" tray end 0
            write_applet "$a_status" status end 1
            write_applet "$a_raven" raven-trigger end 2
            write_applet "$a_clock" clock end 3
            write_applet "$a_dock" icon-tasklist center 0
            write_panel "$p1" top 28 false "$a_menu" "$a_tray" "$a_status" "$a_raven" "$a_clock"
            write_panel "$p2" bottom 58 true "$a_dock"
            dconf write "/com/solus-project/budgie-panel/panels/{$p2}/transparency" "'dynamic'"
            dconf write /com/solus-project/budgie-panel/panels "['$p1', '$p2']"
            ;;
        gnome)
            p1=$(uuidgen)
            a_menu=$(uuidgen); a_clock=$(uuidgen); a_tray=$(uuidgen); a_status=$(uuidgen); a_raven=$(uuidgen)
            write_applet "$a_menu" budgie-menu start 0
            write_applet "$a_clock" clock center 0
            write_applet "$a_tray" tray end 0
            write_applet "$a_status" status end 1
            write_applet "$a_raven" raven-trigger end 2
            write_panel "$p1" top 38 false "$a_menu" "$a_clock" "$a_tray" "$a_status" "$a_raven"
            dconf write /com/solus-project/budgie-panel/panels "['$p1']"
            ;;
    esac

    nohup budgie-panel --replace >/dev/null 2>&1 &
    disown || true
    echo "Applied the {{layout}} layout. If the panel doesn't refresh immediately, log out and back in."

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
