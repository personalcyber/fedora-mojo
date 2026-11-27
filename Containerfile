FROM quay.io/fedora/fedora-budgie-atomic:45

LABEL org.opencontainers.image.title="fedora-mojo" \
      org.opencontainers.image.description="Custom Fedora Atomic build with FreeIPA"

RUN dnf install -y just freeipa-client git alsa-sof-firmware alsa-ucm && dnf clean all

# Chromebook-specific ALSA UCM profiles not yet upstreamed into alsa-ucm-conf,
# pinned to an exact commit (tag 0.8's SHA — a git tag ref is not immutable,
# unlike a commit SHA). Everything must land under ucm2/conf.d/ — alsa-lib's
# resolver has the legacy flat ucm2/<name>/ lookup disabled by default
# (Define.V2Name "" in ucm.conf), so a flat copy is silently inert.
# Only sof-glkda7219ma is taken from overrides/: the rest (avs_*) target the
# AVS driver, which this image's forced SOF dsp_driver setting never loads.
# `-n` (no-clobber) is deliberate: codecs/hda/ in this overlay collides with
# alsa-ucm's own codecs/hda/, and a plain `cp -r` overwrites it in place —
# which, because alsa-ucm ships many files as hardlinks to shared content,
# silently corrupted an unrelated board's config (verified directly: a stray
# cp -r here rewrote /usr/share/alsa/ucm2/Intel/sof-glkda7219max/
# sof-glkda7219max.conf to generic stub content). -n guarantees we only ever
# add new files, never touch anything alsa-ucm already owns.
#
# `set -e` makes the whole script fail-fast on any step (mkdir/git/cp/test),
# which earlier && / ; mixing in this RUN did not do: if git fetch or a cp
# failed, execution could still reach past it via the trailing ; statements
# and the overall RUN could exit 0 anyway, silently shipping an image
# without the overlay. The rpm -V capture is the one expected exception —
# it always exits nonzero whenever any verify difference exists, including
# the harmless T-only ones container layering always produces — so its
# `|| true` lives *inside* the command substitution, neutralizing just that
# one expected nonzero exit without weakening set -e for anything else. The
# explicit `test -f` afterward independently proves the override landed.
RUN set -eu; \
    mkdir /tmp/alsa-ucm-conf-cros; \
    cd /tmp/alsa-ucm-conf-cros; \
    git init -q; \
    git fetch --depth 1 -q https://github.com/WeirdTreeThing/alsa-ucm-conf-cros a4e92135fd49e669b5ce096439289e05e25ae90c; \
    git checkout -q FETCH_HEAD; \
    cp -rn /tmp/alsa-ucm-conf-cros/ucm2/. /usr/share/alsa/ucm2/; \
    cp -rn /tmp/alsa-ucm-conf-cros/overrides/sof-glkda7219ma /usr/share/alsa/ucm2/conf.d/; \
    cd /; \
    rm -rf /tmp/alsa-ucm-conf-cros; \
    test -f /usr/share/alsa/ucm2/conf.d/sof-glkda7219ma/HiFi.conf; \
    rpm -q alsa-ucm > /dev/null; \
    raw="$(rpm -V alsa-ucm 2>&1 || true)"; \
    bad="$(printf '%s\n' "$raw" | grep -v '^\.\{7\}T\. ' || true)"; \
    [ -n "$raw" ] && [ -z "$bad" ] || { echo "alsa-ucm integrity check failed. Raw output: $raw"; exit 1; }

COPY conf/modprobe.d/inteldspcfg.conf /etc/modprobe.d/inteldspcfg.conf

# RPM Fusion for full ffmpeg + both Intel VAAPI drivers, per ADR-0001: a
# deliberate licensing trade-off accepted for complete codec/hardware-decode
# coverage across legacy (i965) and modern (iHD) Intel graphics.
#
# The release RPMs are checksum-pinned (matching the base image's own fixed
# "45" tag) before dnf ever touches them — there's no prior trust to check
# a GPG signature against the first time, since installing these IS what
# establishes that trust for everything RPM Fusion ships afterward.
#
# --allowerasing lets dnf remove whatever it needs to resolve the
# ffmpeg-free -> ffmpeg conflict. Rather than just document the expected
# removal set, this enforces it: diffs the full installed-package list
# before/after and fails the build if anything beyond ffmpeg-free's own 7
# split libraries gets removed.
#
# The repos are disabled (not removed) immediately after use, so a later
# `dnf`/`bootc` operation can't silently pull more from RPM Fusion without
# deliberately re-enabling it — the packages already installed stay put.
RUN set -eu; \
    curl -fsSL -o /tmp/rpmfusion-free.rpm https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-45.noarch.rpm; \
    echo '761100efc44f57e16dadec1780582f725028e212593740e955dbc7d5b2de81bb  /tmp/rpmfusion-free.rpm' | sha256sum -c -; \
    curl -fsSL -o /tmp/rpmfusion-nonfree.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-45.noarch.rpm; \
    echo '04582bbbb8edf54cc5340d807fb57ae44fea2e8c513b1928a9637b518817328e  /tmp/rpmfusion-nonfree.rpm' | sha256sum -c -; \
    dnf install -y /tmp/rpmfusion-free.rpm /tmp/rpmfusion-nonfree.rpm; \
    rm -f /tmp/rpmfusion-free.rpm /tmp/rpmfusion-nonfree.rpm; \
    rpm -qa --qf '%{NAME}\n' | sort > /tmp/pkgs-before.txt; \
    dnf swap -y ffmpeg-free ffmpeg --allowerasing; \
    rpm -qa --qf '%{NAME}\n' | sort > /tmp/pkgs-after.txt; \
    removed="$(comm -23 /tmp/pkgs-before.txt /tmp/pkgs-after.txt)"; \
    rm -f /tmp/pkgs-before.txt /tmp/pkgs-after.txt; \
    allowed_sorted="$(printf '%s\n' ffmpeg-free libavcodec-free libavdevice-free libavfilter-free libavformat-free libavutil-free libswresample-free libswscale-free | sort)"; \
    removed_sorted="$(printf '%s\n' "$removed" | sort)"; \
    if [ "$removed_sorted" != "$allowed_sorted" ]; then \
      echo "Unexpected package removal during ffmpeg swap. Removed: $removed"; \
      exit 1; \
    fi; \
    dnf install -y intel-media-driver libva-intel-driver; \
    dnf config-manager disable rpmfusion-free rpmfusion-free-updates rpmfusion-nonfree rpmfusion-nonfree-updates; \
    dnf clean all

# ArtCraft office apps (AppImage), downloaded and checksum-verified against
# the sha256 captured directly from getartcraft.com/apps at commit time.
RUN set -eu; \
    mkdir -p /usr/share/artcraft; \
    curl -fsSL -o /usr/share/artcraft/wordcraft.AppImage https://github.com/storytold/wordcraft/releases/download/v0.19.1/wordcraft-0.19.1-linux-x86_64.AppImage; \
    echo '10176ffa8b8b4e0d298516c656b201959bb8280444f059d7b8838b6a691590de  /usr/share/artcraft/wordcraft.AppImage' | sha256sum -c -; \
    curl -fsSL -o /usr/share/artcraft/gridcraft.AppImage https://github.com/storytold/gridcraft/releases/download/v0.19.1/gridcraft-0.19.1-linux-x86_64.AppImage; \
    echo '5b1ce10ad6c7a2d389249dfd259010014a85fce1aa42c627fc4cda571671e221  /usr/share/artcraft/gridcraft.AppImage' | sha256sum -c -; \
    curl -fsSL -o /usr/share/artcraft/deckcraft.AppImage https://github.com/storytold/deckcraft/releases/download/v0.19.1/deckcraft-0.19.1-linux-x86_64.AppImage; \
    echo '8295d0fb795bbd0c7ab8ae97cdf0993e1e6cf14d90aac35aab78b816dcdaa2fe  /usr/share/artcraft/deckcraft.AppImage' | sha256sum -c -; \
    curl -fsSL -o /usr/share/artcraft/pdfcraft.AppImage https://github.com/storytold/pdfcraft/releases/download/v0.22.0/pdfcraft-0.22.0-linux-x86_64.AppImage; \
    echo '771f61b07aaf8cc17e73cb1f93fbe88526f27b0aa82ff32d0710e2c375f49248  /usr/share/artcraft/pdfcraft.AppImage' | sha256sum -c -; \
    chmod +x /usr/share/artcraft/*.AppImage

# Gear Lever for AppImage desktop integration (icons, launchers, updates).
# Only officially distributed via Flathub. Pinned to a specific commit
# (captured via `flatpak remote-info flathub it.mijorus.gearlever`) for the
# same reproducibility reason as every other external fetch in this file —
# `flatpak update --commit=` after the initial install is the verified way
# to pin a Flatpak, since `flatpak install <ref> <commit>` rejects a raw
# commit hash as an invalid app id.
#
# The flathub remote is deliberately left enabled afterward, unlike
# RPM Fusion: this repo's own spec calls for Flathub to be a persistent,
# explicitly-configured remote available to end users (that's the whole
# point of the separate Flatpak/Flathub ticket), not a one-time
# build-time-only source the way RPM Fusion is.
RUN flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
    flatpak install -y --system flathub it.mijorus.gearlever && \
    flatpak update -y --system --commit=76f4b07aefffc823b3605f9ce11fb9bb9b8beb36e6082ad390408bc7ec778835 it.mijorus.gearlever

# LibreOffice and Thunderbird ship by default on Fedora's traditional Budgie
# Spin, but are NOT actually present on this Atomic image (verified
# directly: zero matching packages). Removed anyway, defensively, so the
# image stays correct if a future Fedora release starts including them.
RUN dnf remove -y 'libreoffice*' 'thunderbird*'

COPY justfile /usr/share/fedora-mojo/justfile
COPY scripts/ujust /usr/bin/ujust
RUN chmod +x /usr/bin/ujust
