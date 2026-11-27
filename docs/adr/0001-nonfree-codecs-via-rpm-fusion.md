# Bundle patent-encumbered multimedia codecs via RPM Fusion

This image enables RPM Fusion (free + nonfree) and installs full `ffmpeg` plus both `intel-media-driver` and `libva-intel-driver` for hardware video decode, rather than shipping only Fedora's patent-safe default codec set. We chose this despite the image being otherwise FOSS-first and publicly distributed via GHCR, because "enhanced multimedia support" was an explicit requirement and the target hardware (legacy and modern Intel Chromebooks) needs working hardware-accelerated decode for everyday media playback to be usable.
