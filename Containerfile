FROM quay.io/fedora/fedora-budgie-atomic:45

LABEL org.opencontainers.image.title="fedora-mojo" \
      org.opencontainers.image.description="Custom Fedora Atomic build with FreeIPA"

RUN dnf install -y just freeipa-client && dnf clean all

COPY justfile /usr/share/fedora-mojo/justfile
COPY scripts/ujust /usr/bin/ujust
RUN chmod +x /usr/bin/ujust
