FROM quay.io/fedora/fedora-budgie-atomic:45

LABEL org.opencontainers.image.title="fedora-mojo" \
      org.opencontainers.image.description="Custom Fedora Atomic build with FreeIPA"

RUN dnf install -y just freeipa-client git alsa-sof-firmware alsa-ucm && dnf clean all

# Chromebook-specific ALSA UCM profiles not yet upstreamed into alsa-ucm-conf,
# pinned to a reviewed release tag. Everything must land under ucm2/conf.d/ —
# alsa-lib's resolver has the legacy flat ucm2/<name>/ lookup disabled by
# default (Define.V2Name "" in ucm.conf), so a flat copy is silently inert.
# Only sof-glkda7219ma is taken from overrides/: the rest (avs_*) target the
# AVS driver, which this image's forced SOF dsp_driver setting never loads.
RUN git clone --depth 1 --branch 0.8 https://github.com/WeirdTreeThing/alsa-ucm-conf-cros /tmp/alsa-ucm-conf-cros && \
    cp -r /tmp/alsa-ucm-conf-cros/ucm2/. /usr/share/alsa/ucm2/ && \
    cp -r /tmp/alsa-ucm-conf-cros/overrides/sof-glkda7219ma /usr/share/alsa/ucm2/conf.d/ && \
    rm -rf /tmp/alsa-ucm-conf-cros

COPY conf/modprobe.d/inteldspcfg.conf /etc/modprobe.d/inteldspcfg.conf

COPY justfile /usr/share/fedora-mojo/justfile
COPY scripts/ujust /usr/bin/ujust
RUN chmod +x /usr/bin/ujust
