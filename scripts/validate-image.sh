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

check "alsa-sof-firmware package present" \
  "rpm -q alsa-sof-firmware"

check "alsa-ucm package present" \
  "rpm -q alsa-ucm"

check "alsa-ucm-conf-cros overlay file present" \
  "test -f /usr/share/alsa/ucm2/conf.d/sof-rt5682/sof-rt5682.conf"

check "alsa-ucm-conf-cros override file present" \
  "test -f /usr/share/alsa/ucm2/conf.d/sof-glkda7219ma/HiFi.conf"

check "snd_intel_dspcfg modprobe safety net present" \
  "grep -qx 'options snd-intel-dspcfg dsp_driver=3' /etc/modprobe.d/inteldspcfg.conf"

check_recipe_syntax "chromebook-keyboard"

check "RPM Fusion free release package present" \
  "rpm -q rpmfusion-free-release"

check "RPM Fusion nonfree release package present" \
  "rpm -q rpmfusion-nonfree-release"

check "RPM Fusion repos disabled after use" \
  "! dnf repolist --enabled 2>/dev/null | grep -qi rpmfusion"

check "full ffmpeg installed (not the patent-safe default)" \
  "rpm -q ffmpeg && ! rpm -q ffmpeg-free"

check "intel-media-driver (iHD) present" \
  "rpm -q intel-media-driver"

check "libva-intel-driver (legacy i965) present" \
  "rpm -q libva-intel-driver"

check "WordCraft AppImage present" \
  "test -x /usr/share/artcraft/wordcraft.AppImage"

check "GridCraft AppImage present" \
  "test -x /usr/share/artcraft/gridcraft.AppImage"

check "DeckCraft AppImage present" \
  "test -x /usr/share/artcraft/deckcraft.AppImage"

check "PdfCraft AppImage present" \
  "test -x /usr/share/artcraft/pdfcraft.AppImage"

check "Gear Lever present" \
  "flatpak list --system --columns=application | grep -qx it.mijorus.gearlever"

check "Gear Lever pinned to the expected commit" \
  "[ \"\$(flatpak info --system --show-commit it.mijorus.gearlever)\" = 76f4b07aefffc823b3605f9ce11fb9bb9b8beb36e6082ad390408bc7ec778835 ]"

check "org.gnome.Platform runtime pinned to the expected commit" \
  "[ \"\$(flatpak info --system --show-commit org.gnome.Platform//50)\" = ac43a2a40ddb855048f7d8e42c1cfd6ae2d0ad7d88b09939f5dc371a3735f464 ]"

check "org.freedesktop.Platform.GL.default//25.08 pinned to the expected commit" \
  "[ \"\$(flatpak info --system --show-commit org.freedesktop.Platform.GL.default//25.08)\" = faea141e54b9c74e75d571e3b001d6a80f2b6757221fd8f29b937ff2486ee2b9 ]"

check "org.freedesktop.Platform.GL.default//25.08-extra pinned to the expected commit" \
  "[ \"\$(flatpak info --system --show-commit org.freedesktop.Platform.GL.default//25.08-extra)\" = ea550d0bdbaa416e3b9dbd51a55f5f73612e7c3fe9b1d3733791ed4004f3020b ]"

check "org.freedesktop.Platform.VAAPI.Intel//25.08 pinned to the expected commit" \
  "[ \"\$(flatpak info --system --show-commit org.freedesktop.Platform.VAAPI.Intel//25.08)\" = f68c296a49c549b75e104104d9e602b8d2992ccb94a9c3482a40b09e6d6492d7 ]"

check "org.freedesktop.Platform.codecs-extra//25.08-extra pinned to the expected commit" \
  "[ \"\$(flatpak info --system --show-commit org.freedesktop.Platform.codecs-extra//25.08-extra)\" = 3bf3b955b0227dc63cc89d9b450a03559cf0700b6e04eeb08964d39642dc58ad ]"

check "Flathub remote explicitly configured" \
  "flatpak remotes --system --columns=name | grep -qx flathub"

check "No unexpected flatpak refs beyond the pinned/known set" \
  "expected=\$(printf '%s\n' com.github.tchx84.Flatseal/x86_64/stable it.mijorus.gearlever/x86_64/stable org.freedesktop.Platform.GL.default/x86_64/25.08 org.freedesktop.Platform.GL.default/x86_64/25.08-extra org.freedesktop.Platform.VAAPI.Intel/x86_64/25.08 org.freedesktop.Platform.codecs-extra/x86_64/25.08-extra org.gnome.Platform/x86_64/50 | sort); [ \"\$(flatpak list --system --columns=ref | sort)\" = \"\$expected\" ]"

check "Flatseal present" \
  "flatpak list --system --columns=application | grep -qx com.github.tchx84.Flatseal"

check "Flatseal pinned to the expected commit" \
  "[ \"\$(flatpak info --system --show-commit com.github.tchx84.Flatseal)\" = ef9fe38e9cb96c170ea579fe1bbf8c76011255d4962d7fc4b3aa4e0a6063f8ae ]"

check "LibreOffice absent" \
  "! rpm -qa | grep -qi libreoffice"

check "Thunderbird absent" \
  "! rpm -qa | grep -qi thunderbird"

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed."
  exit 1
fi

echo "All checks passed."
