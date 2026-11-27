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
# --allowerasing lets dnf remove whatever it needs to resolve the
# ffmpeg-free -> ffmpeg conflict. Verified directly (diffed the full
# installed-package list before/after on this exact base image) that it
# removes exactly ffmpeg-free's own 7 split libraries (libavcodec-free,
# libavdevice-free, libavfilter-free, libavformat-free, libavutil-free,
# libswresample-free, libswscale-free) and nothing else — no unrelated
# collateral removal on this image.
RUN FEDVER="$(rpm -E %fedora)" && \
    dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDVER}.noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDVER}.noarch.rpm" && \
    dnf swap -y ffmpeg-free ffmpeg --allowerasing && \
    dnf install -y intel-media-driver libva-intel-driver && \
    dnf clean all

COPY justfile /usr/share/fedora-mojo/justfile
COPY scripts/ujust /usr/bin/ujust
RUN chmod +x /usr/bin/ujust
