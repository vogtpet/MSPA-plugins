#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Download the MSPA binaries named in MSPA_VERSION and lay them out below
# resources/ in the layout used by RMSPA.
#
# The archives are taken unchanged from the MSPAstandalone release, which is
# the reference build of MSPA. Checksums are verified against the SHA256SUMS
# asset of that release.
#
# Usage: ./scripts/fetch-binaries.sh
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "$0")/.."

version="$(tr -d '[:space:]' < MSPA_VERSION)"
if [[ -z "$version" ]]; then
  echo "error: MSPA_VERSION is empty" >&2
  exit 1
fi

repo="vogtpet/MSPAstandalone"
base="https://github.com/${repo}/releases/download/v${version}"

assets=(
  "mspa-${version}-linux-x86_64-glibc2.31.tar.gz"
  "mspa-${version}-linux-aarch64.tar.gz"
  "mspa-${version}-macos-arm64.tar.gz"
  "mspa-${version}-windows-x86_64.zip"
  "mspa-${version}-windows-arm64.zip"
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    echo "error: no SHA-256 tool found (sha256sum, shasum or openssl)" >&2
    return 1
  fi
}

echo "Fetching MSPA ${version} from ${repo}"
for asset in "${assets[@]}" SHA256SUMS; do
  echo "  ${asset}"
  curl -fsSL -o "${tmp}/${asset}" "${base}/${asset}"
done

echo "Verifying checksums"
while read -r expected file; do
  [[ -z "${expected:-}" ]] && continue
  file="${file#./}"
  [[ -f "${tmp}/${file}" ]] || continue
  actual="$(sha256_of "${tmp}/${file}")"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "error: checksum mismatch for ${file}" >&2
    exit 1
  fi
done < "${tmp}/SHA256SUMS"

echo "Extracting"
rm -rf resources
mkdir -p resources/linux-x86_64 resources/linux-aarch64 resources/macos-arm64 \
         resources/windows-x86_64 resources/windows-arm64

mkdir -p "${tmp}/linux-x86_64" "${tmp}/linux-aarch64" "${tmp}/macos-arm64" \
         "${tmp}/windows-x86_64" "${tmp}/windows-arm64"

tar -xzf "${tmp}/mspa-${version}-linux-x86_64-glibc2.31.tar.gz" \
    --strip-components=1 -C "${tmp}/linux-x86_64"
tar -xzf "${tmp}/mspa-${version}-linux-aarch64.tar.gz" \
    --strip-components=1 -C "${tmp}/linux-aarch64"
tar -xzf "${tmp}/mspa-${version}-macos-arm64.tar.gz" \
    --strip-components=1 -C "${tmp}/macos-arm64"
unzip -qj "${tmp}/mspa-${version}-windows-x86_64.zip" -d "${tmp}/windows-x86_64"
unzip -qj "${tmp}/mspa-${version}-windows-arm64.zip" -d "${tmp}/windows-arm64"

cp "${tmp}/linux-x86_64/mspa_linux"          resources/linux-x86_64/
cp "${tmp}/linux-aarch64/mspa_linux_ARM"     resources/linux-aarch64/
cp "${tmp}/macos-arm64/mspa_macOS_ARM"       resources/macos-arm64/
cp "${tmp}/macos-arm64/libdeflate.0.dylib"   resources/macos-arm64/
cp "${tmp}/macos-arm64/libLerc.4.dylib"      resources/macos-arm64/
cp "${tmp}/windows-x86_64/mspa_win64.exe"    resources/windows-x86_64/
cp "${tmp}/windows-arm64/mspa_win64_ARM.exe" resources/windows-arm64/

find resources -type f ! -name '*.dylib' -exec chmod 755 {} +

echo "Recording provenance"
{
  echo "MSPA version: ${version}"
  echo "Source: https://github.com/${repo}/releases/tag/v${version}"
  echo "Fetched: $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo ""
  (cd resources && for f in \
      linux-x86_64/mspa_linux \
      linux-aarch64/mspa_linux_ARM \
      macos-arm64/mspa_macOS_ARM \
      macos-arm64/libdeflate.0.dylib \
      macos-arm64/libLerc.4.dylib \
      windows-x86_64/mspa_win64.exe \
      windows-arm64/mspa_win64_ARM.exe; do
      echo "$(sha256_of "$f")  $f"
    done)
} > resources/BINARIES.txt

echo "Done"
cat resources/BINARIES.txt
