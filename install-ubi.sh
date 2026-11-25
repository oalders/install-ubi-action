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
test -d "$LOCAL_BIN" || mkdir -p "$LOCAL_BIN"
if [ "$INPUT_SUDO" != "true" ] && [ -z "${TARGET:-}" ]; then
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

COMMIT=d9348539c2521f05225618139ea23fd3f54bce46
URL_PATH="houseabsolute/ubi/$COMMIT/bootstrap/bootstrap-ubi.sh"
INSTALLER=https://raw.githubusercontent.com/$URL_PATH

# Download and run the bootstrap script
INSTALLER_FILE=$(mktemp)
trap 'rm -f "$INSTALLER_FILE"' EXIT
curl --fail --show-error --silent --location --output "$INSTALLER_FILE" "$INSTALLER"
# A caller's FILENAME would make the bootstrap fetch that asset instead of deriving one.
unset FILENAME
if [ "$INPUT_SUDO" = "true" ]; then
  if [ -z "${TARGET:-}" ]; then
    sudo env TAG="$INPUT_VERSION" sh "$INSTALLER_FILE"
  else
    sudo env TAG="$INPUT_VERSION" TARGET="$TARGET" sh "$INSTALLER_FILE"
  fi
else
  env TAG="$INPUT_VERSION" TARGET="$TARGET" sh "$INSTALLER_FILE"
fi
# Put TARGET first even if another ubi is on PATH, so later steps get this one.
if [ -n "${TARGET:-}" ]; then
  echo "$TARGET" >> "$GITHUB_PATH"
  PATH="$TARGET:$PATH"
fi

# Verify installation
# Check the binary we installed, not whatever ubi is earlier on PATH.
# With no TARGET (sudo only), the bootstrap installs as root to /usr/local/bin; recheck on COMMIT bumps.
UBI_PATH="${TARGET:-/usr/local/bin}/ubi"
if [ -x "$UBI_PATH" ]; then
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
