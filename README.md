# oleafly-bin (Arch Linux / CachyOS AUR Package)

`oleafly-bin` is an Arch Linux / CachyOS `x86_64` binary package for [Oleafly](https://github.com/Oleafly/Oleafly), a local-first AI-assisted research workspace for LaTeX, Typst, and Markdown.

It repackages the official upstream `.deb` release directly into a native Pacman package after verifying both **SHA-256** checksums and the upstream **Tauri Minisign** signature.

---

## Why `oleafly-bin`?

The existing AUR [`oleafly`](https://aur.archlinux.org/packages/oleafly) package builds from source and requires `nodejs-lts-krypton`, `pnpm`, `cargo`, and `cargo-tauri` as `makedepends`, which can conflict with systems running newer Node.js versions (e.g., Node.js 26) and pulls heavy build toolchains.

| Comparison | `oleafly` (AUR source) | `oleafly-bin` (this package) |
| --- | --- | --- |
| Build method | Compiles frontend + Rust/Tauri from source | Repackages official GitHub Release `.deb` |
| Node.js / pnpm / Rust needed | Yes (`nodejs-lts-krypton`, `pnpm`, `cargo`, `cargo-tauri`) | **No** (no compiler or Node.js required) |
| Node.js 26 conflict | Conflicts with `nodejs-lts-krypton` | **None** |
| Bundled compilers | Symlinks system `tectonic`, `typst`, `pandoc`, `biber` | **Self-contained** (`/usr/libexec/oleafly/*`, `/usr/bin/tectonic-biber`) |
| Upstream `AGPL-3.0-or-later` + bundled licenses | Declared `MIT` in AUR `oleafly` (0.4.11) | **Oleafly `AGPL-3.0-or-later` + bundled component SPDX licenses** |
| Cryptographic verification | Source tarball SHA-256 | **SHA-256 + pinned Minisign signature** |

Both packages set `provides=("oleafly=${pkgver}")` (or `oleafly`) and `conflicts=('oleafly')`.

---

## Upstream Project & License

- **Upstream repository:** <https://github.com/Oleafly/Oleafly>
- **Upstream releases:** <https://github.com/Oleafly/Oleafly/releases>
- **Licenses:** `AGPL-3.0-or-later` (Oleafly), `Apache-2.0` (Typst, Tinymist), `Artistic-2.0 OR GPL-1.0-or-later` (Biber), `GPL-2.0-or-later` (Pandoc), and `MIT` (Tectonic, bundled scientific agent skills).
  - `/usr/share/licenses/oleafly-bin/LICENSE`, `NOTICE`, `THIRD_PARTY_LICENSES.md`, and `third-party/` notices are installed alongside `/usr/lib/Oleafly/resources/licenses/`.

---

## Security & Signature Verification Flow

Upstream Oleafly signs every release installer for the Tauri Updater using **Minisign** (stored Base64-encoded in `Oleafly_<ver>_amd64.deb.sig`).

1. **Pinned Public Key (`oleafly.pub`):**
   - Extracted from upstream `src-tauri/tauri.conf.json` (`plugins.updater.pubkey`), verified against upstream release signatures, and pinned locally in `oleafly.pub` (also SHA-256 pinned in `PKGBUILD`).
   - Public key ID: `6E856CD4A6E20568`.
2. **Avoiding `makepkg` PGP misdetection:**
   - Because `makepkg` automatically treats `.sig` source files as detached PGP signatures, `PKGBUILD` renames the downloaded `.deb.sig` to `Oleafly_${pkgver}_amd64.deb.minisig.b64`.
3. **Dual Verification before Unpacking:**
   - First, `makepkg` validates `sha256sums` for all six sources (`.deb`, `.minisig.b64`, `LICENSE`, `NOTICE`, `THIRD_PARTY_LICENSES.md`, `oleafly.pub`), and `noextract` leaves the `.deb` unextracted.
   - Next, at the start of `prepare()` before running `bsdtar` (which preserves clean-chroot compatibility under `archlinux/devtools#224` while still verifying before extraction):
     - Decodes `Oleafly_${pkgver}_amd64.deb.minisig.b64` from Base64.
     - Runs `minisign -Vm` against the `.deb` using `oleafly.pub`.
     - Confirms the cryptographically signed `Trusted comment:` line contains exact `file:Oleafly_${pkgver}_amd64.deb` and `version:${pkgver}` tokens (preventing file-swap, prefix, or rollback attacks).
   - Any failure aborts the build before extracting any archive or entering `package()`.

---

## Packaged Layout & Dependencies

The official `.deb` layout is preserved cleanly so Oleafly's GUI and CLI resolve all bundled tools automatically:

- `/usr/bin/oleafly` — `/bin/sh` dispatcher (launches `oleafly-desktop` with no args, `oleafly-cli` otherwise)
- `/usr/bin/oleafly-desktop` — Main Tauri GUI application
- `/usr/bin/oleafly-cli` — Full Oleafly CLI (`doctor`, `build`, `watch`, `mcp`, etc.)
- `/usr/bin/tectonic-biber` — Co-packaged Biber 2.17 binary (matched to Tectonic 0.17.0 / biblatex 3.17; requires `libxcrypt-compat` for `libcrypt.so.1`)
- `/usr/libexec/oleafly/{pandoc,tectonic,typst}` — Bundled sidecar engines (kept in `/usr/libexec/oleafly` as expected by `oleafly-core::sidecar`, avoiding filename conflicts with system `pandoc-cli`, `tectonic`, `typst`)
- `/usr/lib/Oleafly/resources/` — Templates, catalogs, Tinymist LSP archive, and AI skills
- `/usr/share/applications/{Oleafly,oleafly-url-handler}.desktop` — Desktop launcher & `oleafly://` URL handler
- `/usr/share/kio/servicemenus/oleafly-open-folder.desktop` — KDE Dolphin "Open with Oleafly" context menu
- `/usr/share/nemo/actions/oleafly-open-folder.nemo_action` — Nemo file manager action
- `/usr/share/metainfo/com.oleafly.app.metainfo.xml` — AppStream metadata
- `/usr/share/icons/hicolor/*/apps/oleafly-desktop.png` — Hicolor application icons (`32x32` through `512x512`, including `256x256@2`)

> **Important (`!strip`):** `PKGBUILD` sets `options=('!strip' '!debug')` because `tectonic-biber` is a PAR::Packer self-extracting executable with an appended archive payload; running `strip` would corrupt it.

---

## Installation & Build Steps

### Prerequisites

```bash
sudo pacman -S --needed base-devel minisign
```

### Build and Install Locally

```bash
git clone https://github.com/LYB926/oleafly-bin-aur.git
cd oleafly-bin-aur
./verify-build.sh
makepkg -si
```

### Install / Update via AUR Helper (once published on AUR)

```bash
paru -S oleafly-bin
# or
yay -S oleafly-bin
```

---

## Updating to a New Upstream Version

Run `./update.sh` (never skips signature verification, never pushes automatically):

```bash
./update.sh           # Check latest stable release, verify, update PKGBUILD & .SRCINFO
./update.sh --build   # Also run makepkg locally after updating
```

---

## Built-in Auto-Updater vs Pacman

Oleafly bundles `tauri-plugin-updater`, but in upstream `src-tauri/src/commands.rs` (`updater_self_installable()`), Linux in-place updates are **only enabled when `$APPIMAGE` is set**. When installed via `oleafly-bin`, the app cannot overwrite Pacman-managed files in `/usr`; if an update check notices a newer release, it only displays a release link. Always upgrade `oleafly-bin` via Pacman / your AUR helper (`paru -Syu` / `yay -Syu` / `makepkg -si`).

---

## Compatibility & Known Notes

- **Arch Linux / CachyOS (`x86_64`):** Verified on CachyOS rolling (`x86_64`, KDE Plasma 6 Wayland). `libxcrypt-compat` is explicitly included in `depends` so `tectonic-biber` resolves `libcrypt.so.1` cleanly.
- **Wayland / XWayland rendering:** Under GTK3 Wayland + WebKitGTK 2.54, Oleafly's frameless transparent window can fail to repaint static regions (only animated elements appear on hover). To avoid this out of the box without moving `/usr/bin/oleafly-desktop`, desktop/service entries invoke `/usr/lib/Oleafly/oleafly-desktop-launch` while `/usr/bin/oleafly` applies the same `GDK_BACKEND=x11` fallback inline before executing `oleafly-desktop` or `oleafly-cli` (only when `WAYLAND_DISPLAY` and `DISPLAY` are both present and `GDK_BACKEND` is unset). You can always override this explicitly (e.g., `GDK_BACKEND=wayland oleafly`).
- **KDE Plasma / Dolphin:** Installs `/usr/share/kio/servicemenus/oleafly-open-folder.desktop` natively.
- **Tectonic TeX package cache:** On the very first LaTeX build, Tectonic downloads TeX packages on demand to `~/.cache/Tectonic` (unless an offline TeX Live `latexmk` installation is used).
- **`namcap` `/usr/libexec` notice:** `namcap` emits a standard warning/error for ELFs in `/usr/libexec/oleafly/`. This path is intentionally preserved because `oleafly-core` probes `../libexec/oleafly/` relative to `/usr/bin/` and moving them to `/usr/bin/` would conflict with Arch's `pandoc-cli`, `tectonic`, and `typst` packages.
- **Optional Python skill scripts:** Some bundled AI skill scripts under `/usr/lib/Oleafly/resources/skills/` import Python packages (`requests`, `PIL`, etc.). They are optional and not needed for core IDE or compiler operation.

---

## Repository Branches

- **`dev` (GitHub default branch):** Full repository including documentation, helper scripts (`update.sh`, `verify-build.sh`), and GitHub Actions workflows.
- **`master` (AUR-ready flat orphan branch):** Contains only the five root-level files required by AUR (`PKGBUILD`, `.SRCINFO`, `oleafly.pub`, `.gitignore`, `LICENSE`) with zero subdirectories in commit history, matching `aurweb` repository rules. Whenever those files change on `dev`, GitHub Actions automatically fast-forward syncs them to `master` so `master` can be cloned or pushed directly to `ssh://aur@aur.archlinux.org/oleafly-bin.git`.
