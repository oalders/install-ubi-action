#!/bin/sh
# -f: no globbing anywhere; $project is word-split on purpose to carry ubi flags.
set -eufx

# An empty tag falls back to latest and a slash can redirect the download path.
case "$INPUT_VERSION" in
  ''|*/*)
    echo "Invalid version: $INPUT_VERSION" >&2
    exit 1
    ;;
esac

echo "Installing ubi universal binary installer..."

# ubi's default --in (./bin) is not on PATH, so default TARGET to ~/.local/bin.
LOCAL_BIN=$HOME/.local/bin
if [ "$INPUT_SUDO" != "true" ] && [ -z "${TARGET:-}" ]; then
  test -d "$LOCAL_BIN" || mkdir -p "$LOCAL_BIN"
  TARGET=$LOCAL_BIN
  echo "Setting TARGET to ${TARGET}"
  export TARGET
fi

# GITHUB_PATH and GITHUB_OUTPUT are line-based, so a newline would add entries.
nl='
'
cr=$(printf '\r')
case "${TARGET:-}" in
  *"$nl"*|*"$cr"*)
    echo "Invalid TARGET: contains a newline or carriage return" >&2
    exit 1
    ;;
esac

# awk can't tell a missing checksum file from an unlisted tag, so check it first.
SUMS="$(dirname "$0")/ubi-checksums.txt"
if [ ! -r "$SUMS" ]; then
  echo "❌ $SUMS is missing or unreadable"
  exit 1
fi

COMMIT=d9348539c2521f05225618139ea23fd3f54bce46
URL_PATH="houseabsolute/ubi/$COMMIT/bootstrap/bootstrap-ubi.sh"
INSTALLER=https://raw.githubusercontent.com/$URL_PATH

# Download and run the bootstrap script
INSTALLER_FILE=$(mktemp)
trap 'rm -f "$INSTALLER_FILE"' EXIT
curl --fail --show-error --silent --location --output "$INSTALLER_FILE" "$INSTALLER"
# Run the bootstrap with only what it and its tools need: a caller's FILENAME or
# TAR_OPTIONS would change what it fetches or extracts.
set -- TAG="$INPUT_VERSION"
[ -z "${TARGET:-}" ] || set -- "$@" TARGET="$TARGET"
[ -z "${UBI_DEBUG_BOOTSTRAP:-}" ] || set -- "$@" UBI_DEBUG_BOOTSTRAP=1
if [ "$INPUT_SUDO" = "true" ]; then
  # Root gets a fixed PATH and none of the caller's proxy, CA or TMPDIR settings:
  # on sudo's argv they would land in its log.
  sudo env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$@" sh "$INSTALLER_FILE"
else
  # xtrace off, so proxy credentials stay out of the log.
  set +x
  for var in TMPDIR http_proxy https_proxy HTTPS_PROXY all_proxy ALL_PROXY \
    no_proxy NO_PROXY CURL_CA_BUNDLE SSL_CERT_FILE SSL_CERT_DIR; do
    eval "val=\${$var:-}"
    [ -z "$val" ] || set -- "$@" "$var=$val"
  done
  env -i PATH="$PATH" HOME="$HOME" "$@" sh "$INSTALLER_FILE"
  set -x
fi

# Verify installation
# Check the binary we installed, not whatever ubi is earlier on PATH.
# With no TARGET (sudo only), the bootstrap installs as root to /usr/local/bin; recheck on COMMIT bumps.
UBI_PATH="${TARGET:-/usr/local/bin}/ubi"
if [ -x "$UBI_PATH" ]; then
  # The bootstrap checks nothing it downloads, so check the binary before running it.
  # Hash with the privilege that installed it, and remove it on any failure, as TARGET may already be on PATH.
  run() { if [ "$INPUT_SUDO" = "true" ]; then sudo "$@"; else "$@"; fi; }
  reject() {
    echo "❌ $1"
    run rm -rf -- "$UBI_PATH"
    exit 1
  }
  # No pipe, so a hashing failure is caught.
  if command -v sha256sum >/dev/null; then
    UBI_SHA=$(run sha256sum "$UBI_PATH") || reject "could not hash $UBI_PATH"
  else
    UBI_SHA=$(run shasum -a 256 "$UBI_PATH") || reject "could not hash $UBI_PATH"
  fi
  UBI_SHA=${UBI_SHA%% *}
  # Appending "" forces a string comparison: all-digit values would otherwise compare as numbers.
  if ! V="$INPUT_VERSION" awk '$1 "" == ENVIRON["V"] "" { f = 1 } END { exit !f }' "$SUMS"; then
    echo "::warning::ubi $INPUT_VERSION is not in ubi-checksums.txt, so its checksum was not verified"
  elif ! V="$INPUT_VERSION" H="$UBI_SHA" \
    awk '$1 "" == ENVIRON["V"] "" && $2 "" == ENVIRON["H"] "" { f = 1 } END { exit !f }' "$SUMS"; then
    reject "$UBI_PATH (sha256 $UBI_SHA) does not match any ubi $INPUT_VERSION checksum in ubi-checksums.txt"
  fi
  UBI_VERSION=$("$UBI_PATH" --version | head -n1 | awk '{print $2}')
  if [ -z "$UBI_VERSION" ]; then
    echo "❌ $UBI_PATH did not report a version"
    exit 1
  fi
  echo "✅ ubi ${UBI_VERSION} installed successfully at ${UBI_PATH}"
  echo "version=${UBI_VERSION}" >> "$GITHUB_OUTPUT"
  echo "path=${UBI_PATH}" >> "$GITHUB_OUTPUT"
else
  echo "❌ Failed to install ubi"
  exit 1
fi

# Put TARGET first even if another ubi is on PATH, so later steps get this one.
if [ -n "${TARGET:-}" ]; then
  echo "$TARGET" >> "$GITHUB_PATH"
  PATH="$TARGET:$PATH"
fi

# Install additional projects if specified
if [ -n "$INPUT_PROJECTS" ]; then
  echo "Installing specified projects with ubi..."

  # Export with xtrace off so the token stays out of the log and out of argv.
  set +x
  export GITHUB_TOKEN="$INPUT_GITHUB_TOKEN"
  set -x

  # Process each project in the newline-delimited list
  printf '%s\n' "$INPUT_PROJECTS" | while read -r project; do
    if [ -n "$project" ]; then
      echo "Installing $project..."

      # ubi defaults --in to ./bin, so install beside ubi unless the line names a dir.
      # shellcheck disable=SC2086 # split on purpose, see set -f above
      set -- --project $project
      has_in=
      for arg in "$@"; do
        case $arg in -i|--in|--in=*) has_in=1 ;; esac
      done
      [ -n "$has_in" ] || set -- "$@" --in "${TARGET:-/usr/local/bin}"
      if [ "$INPUT_SUDO" = "true" ]; then
        sudo --preserve-env=GITHUB_TOKEN "$UBI_PATH" "$@"
      else
        "$UBI_PATH" "$@"
      fi

      echo "✅ Installed $project"
    fi
  done
fi
