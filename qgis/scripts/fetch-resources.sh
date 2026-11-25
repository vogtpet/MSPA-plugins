#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Fetch the resources needed to build the QGIS 3 plugin:
#   - the MSPA binaries for all supported platforms from MSPAstandalone
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
curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"

fetch() {
  local asset="$1"
  echo "Fetching $asset"
  curl -fsSL -o "$tmp/$asset" "$base/$asset"
  local expected actual
  expected="$(awk -v f="./$asset" '$2 == f {print $1}' "$tmp/SHA256SUMS")"
  actual="$(sha256_of "$tmp/$asset")"
  if [[ -z "$expected" || "$expected" != "$actual" ]]; then
    echo "error: checksum mismatch for $asset" >&2
    return 1
  fi
  printf '%s  %s\n' "$actual" "$asset" >> "$tmp/verified.txt"
}

fetch "mspa-${release_version}-windows-x86_64.zip"
fetch "mspa-${release_version}-windows-arm64.zip"
fetch "mspa-${release_version}-linux-x86_64-glibc2.31.tar.gz"
fetch "mspa-${release_version}-linux-aarch64.tar.gz"
fetch "mspa-${release_version}-macos-arm64.tar.gz"

mkdir -p "$tmp/win64" "$tmp/winarm" "$tmp/lin64" "$tmp/linarm" "$tmp/macarm"
unzip -q "$tmp/mspa-${release_version}-windows-x86_64.zip" -d "$tmp/win64"
unzip -q "$tmp/mspa-${release_version}-windows-arm64.zip" -d "$tmp/winarm"
tar xzf "$tmp/mspa-${release_version}-linux-x86_64-glibc2.31.tar.gz" -C "$tmp/lin64"
tar xzf "$tmp/mspa-${release_version}-linux-aarch64.tar.gz" -C "$tmp/linarm"
tar xzf "$tmp/mspa-${release_version}-macos-arm64.tar.gz" -C "$tmp/macarm"

mkdir -p mspa/binaries
cp "$(find "$tmp/win64" -name mspa_win64.exe | head -1)" \
   mspa/binaries/mspa_win64.exe
cp "$(find "$tmp/winarm" -name mspa_win64_ARM.exe | head -1)" \
   mspa/binaries/mspa_win64_ARM.exe
cp "$(find "$tmp/lin64" -name mspa_linux | head -1)" \
   mspa/binaries/mspa_linux
cp "$(find "$tmp/linarm" -name mspa_linux_ARM | head -1)" \
   mspa/binaries/mspa_linux_ARM
cp "$(find "$tmp/macarm" -name mspa_macOS_ARM | head -1)" \
   mspa/binaries/mspa_macOS_ARM
chmod 755 mspa/binaries/*

echo "Fetching the current MSPA guide"
curl -fsSL -o mspa/MSPA_Guide.pdf \
  "https://ies-ows.jrc.ec.europa.eu/gtb/GTB/MSPA_Guide.pdf"

{
  echo "MSPA version: ${engine_version}"
  echo "Release: v${release_version}"
  echo "Source: https://github.com/vogtpet/MSPAstandalone/releases/tag/v${release_version}"
  echo ""
  for name in mspa_win64.exe mspa_win64_ARM.exe mspa_linux \
              mspa_linux_ARM mspa_macOS_ARM; do
    echo "$(sha256_of "mspa/binaries/$name")  $name"
  done
} > mspa/binaries/BINARIES.txt

echo "Done"
cat mspa/binaries/BINARIES.txt
