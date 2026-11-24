#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Fetch the resources needed to build the ArcGIS plugin:
#   - the current MSPA Windows x86_64 binary from MSPAstandalone (MSPA_RELEASE)
#   - the current MSPA guide
#
# Usage: ./scripts/fetch-resources.sh
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "$0")/.."

engine_version="$(tr -d '[:space:]' < MSPA_VERSION)"
release_version="$(tr -d '[:space:]' < MSPA_RELEASE)"
if [[ -z "$engine_version" || -z "$release_version" ]]; then
  echo "error: MSPA_VERSION or MSPA_RELEASE is empty" >&2
  exit 1
fi

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    echo "error: no SHA-256 tool found" >&2
    return 1
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

base="https://github.com/vogtpet/MSPAstandalone/releases/download/v${release_version}"
mspa_zip="mspa-${release_version}-windows-x86_64.zip"

echo "Fetching MSPA ${engine_version} (release v${release_version})"
curl -fsSL -o "$tmp/$mspa_zip" "$base/$mspa_zip"
curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"
expected="$(awk -v f="./$mspa_zip" '$2 == f {print $1}' "$tmp/SHA256SUMS")"
actual="$(sha256_of "$tmp/$mspa_zip")"
if [[ -z "$expected" || "$expected" != "$actual" ]]; then
  echo "error: checksum mismatch for $mspa_zip" >&2
  exit 1
fi

mkdir -p "$tmp/mspa"
unzip -q "$tmp/$mspa_zip" -d "$tmp/mspa"
exe="$(find "$tmp/mspa" -name mspa_win64.exe | head -1)"
if [[ -z "$exe" ]]; then
  echo "error: mspa_win64.exe not found in the archive" >&2
  exit 1
fi
mkdir -p mspa/resources
cp "$exe" mspa/resources/mspa_win64.exe
rm -rf mspa/resources/gdal

echo "Fetching the current MSPA guide"
curl -fsSL -o MSPA_Guide.pdf \
  "https://ies-ows.jrc.ec.europa.eu/gtb/GTB/MSPA_Guide.pdf"

find mspa/resources -type f \( -name '*.exe' -o -name 'mspa_win64.exe' \) \
  -exec chmod 755 {} +

{
  echo "MSPA version: ${engine_version}"
  echo "Release: v${release_version}"
  echo "Source: https://github.com/vogtpet/MSPAstandalone/releases/tag/v${release_version}"
  echo ""
  (cd mspa/resources && echo "$(sha256_of mspa_win64.exe)  mspa_win64.exe")
} > mspa/resources/BINARIES.txt

echo "Done"
cat mspa/resources/BINARIES.txt
