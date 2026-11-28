<p align="center"><img src="assets/logo-landscape.svg" alt="Fedora Mojo" width="600"></p>

# Fedora Mojo

A custom Fedora Atomic (bootc) desktop image for a small fleet of
laptops — including repurposed Chromebooks — joined to a shared
FreeIPA domain. Built on Fedora COSMIC Atomic 45.

## Executive summary

fedora-mojo turns a stock Fedora COSMIC Atomic image into a
ready-to-deploy fleet image for a household or small organization that
wants centrally managed identity, consistent desktop software, and
hardware support for commodity/repurposed laptops (notably
Chromebooks), without the maintenance burden of hand-configuring each
machine.

Every machine built from this image:

- Joins a shared **FreeIPA** domain for centralized user accounts and
  group-based privilege gating (e.g. who gets Homebrew access).
- Gets a **COSMIC** desktop with common productivity and creative
  software pre-installed — no per-machine app installs needed.
- Has working **audio and keyboard support on legacy Chromebook
  hardware**, which upstream Fedora doesn't configure out of the box.
- Can self-update via `ujust update` (a thin wrapper over `bootc
  upgrade`) and join a private network via `ujust tailscale-up`.
- Manages its own Flatpak apps and permissions (Gear Lever, Flatseal)
  without the user needing to know Flatpak's CLI.
- Ships with locked-down Firefox defaults (telemetry off, tracking
  protection on, data cleared on exit) suitable for a shared-household
  or shared-fleet browser, applied automatically with no per-user
  setup.

The image is built reproducibly from a single `Containerfile`: every
external package, binary, and Flatpak it pulls in is pinned to an
exact commit hash or checksum, and a CI pipeline rebuilds and
re-verifies the image on every change before it's published.

## Detailed feature description

### Identity and privilege management

- **FreeIPA client** (`freeipa-client`) is installed so machines can
  be enrolled into a shared FreeIPA domain for centralized Unix
  accounts, group membership, and (optionally) Kerberos/SSO.
- **Brew-group isolated Homebrew.** Membership in the FreeIPA-managed
  `brew` Unix group is what grants a user Homebrew access on this
  image. Running `ujust brew-setup` as a `brew`-group member clones
  Homebrew (pinned to an exact commit) into `$HOME/.homebrew` — a
  private, fully independent install (own core, taps, cellar) per
  user, rather than one shared installation. See
  [`docs/adr/0002-isolated-homebrew-per-brew-group-user.md`](docs/adr/0002-isolated-homebrew-per-brew-group-user.md)
  for the trade-off this made (prebuilt bottles don't apply at this
  non-standard prefix, so most formulae build from source).

### Desktop and applications

- **COSMIC desktop environment**, Fedora's COSMIC Atomic spin as the
  base.
- **ArtCraft** office/creative suite (WordCraft, GridCraft, DeckCraft,
  PdfCraft) installed as checksum-verified AppImages under
  `/usr/share/artcraft/`, with **Gear Lever** (via Flatpak) to give
  users a GUI for integrating and managing AppImages on the desktop.
- **Flatpak app management**: the Flathub remote is configured
  system-wide, and **Flatseal** is installed so users can inspect and
  adjust individual Flatpak apps' sandbox permissions without the CLI.
- **LibreOffice and Thunderbird are explicitly excluded** (not present
  on this Atomic base by default, but removed defensively in case a
  future Fedora release starts bundling them) — the office/creative
  need is covered by ArtCraft instead.
- **Firefox enterprise policy** is baked in at
  `/usr/lib64/firefox/distribution/policies.json`, generated at build
  time from [`policies.yaml`](policies.yaml) via the
  [Firefox Policy Generator](https://github.com/personalcyber/firefox-policy-generator).
  Defaults: telemetry/studies/Pocket disabled, strict tracking
  protection, TLS 1.2 minimum, DNS-over-HTTPS enabled (with plaintext
  fallback deliberately *off* — see the comment in `policies.yaml` for
  how to scope an exception for your FreeIPA domain's internal names),
  sensitive permissions (camera/mic/location/notifications) blocked by
  default, and browsing data cleared on shutdown.

### Hardware support (Chromebooks and Intel graphics)

- **Legacy Chromebook audio**: `alsa-sof-firmware` and `alsa-ucm` are
  installed, plus Chromebook-specific ALSA UCM profiles from
  [alsa-ucm-conf-cros](https://github.com/WeirdTreeThing/alsa-ucm-conf-cros)
  (pinned to an exact commit) that aren't yet upstreamed into Fedora's
  own `alsa-ucm-conf`. A modprobe override forces the SOF DSP driver
  (`snd-intel-dspcfg dsp_driver=3`) so the kernel doesn't instead load
  the incompatible AVS driver on affected hardware.
- **Chromebook keyboard layout**: `ujust chromebook-keyboard` toggles
  xkeyboard-config's own upstream `chromebook` XKB model (applied via
  `localectl`, so it covers both X11 and Wayland/labwc sessions),
  remapping the top row to match a Chromebook's physical keycaps
  (back/forward/refresh/fullscreen, brightness, mute, volume) and
  filling in the keys these keyboards lack outright via AltGr:
  `AltGr+Backspace` = Delete, `AltGr+Up/Down/Left/Right` =
  PageUp/PageDown/Home/End. Running it again restores the standard
  layout.
- **Intel graphics / hardware video decode**: both `intel-media-driver`
  (iHD, modern Intel GPUs) and `libva-intel-driver` (i965, older/
  legacy Intel GPUs found in most Chromebooks) are installed, so
  hardware-accelerated decode works across the whole age range of
  target hardware.
- **Enhanced multimedia**: RPM Fusion (free + nonfree) is enabled just
  long enough to swap in full `ffmpeg` (replacing Fedora's patent-safe
  `ffmpeg-free`) and install the Intel VAAPI drivers above, then
  disabled again — see
  [`docs/adr/0001-nonfree-codecs-via-rpm-fusion.md`](docs/adr/0001-nonfree-codecs-via-rpm-fusion.md)
  for the licensing trade-off this represents.

### Networking and system management

- **Tailscale** (`tailscale` package) ships pre-installed, with the
  `tailscaled` service enabled but not started — joining a tailnet is
  left as a per-machine, per-user decision. `ujust tailscale-up` joins
  (defaulting to `--shields-up`, blocking inbound connections, since
  this is a laptop fleet rather than a set of servers — pass
  `--shields-up=false` directly via `tailscale up` if a machine
  genuinely needs to accept inbound tailnet connections) and `ujust
  tailscale-down` leaves.
- **`ujust` command layer**: a thin, discoverable wrapper (backed by
  [`justfile`](justfile)) around the above operations, so end users
  never need to know the underlying `bootc`/`systemctl`/`git`
  commands. Run `ujust --list` on a deployed machine to see every
  available recipe (`update`, `brew-setup`, `chromebook-keyboard`,
  `tailscale-up`, `tailscale-down`).
- **`bootc upgrade`** via `ujust update` is the supported way to pull
  a newer published image and apply it on next boot — see Deployment
  below.
- **Branded boot splash**: a Plymouth theme shows the Fedora Mojo spark
  mark and wordmark from early boot, so machines running this image
  are clearly identifiable as Fedora Mojo rather than stock Fedora.

### Supply-chain integrity

Every external artifact the build pulls in — git repositories, RPM
Fusion release packages, AppImages, Flatpak refs, and even the Python
packages used only inside the build-time Firefox-policy stage — is
pinned to an exact commit SHA or verified against a pinned sha256
checksum, never a floating tag, branch, or "latest". The build fails
closed (via `set -eu` and explicit diff/assertion checks) rather than
silently shipping an unverified or partially-applied change if any
pinned fetch doesn't match. [`scripts/validate-image.sh`](scripts/validate-image.sh)
re-asserts all of this (currently 41 checks) against the built image
itself — no VM boot required — and CI runs it on every push and pull
request before anything is published.

## Deployment

### Prerequisites

- A machine capable of running `podman` (for building/testing
  locally) — not required if you only consume the published image.
- A target machine already running a Fedora Atomic/bootc-based OS
  (e.g. a stock Fedora COSMIC Atomic install), or one being freshly
  installed from this image's ISO/disk image.
- Network access to `ghcr.io` (or your own registry, if you publish
  elsewhere) and, for ongoing use, to your FreeIPA server and Tailscale
  coordination server.

### 1. Build (CI, automatic)

[`.github/workflows/build.yml`](.github/workflows/build.yml) builds
and validates the image on every push and pull request. On a push to
`master` it additionally publishes the image to GHCR, tagged both
`:latest` and with the commit SHA:

```
ghcr.io/<repository_owner>/fedora-mojo:latest
ghcr.io/<repository_owner>/fedora-mojo:<commit-sha>
```

No manual steps are required for this — merging to `master` is what
triggers a publish. To build and validate locally instead (e.g. before
opening a PR):

```sh
podman build -t fedora-mojo:local -f Containerfile .
./scripts/validate-image.sh fedora-mojo:local
```

### 2. Build an installable ISO (optional)

`bootc install` (next section) needs *some* already-running Linux with
`podman`/`bootc` to install from — fine if you already have one handy,
but not if you're provisioning a bare machine or one of this fleet's
repurposed Chromebooks from nothing. [`scripts/build-iso.sh`](scripts/build-iso.sh)
wraps [`bootc-image-builder`](https://github.com/osbuild/bootc-image-builder)
to turn the published image into a bootable installer ISO instead:

```sh
cp config.toml.example config.toml
# edit config.toml: add your own SSH key and/or a password hash
# generated with `openssl passwd -6` -- see the comments in the file.
./scripts/build-iso.sh
```

This produces `output/bootiso/install.iso`. A few things worth knowing:

- It needs `--privileged` (loop devices) and `sudo`, since
  `bootc-image-builder` builds the disk image locally rather than in a
  remote service.
- The image ships no default user — FreeIPA is this fleet's system of
  record for identity, not a baked-in account — so `config.toml`'s
  `bootstrap` user (wheel/sudo) is what lets you log in on first boot to
  run `ipa-client-install` at all. It's not meant to be a long-term
  account once a machine is enrolled into FreeIPA.
- `config.toml` is gitignored on purpose (it holds a password hash
  and/or your SSH key): never commit the real one, only
  `config.toml.example`.
- By default this builds from the published `:latest` image; pass a
  different ref as the first argument (e.g.
  `./scripts/build-iso.sh ghcr.io/<owner>/fedora-mojo:<commit-sha>`) to
  build from a specific build instead.

### 3. Provision a new machine from the image

Fedora Atomic images are installed via `bootc install`, typically from
a live/rescue environment booted against the container image itself —
either the ISO from the previous step, or any other Linux with
`podman`/`bootc` available:

```sh
sudo bootc install to-disk \
  --source ghcr.io/<repository_owner>/fedora-mojo:latest \
  /dev/<target-disk>
```

Consult [bootc's installation documentation](https://containers.github.io/bootc/)
for the full set of `bootc install` modes (`to-disk`, `to-existing-root`,
`to-filesystem`) and pick whichever matches how you're provisioning —
a brand-new disk, replacing an existing OS in place, or targeting an
already-partitioned filesystem.

### 4. First boot

On first boot:

1. **Join FreeIPA**, if your fleet uses it, with `ipa-client-install`
   (provided by the pre-installed `freeipa-client` package) pointed at
   your FreeIPA server.
2. **Add users to the `brew` group** in FreeIPA for anyone who should
   get Homebrew access; they can then run `ujust brew-setup`.
3. Run `ujust --list` to see the available recipes, and apply whichever
   are relevant to that machine — e.g. `ujust chromebook-keyboard` on
   repurposed Chromebook hardware, `ujust tailscale-up` to join your
   tailnet.

### 5. Ongoing updates

Each machine updates itself in place by pulling the newer published
image and rebooting into it:

```sh
ujust update
```

This is a thin wrapper over `sudo bootc upgrade`. There's no package
manager drift to manage on these machines — all package changes ship
as a new image build through the same CI pipeline that produced the
one currently running.

### Customizing for your own fleet

If you fork this for your own deployment:

- Edit [`policies.yaml`](policies.yaml) and rebuild to change Firefox's
  managed policy defaults — don't edit the generated
  `policies.json` directly, since it's overwritten on every build. In
  particular, if your FreeIPA domain has internal hostnames that don't
  resolve over DoH, add an `ExcludedDomains` entry for your domain (see
  the comment above `DNSOverHTTPS` in that file).
- The RPM Fusion release RPM checksums and the `"45"` version string in
  the Containerfile are tied to this Fedora release; bumping the base
  image to a new Fedora version means re-pinning those checksums too.
- Every other pinned commit/checksum in the Containerfile (Homebrew,
  alsa-ucm-conf-cros, the ArtCraft AppImages, the Flatpak refs, the
  Firefox Policy Generator and its pip dependencies) can be bumped
  independently — re-run `./scripts/validate-image.sh` after any such
  change to confirm nothing broke.

## Project documentation

- [`GLOSSARY.md`](GLOSSARY.md) — domain vocabulary used throughout
  this repo's issues, commits, and docs.
- [`docs/adr/`](docs/adr/) — architecture decision records explaining
  trade-offs made along the way (nonfree codecs via RPM Fusion,
  isolated per-user Homebrew).
- [`docs/agents/`](docs/agents/) — conventions for AI coding agents
  working in this repo (issue tracker, triage labels, domain-doc
  layout).
