#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Build the RMSPA release archive.
#
# Requires the MSPA binaries in resources/ (run scripts/fetch-binaries.sh
# first). The archive contains a top-level folder RMSPA/ and preserves the
# executable bits of the MSPA binaries.
#
# Usage: ./scripts/build-release.sh [expected-version]
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "$0")/.."

version="$(tr -d '[:space:]' < VERSION)"
if [[ -z "$version" ]]; then
  echo "error: VERSION is empty" >&2
  exit 1
fi
if [[ $# -ge 1 && "$1" != "$version" ]]; then
  echo "error: expected version '$1' but VERSION contains '$version'" >&2
  exit 1
fi

for target in linux-x86_64 linux-aarch64 macos-arm64 windows-x86_64 windows-arm64; do
  if [[ ! -d "resources/${target}" ]]; then
    echo "error: resources/${target} is missing; run scripts/fetch-binaries.sh" >&2
    exit 1
  fi
done

dist="${PWD}/dist"
zip_name="RMSPA-${version}.zip"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

mkdir -p "$stage/RMSPA"
cp app.R VERSION MSPA_VERSION README.md CHANGELOG.md "$stage/RMSPA/"
cp -R R www examples resources "$stage/RMSPA/"

find "$stage/RMSPA" -type d -exec chmod 755 {} +
find "$stage/RMSPA/resources" -type f ! -name '*.dylib' ! -name '*.txt' \
     -exec chmod 755 {} +
find "$stage/RMSPA/resources" -type f -name '*.dylib' -exec chmod 644 {} +

mkdir -p "$dist"
rm -f "${dist}/${zip_name}" "${dist}/SHA256SUMS"

( cd "$stage" && zip -qrX "${dist}/${zip_name}" RMSPA )

( cd "$dist"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${zip_name}" > SHA256SUMS
  else
    shasum -a 256 "${zip_name}" > SHA256SUMS
  fi
)

echo "Created:"
ls -lh "${dist}/${zip_name}" "${dist}/SHA256SUMS"
cat "${dist}/SHA256SUMS"
