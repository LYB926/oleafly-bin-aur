#!/usr/bin/env bash
set -euo pipefail

# verify-build.sh - Local validation script for oleafly-bin PKGBUILD and built package.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> 1. Checking PKGBUILD bash syntax"
bash -n PKGBUILD

echo "==> 2. Verifying .SRCINFO is up to date"
TMP_SRCINFO="$(mktemp)"
trap 'rm -f "$TMP_SRCINFO"' EXIT
makepkg --printsrcinfo > "$TMP_SRCINFO"
if ! diff -u .SRCINFO "$TMP_SRCINFO"; then
  echo "Error: .SRCINFO is out of sync with PKGBUILD. Run: makepkg --printsrcinfo > .SRCINFO" >&2
  exit 1
fi
echo "    .SRCINFO matches PKGBUILD"

if command -v namcap >/dev/null 2>&1; then
  echo "==> 3. Running namcap on PKGBUILD"
  namcap PKGBUILD || true
else
  echo "==> 3. Skipping namcap (not installed)"
fi

echo "==> 4. Checking verify() hook is present and no SKIP checksums exist"
if grep -qE "'SKIP'|\"SKIP\"" PKGBUILD; then
  echo "Error: PKGBUILD contains SKIP checksums" >&2
  exit 1
fi
grep -q '^verify()' PKGBUILD || { echo "Error: verify() function missing" >&2; exit 1; }

PKG_FILE="$(find "$SCRIPT_DIR" -maxdepth 1 -type f -name 'oleafly-bin-*.pkg.tar*' | sort | tail -n 1 || true)"
if [[ -n "$PKG_FILE" ]]; then
  echo "==> 5. Inspecting built package: $(basename "$PKG_FILE")"
  if command -v namcap >/dev/null 2>&1; then
    namcap "$PKG_FILE" || true
  fi
  echo "    Checking ownership (expecting root:root)..."
  NON_ROOT="$(bsdtar -tvf "$PKG_FILE" | grep -v '^[-dlrwx]* *0 root *root ' || true)"
  if [[ -n "$NON_ROOT" ]]; then
    echo "Error: non-root file ownership found in package:" >&2
    printf '%s\n' "$NON_ROOT" >&2
    exit 1
  fi
  echo "    All entries owned by root:root"

  echo "    Checking required paths..."
  CONTENTS="$(bsdtar -tf "$PKG_FILE")"
  for req in \
    "usr/bin/oleafly" \
    "usr/bin/oleafly-cli" \
    "usr/bin/oleafly-desktop" \
    "usr/bin/tectonic-biber" \
    "usr/libexec/oleafly/pandoc" \
    "usr/libexec/oleafly/tectonic" \
    "usr/libexec/oleafly/typst" \
    "usr/lib/Oleafly/oleafly-desktop-launch" \
    "usr/lib/Oleafly/resources/skills-catalog.json" \
    "usr/share/applications/Oleafly.desktop" \
    "usr/share/applications/oleafly-url-handler.desktop" \
    "usr/share/kio/servicemenus/oleafly-open-folder.desktop" \
    "usr/share/licenses/oleafly-bin/LICENSE"
  do
    grep -Fxq "$req" <<<"$CONTENTS" || { echo "Error: missing $req in package" >&2; exit 1; }
  done
  echo "    All required paths present"
else
  echo "==> 5. No built .pkg.tar* artifact present (run 'makepkg' to build and inspect)"
fi

echo "==> Verification checks completed."
