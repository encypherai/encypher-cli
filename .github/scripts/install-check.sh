#!/usr/bin/env bash
# Installs encypher through the release's install.sh the way a user does, then
# checks what the user gets. Run by release.yml's install-check job on Linux
# and macOS.
#
#   BASE      release base URL: the published release, or a dry run's loopback mirror
#   VERSION   the release version
#   FIXTURE   directory holding signed-test.jpg and image_png.png
#   ENCYPHER_API_KEY  optional: also sign a PNG and verify the result
#   ENCYPHER_DOWNLOAD_URL  set by a dry run, passed through to the installer
#   ENCYPHER_CHECK_UNPINNED  non-empty: install the README's unpinned way
set -euo pipefail
: "${BASE:?}" "${VERSION:?}" "${FIXTURE:?}"

fail() {
  echo "install-check: $*" >&2
  exit 1
}

bin="${HOME}/.local/bin"
cli="${bin}/encypher"
expected="\"client\": \"${VERSION}\""
case "$(uname -s)" in
  Darwin) login_shell=/bin/zsh ;;
  *) login_shell=/bin/bash ;;
esac
# A new user's PATH does not contain the install directory yet.
user_path="$(printf '%s' "${PATH}" | tr ':' '\n' | grep -vxF "${bin}" | paste -sd: -)"
out="$(mktemp)"

# Unpinned takes the script and the archive from latest/download and sets no
# ENCYPHER_VERSION, exactly as the README's main command does. Only a dry run
# asks for it: until promote, latest still points at the previous release.
script_url="${BASE}/download/v${VERSION}/install.sh"
pin=("ENCYPHER_VERSION=${VERSION}")
if [[ -n "${ENCYPHER_CHECK_UNPINNED:-}" ]]; then
  script_url="${BASE}/latest/download/install.sh"
  pin=(-u ENCYPHER_VERSION)
fi
curl -fsSL "${script_url}" \
  | env "${pin[@]}" PATH="${user_path}" SHELL="${login_shell}" sh | tee "${out}"

# The printed PATH lines, applied the way the installer says, find encypher by name.
line_after() {
  awk -v marker="$1" 'index($0, marker) { getline; sub(/^    /, ""); print; exit }' "${out}"
}
current="$(line_after 'in this shell, run:')"
persistent="$(line_after 'and for new shells')"
[[ -n "${current}" && -n "${persistent}" ]] || fail "the installer printed no PATH lines"
fresh=(env -i "HOME=${HOME}" PATH=/usr/bin:/bin TERM=dumb)
"${fresh[@]}" sh -c "${current}; encypher --version" | grep -qF "${expected}" \
  || fail "encypher is not found by name after: ${current}"
"${fresh[@]}" sh -c "${persistent}"
"${fresh[@]}" "${login_shell}" -ic 'encypher --version' 2>/dev/null | grep -qF "${expected}" \
  || fail "encypher is not found by name in a new ${login_shell} after: ${persistent}"

"${cli}" --version | grep -qF "${expected}" || fail "the installed encypher does not report ${VERSION}"
"${cli}" inspect "${FIXTURE}/signed-test.jpg" --json >/dev/null
"${cli}" verify "${FIXTURE}/signed-test.jpg" --json
if [[ -n "${ENCYPHER_API_KEY:-}" ]]; then
  signed="$(mktemp -d)/signed.png"
  "${cli}" sign "${FIXTURE}/image_png.png" -o "${signed}" --on-existing-provenance chain --json \
    --digital-source-type http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture >/dev/null
  "${cli}" verify "${signed}" --json >/dev/null
  echo "install-check: signed and verified a PNG with the installed encypher"
else
  echo "install-check: ENCYPHER_API_KEY is not configured; live sign skipped"
fi

if [[ "$(uname -s)" == Darwin ]]; then
  # What this machine enforces, so the evidence states what was exercised.
  sw_vers
  spctl --status || true
  csrutil status || true
  if xattr -p com.apple.quarantine "${cli}" >/dev/null 2>&1; then
    fail "the installed encypher carries com.apple.quarantine"
  fi
  codesign --verify --strict "${cli}"
  codesign -dv "${cli}" 2>&1 | grep -q 'Signature=adhoc' || fail "the installed encypher has no ad hoc signature"
  # A browser download is quarantined; the README's xattr line clears it.
  browser="$(mktemp -d)/encypher-${VERSION}"
  mkdir -p "${browser}"
  cp "${cli}" "${browser}/encypher"
  xattr -w com.apple.quarantine "0083;00000000;Safari;" "${browser}/encypher"
  xattr -p com.apple.quarantine "${browser}/encypher" >/dev/null
  xattr -dr com.apple.quarantine "${browser}"
  if xattr -p com.apple.quarantine "${browser}/encypher" >/dev/null 2>&1; then
    fail "xattr -dr did not clear the quarantine mark"
  fi
  "${browser}/encypher" --version | grep -qF "${expected}"
fi
echo "install-check: encypher ${VERSION} installed by ${script_url} and ran"
