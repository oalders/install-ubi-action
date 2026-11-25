#!/bin/sh
# Print ubi-checksums.txt lines for a ubi release: the sha256 of the ubi binary
# in each non-Windows asset, after checking the asset against its .sha256 file.
# Usage: sh update-ubi-checksums.sh v0.13.0 >> ubi-checksums.txt
# Needs gh, curl and GNU sha256sum.
set -euf

version=$1
base="https://github.com/houseabsolute/ubi/releases/download/$version"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

gh api "repos/houseabsolute/ubi/releases/tags/$version" \
  --jq '.assets[].name | select(endswith(".tar.gz"))' > "$work/assets"
if [ ! -s "$work/assets" ]; then
  echo "$version has no .tar.gz assets" >&2
  exit 1
fi

# Print nothing until every asset checks out, so a failure can't append a partial list.
while read -r asset; do
  curl --fail --silent --show-error --location --output "$work/$asset" "$base/$asset"
  curl --fail --silent --show-error --location --output "$work/sum" "$base/$asset.sha256"
  expected=$(cut -d' ' -f1 < "$work/sum")
  actual=$(sha256sum "$work/$asset" | cut -d' ' -f1)
  if [ "$expected" != "$actual" ]; then
    echo "$asset does not match its .sha256 file" >&2
    exit 1
  fi
  tar -xzf "$work/$asset" -C "$work" ubi
  if [ ! -f "$work/ubi" ] || [ -L "$work/ubi" ]; then
    echo "$asset: ubi is not a regular file" >&2
    exit 1
  fi
  sum=$(sha256sum "$work/ubi")
  echo "$version ${sum%% *} $asset" >> "$work/out"
  rm -f "$work/ubi" "$work/$asset"
done < "$work/assets"
cat "$work/out"
