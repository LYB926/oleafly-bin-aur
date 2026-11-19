#!/usr/bin/env bash
set -euo pipefail

# update.sh - Check upstream Oleafly stable releases, verify Minisign & SHA-256,
# update PKGBUILD and .SRCINFO, and run consistency checks.
# Never skips signature verification and never auto-publishes to AUR/GitHub.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

REPO="Oleafly/Oleafly"
PUBKEY_FILE="$SCRIPT_DIR/oleafly.pub"
PKGBUILD_FILE="$SCRIPT_DIR/PKGBUILD"
SRCINFO_FILE="$SCRIPT_DIR/.SRCINFO"

DO_BUILD=0
FORCE=0
TARGET_VERSION=""

usage() {
  cat <<'EOF'
Usage: ./update.sh [OPTIONS]

Options:
  --version <ver>   Update to a specific stable release version (e.g. 0.4.12)
  --build           Also run makepkg after updating PKGBUILD and .SRCINFO
  --force           Re-verify and rewrite PKGBUILD/.SRCINFO even if pkgver matches
  -h, --help        Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || { echo "Error: --version requires an argument" >&2; exit 1; }
      TARGET_VERSION="${2#v}"
      shift 2
      ;;
    --build)
      DO_BUILD=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for cmd in curl python3 base64 sha256sum minisign makepkg; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' not found in PATH" >&2
    exit 1
  fi
done

[[ -f "$PUBKEY_FILE" ]] || { echo "Error: missing pinned public key: $PUBKEY_FILE" >&2; exit 1; }
[[ -f "$PKGBUILD_FILE" ]] || { echo "Error: missing PKGBUILD: $PKGBUILD_FILE" >&2; exit 1; }

CURRENT_VER="$(grep -E '^pkgver=' "$PKGBUILD_FILE" | head -n 1 | cut -d= -f2- | tr -d "'\"")"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

RELEASE_JSON="$TMP_DIR/release.json"
if [[ -n "$TARGET_VERSION" ]]; then
  API_URL="https://api.github.com/repos/${REPO}/releases/tags/v${TARGET_VERSION}"
else
  API_URL="https://api.github.com/repos/${REPO}/releases/latest"
fi

echo "==> Querying upstream release metadata: $API_URL"
CURL_API_ARGS=(-fsSL -H 'Accept: application/vnd.github+json' -H 'User-Agent: oleafly-bin-aur-updater')
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  CURL_API_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi
curl "${CURL_API_ARGS[@]}" "$API_URL" -o "$RELEASE_JSON"

readarray -t META < <(python3 - "$RELEASE_JSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if data.get("draft") or data.get("prerelease"):
    raise SystemExit("Error: selected release is a draft or prerelease")
tag = data["tag_name"]
ver = tag[1:] if tag.startswith("v") else tag
deb_name = f"Oleafly_{ver}_amd64.deb"
sig_name = f"{deb_name}.sig"
assets = {a["name"]: a["browser_download_url"] for a in data.get("assets", [])}
if deb_name not in assets:
    raise SystemExit(f"Error: asset {deb_name} not found in release {tag}")
if sig_name not in assets:
    raise SystemExit(f"Error: signature asset {sig_name} not found in release {tag}")
print(ver)
print(assets[deb_name])
print(assets[sig_name])
PY
)

LATEST_VER="${META[0]}"
DEB_URL="${META[1]}"
SIG_URL="${META[2]}"
LICENSE_URL="https://raw.githubusercontent.com/${REPO}/v${LATEST_VER}/LICENSE"
TAURI_CONF_URL="https://raw.githubusercontent.com/${REPO}/v${LATEST_VER}/src-tauri/tauri.conf.json"

echo "==> Current pkgver: $CURRENT_VER"
echo "==> Upstream stable: $LATEST_VER"

if [[ "$LATEST_VER" == "$CURRENT_VER" && "$FORCE" -eq 0 ]]; then
  echo "==> Already up to date ($CURRENT_VER)."
  exit 0
fi

DEB_NAME="Oleafly_${LATEST_VER}_amd64.deb"
SIG_B64_NAME="${DEB_NAME}.minisig.b64"
LICENSE_NAME="oleafly-${LATEST_VER}-LICENSE"

DEB_PATH="$TMP_DIR/$DEB_NAME"
SIG_B64_PATH="$TMP_DIR/$SIG_B64_NAME"
SIG_BIN_PATH="$TMP_DIR/${DEB_NAME}.minisig"
LICENSE_PATH="$TMP_DIR/$LICENSE_NAME"
TAURI_CONF_PATH="$TMP_DIR/tauri.conf.json"

echo "==> Checking upstream tauri.conf.json updater public key"
curl -fsSL "$TAURI_CONF_URL" -o "$TAURI_CONF_PATH"
python3 - "$TAURI_CONF_PATH" "$PUBKEY_FILE" <<'PY'
import base64, json, sys
conf = json.load(open(sys.argv[1], encoding="utf-8"))
upstream_pub = base64.b64decode(conf["plugins"]["updater"]["pubkey"]).decode("utf-8").strip()
pinned_pub = open(sys.argv[2], encoding="utf-8").read().strip()
if upstream_pub != pinned_pub:
    raise SystemExit(
        "Error: upstream tauri.conf.json updater pubkey differs from pinned oleafly.pub!\n"
        "Refusing to auto-trust a new key. Audit upstream key rotation manually."
    )
PY
echo "    Pinned oleafly.pub matches upstream v${LATEST_VER} tauri.conf.json"

echo "==> Downloading DEB, Minisign signature, and LICENSE"
curl -fSL "$DEB_URL" -o "$DEB_PATH"
curl -fSL "$SIG_URL" -o "$SIG_B64_PATH"
curl -fsSL "$LICENSE_URL" -o "$LICENSE_PATH"

echo "==> Verifying Minisign signature against pinned oleafly.pub"
base64 -d "$SIG_B64_PATH" > "$SIG_BIN_PATH"
VERIFY_OUT="$(minisign -Vm "$DEB_PATH" -p "$PUBKEY_FILE" -x "$SIG_BIN_PATH" 2>&1)" || {
  printf '%s\n' "$VERIFY_OUT" >&2
  echo "Error: Minisign verification failed!" >&2
  exit 1
}
printf '%s\n' "$VERIFY_OUT"

if ! grep -Fq "file:${DEB_NAME}" <<<"$VERIFY_OUT" || ! grep -Fq "version:${LATEST_VER}" <<<"$VERIFY_OUT"; then
  echo "Error: Minisign trusted comment does not match ${DEB_NAME} (${LATEST_VER})" >&2
  exit 1
fi

DEB_SHA="$(sha256sum "$DEB_PATH" | awk '{print $1}')"
SIG_SHA="$(sha256sum "$SIG_B64_PATH" | awk '{print $1}')"
LIC_SHA="$(sha256sum "$LICENSE_PATH" | awk '{print $1}')"
PUB_SHA="$(sha256sum "$PUBKEY_FILE" | awk '{print $1}')"

echo "==> Computed SHA-256 checksums:"
echo "    DEB:     $DEB_SHA"
echo "    SIG.b64: $SIG_SHA"
echo "    LICENSE: $LIC_SHA"
echo "    PUBKEY:  $PUB_SHA"

echo "==> Updating PKGBUILD"
python3 - "$PKGBUILD_FILE" "$LATEST_VER" "$DEB_SHA" "$SIG_SHA" "$LIC_SHA" "$PUB_SHA" <<'PY'
import re, sys
pkgbuild_path, ver, deb_sha, sig_sha, lic_sha, pub_sha = sys.argv[1:7]
text = open(pkgbuild_path, encoding="utf-8").read()

text, n1 = re.subn(r'^pkgver=.*$', f'pkgver={ver}', text, count=1, flags=re.M)
text, n2 = re.subn(r'^pkgrel=.*$', 'pkgrel=1', text, count=1, flags=re.M)
new_sums = (
    "sha256sums=(\n"
    f"  '{deb_sha}'\n"
    f"  '{sig_sha}'\n"
    f"  '{lic_sha}'\n"
    f"  '{pub_sha}'\n"
    ")"
)
text, n3 = re.subn(r'^sha256sums=\([\s\S]*?^\)$', new_sums, text, count=1, flags=re.M)

if (n1, n2, n3) != (1, 1, 1):
    raise SystemExit(f"Error: unexpected PKGBUILD replacement counts {(n1, n2, n3)}")

open(pkgbuild_path, "w", encoding="utf-8").write(text)
PY

echo "==> Regenerating .SRCINFO"
makepkg --printsrcinfo > "$SRCINFO_FILE"

echo "==> Running consistency checks"
bash -n "$PKGBUILD_FILE"
SRCINFO_VER="$(grep -E '^\s*pkgver\s*=' "$SRCINFO_FILE" | head -n 1 | awk -F= '{gsub(/[[:space:]]/, "", $2); print $2}')"
[[ "$SRCINFO_VER" == "$LATEST_VER" ]] || {
  echo "Error: .SRCINFO pkgver ($SRCINFO_VER) != $LATEST_VER" >&2
  exit 1
}

if [[ "$DO_BUILD" -eq 1 ]]; then
  echo "==> Copying verified sources for local makepkg build"
  cp "$DEB_PATH" "$SCRIPT_DIR/$DEB_NAME"
  cp "$SIG_B64_PATH" "$SCRIPT_DIR/$SIG_B64_NAME"
  cp "$LICENSE_PATH" "$SCRIPT_DIR/$LICENSE_NAME"
  makepkg -fc --noconfirm
fi

echo "==> Done. Review changes with 'git diff' before committing or publishing."
