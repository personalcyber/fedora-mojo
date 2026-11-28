# fedora-mojo

A custom Fedora Atomic (bootc) desktop image, built on Fedora COSMIC Atomic, for a small fleet of laptops — including repurposed Chromebooks — joined to a shared FreeIPA domain for centralized identity and group-based privilege gating.

## Language

**ArtCraft**:
A suite of open-source, Rust-based creative and office applications (e.g. WordCraft, GridCraft, DeckCraft, PdfCraft, PhotoCraft, VectorCraft, FilmCraft), distributed as native Linux apps and delivered on this image via AppImage.
_Avoid_: Askcraft (dictation typo)

**Brew group**:
A FreeIPA-managed Unix group whose membership grants a user a private, fully isolated Homebrew installation on this image.
_Avoid_: Homebrew group
