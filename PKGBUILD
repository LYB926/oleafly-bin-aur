# Maintainer: w568w <w568w at outlook dot com>
# Contributor: Ke Zhang <zhangke23 at m dot fudan dot edu dot cn>

pkgname=oleafly-bin
_upstream_name=Oleafly
pkgver=0.4.12
pkgrel=1
pkgdesc='Local-first AI-assisted research workspace for LaTeX, Typst, and Markdown (prebuilt)'
arch=('x86_64')
url='https://github.com/Oleafly/Oleafly'
license=('AGPL-3.0-or-later')
depends=(
  'bash'
  'cairo'
  'dbus'
  'gdk-pixbuf2'
  'glib2'
  'glibc'
  'gtk3'
  'hicolor-icon-theme'
  'libgcc'
  'libsoup3'
  'libxcrypt-compat'
  'webkit2gtk-4.1'
)
makedepends=('minisign')
optdepends=(
  'git: project version history, checkpoints, and remote repository sync'
  'python: optional bundled AI research skill scripts'
  'texlive-binextra: external latexmk engine support'
)
provides=('oleafly')
conflicts=('oleafly')
options=('!strip' '!debug')
source=(
  "${_upstream_name}_${pkgver}_amd64.deb::${url}/releases/download/v${pkgver}/${_upstream_name}_${pkgver}_amd64.deb"
  "${_upstream_name}_${pkgver}_amd64.deb.minisig.b64::${url}/releases/download/v${pkgver}/${_upstream_name}_${pkgver}_amd64.deb.sig"
  "oleafly-${pkgver}-LICENSE::https://raw.githubusercontent.com/Oleafly/Oleafly/v${pkgver}/LICENSE"
  'oleafly.pub'
)
noextract=("${_upstream_name}_${pkgver}_amd64.deb")
sha256sums=(
  '751eb19205099467eb26627eb117e99d020fb6bb79dc34cf0eed3d4db9e97292'
  '79e22380c16988fa58cf378cc177b3969f21d0652139636eed3b2c23d3e8dc14'
  '0d96a4ff68ad6d4b6f1f30f713b18d5184912ba8dd389f86aa7710db079abcb0'
  'bb414de32bcdfd4cc9de5c2299b2a8c877e32e70e68c3bfebc6d7f6aa104a7dc'
)

verify() {
  local deb_name="${_upstream_name}_${pkgver}_amd64.deb"
  local sig_b64_name="${deb_name}.minisig.b64"
  local deb_path="./${deb_name}"
  local sig_b64_path="./${sig_b64_name}"
  local pub_path='./oleafly.pub'

  if [[ ! -f "$deb_path" && -n "${SRCDEST:-}" && -f "${SRCDEST}/${deb_name}" ]]; then
    deb_path="${SRCDEST}/${deb_name}"
  fi
  if [[ ! -f "$sig_b64_path" && -n "${SRCDEST:-}" && -f "${SRCDEST}/${sig_b64_name}" ]]; then
    sig_b64_path="${SRCDEST}/${sig_b64_name}"
  fi

  [[ -f "$deb_path" ]] || { printf 'ERROR: Missing DEB payload: %s\n' "$deb_path" >&2; return 1; }
  [[ -f "$sig_b64_path" ]] || { printf 'ERROR: Missing Minisign signature: %s\n' "$sig_b64_path" >&2; return 1; }
  [[ -f "$pub_path" ]] || { printf 'ERROR: Missing pinned Minisign public key: %s\n' "$pub_path" >&2; return 1; }

  local tmp_sig verify_out
  tmp_sig="$(mktemp)"
  if ! base64 -d "$sig_b64_path" > "$tmp_sig"; then
    rm -f "$tmp_sig"
    printf 'ERROR: Failed to decode Base64 Minisign signature: %s\n' "$sig_b64_path" >&2
    return 1
  fi

  if ! verify_out="$(minisign -Vm "$deb_path" -p "$pub_path" -x "$tmp_sig" 2>&1)"; then
    printf '%s\n' "$verify_out" >&2
    rm -f "$tmp_sig"
    printf 'ERROR: Minisign signature verification failed for %s\n' "$deb_name" >&2
    return 1
  fi
  rm -f "$tmp_sig"
  printf '%s\n' "$verify_out"

  if ! grep -Fq "file:${deb_name}" <<<"$verify_out" || ! grep -Fq "version:${pkgver}" <<<"$verify_out"; then
    printf 'ERROR: Minisign trusted comment mismatch for %s (%s)\n' "$deb_name" "$pkgver" >&2
    return 1
  fi
}

prepare() {
  local deb_file="${srcdir}/${_upstream_name}_${pkgver}_amd64.deb"
  local ar_dir="${srcdir}/deb-ar"
  local root_dir="${srcdir}/deb-root"

  rm -rf "$ar_dir" "$root_dir"
  mkdir -p "$ar_dir" "$root_dir"

  bsdtar -xf "$deb_file" -C "$ar_dir"

  local data_tar
  data_tar="$(find "$ar_dir" -maxdepth 1 -type f -name 'data.tar*' | head -n 1)"
  [[ -n "$data_tar" ]] || { printf 'ERROR: Could not locate data.tar.* inside %s\n' "$deb_file" >&2; return 1; }

  bsdtar -xf "$data_tar" -C "$root_dir"
}

package() {
  local root="${srcdir}/deb-root"

  # Main executables, CLI wrapper, and co-packaged tectonic-biber
  install -Dm755 -t "$pkgdir/usr/bin" \
    "$root/usr/bin/oleafly" \
    "$root/usr/bin/oleafly-cli" \
    "$root/usr/bin/oleafly-desktop" \
    "$root/usr/bin/tectonic-biber"

  # Bundled compilation engines expected under /usr/libexec/oleafly
  install -Dm755 -t "$pkgdir/usr/libexec/oleafly" \
    "$root/usr/libexec/oleafly/pandoc" \
    "$root/usr/libexec/oleafly/tectonic" \
    "$root/usr/libexec/oleafly/typst"

  # Bundled templates, language server archives, skills, and catalogs
  install -dm755 "$pkgdir/usr/lib/Oleafly"
  cp -r --preserve=mode,timestamps --no-preserve=ownership \
    "$root/usr/lib/Oleafly/resources" \
    "$pkgdir/usr/lib/Oleafly/"

  # Desktop entries and AppStream metainfo
  install -Dm644 -t "$pkgdir/usr/share/applications" \
    "$root/usr/share/applications/Oleafly.desktop" \
    "$root/usr/share/applications/oleafly-url-handler.desktop"
  install -Dm644 -t "$pkgdir/usr/share/metainfo" \
    "$root/usr/share/metainfo/com.oleafly.app.metainfo.xml"

  # File manager integrations (KDE Dolphin KIO service menu & Nemo action)
  install -Dm644 -t "$pkgdir/usr/share/kio/servicemenus" \
    "$root/usr/share/kio/servicemenus/oleafly-open-folder.desktop"
  install -Dm644 -t "$pkgdir/usr/share/nemo/actions" \
    "$root/usr/share/nemo/actions/oleafly-open-folder.nemo_action"

  # Hicolor application icons
  local size
  for size in 32x32 64x64 128x128 256x256 256x256@2 512x512; do
    install -Dm644 -t "$pkgdir/usr/share/icons/hicolor/${size}/apps" \
      "$root/usr/share/icons/hicolor/${size}/apps/oleafly-desktop.png"
  done

  # Upstream AGPL-3.0-or-later license
  install -Dm644 "$srcdir/oleafly-${pkgver}-LICENSE" \
    "$pkgdir/usr/share/licenses/${pkgname}/LICENSE"
}
