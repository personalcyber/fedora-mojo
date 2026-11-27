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
# The integrity-check tail below deliberately uses `;` (not `&&`) between the
# two capture lines: `var="$(rpm -V pkg)"` inherits rpm -V's own exit status
# (verified directly in dash), and rpm -V ALWAYS exits nonzero whenever any
# verify difference exists — including the harmless T-only ones this build
# always produces, since container layering touches mtimes on the whole
# tree. Chaining those captures with && would abort the build on every
# single build, even the clean case. The actual pass/fail decision is the
# final unconditional check, which only looks at content (never an exit
# code): it also requires $raw to be non-empty, so a silent rpm -V failure
# (no output on either stream) is treated as a failure too, not a pass.
RUN mkdir /tmp/alsa-ucm-conf-cros && cd /tmp/alsa-ucm-conf-cros && \
    git init -q && \
    git fetch --depth 1 -q https://github.com/WeirdTreeThing/alsa-ucm-conf-cros a4e92135fd49e669b5ce096439289e05e25ae90c && \
    git checkout -q FETCH_HEAD && \
    cp -rn /tmp/alsa-ucm-conf-cros/ucm2/. /usr/share/alsa/ucm2/ && \
    cp -rn /tmp/alsa-ucm-conf-cros/overrides/sof-glkda7219ma /usr/share/alsa/ucm2/conf.d/ && \
    cd / && rm -rf /tmp/alsa-ucm-conf-cros && \
    rpm -q alsa-ucm > /dev/null && \
    raw="$(rpm -V alsa-ucm 2>&1)"; \
    bad="$(echo "$raw" | grep -v '^\.\{7\}T\. ' || true)"; \
    { [ -n "$raw" ] && [ -z "$bad" ]; } || { echo "alsa-ucm integrity check failed. Raw output: $raw"; exit 1; }

COPY conf/modprobe.d/inteldspcfg.conf /etc/modprobe.d/inteldspcfg.conf

COPY justfile /usr/share/fedora-mojo/justfile
COPY scripts/ujust /usr/bin/ujust
RUN chmod +x /usr/bin/ujust
