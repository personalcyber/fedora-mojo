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
    git clone --depth 1 https://github.com/Homebrew/brew "$HOME/.homebrew"
    echo "Homebrew installed at $HOME/.homebrew"
    echo "Add this to your shell profile to start using it:"
    echo "  eval \"\$($HOME/.homebrew/bin/brew shellenv)\""
    echo "Note: this is a private install outside Homebrew's standard prefix," >&2
    echo "so prebuilt bottles won't apply — most 'brew install' runs will build" >&2
    echo "from source and may be slower or fail for formulae needing extra" >&2
    echo "build dependencies. See docs/adr/0002-isolated-homebrew-per-brew-group-user.md." >&2
