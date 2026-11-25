#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Build the MSPA QGIS 3 plugin archive.
#
# The archive contains exactly one root folder, mspa/, so that it can be
# installed with QGIS: Plugins -> Manage and Install Plugins -> Install from
# ZIP. Documentation and licenses are placed inside that folder.
#
# Requires the resources fetched by scripts/fetch-resources.sh.
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "$0")/.."

version="$(tr -d '[:space:]' < VERSION)"
for file in mspa/binaries/mspa_win64.exe \
            mspa/binaries/mspa_win64_ARM.exe \
            mspa/binaries/mspa_linux \
            mspa/binaries/mspa_linux_ARM \
            mspa/binaries/mspa_macOS_ARM \
            mspa/MSPA_Guide.pdf \
            mspa/metadata.txt; do
  if [[ ! -f "$file" ]]; then
    echo "error: $file is missing; run scripts/fetch-resources.sh" >&2
    exit 1
  fi
done

if ! grep -q "^version=${version}$" mspa/metadata.txt; then
  echo "error: mspa/metadata.txt does not match VERSION (${version})" >&2
  exit 1
fi
if ! grep -q "^PLUGIN_VERSION = \"${version}\"$" mspa/mspa.py; then
  echo "error: PLUGIN_VERSION in mspa/mspa.py does not match VERSION (${version})" >&2
  exit 1
fi

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
root="$stage"

cp -R mspa "$root/"
find "$root/mspa" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
find "$root/mspa" -name '*.pyc' -delete 2>/dev/null || true

cp README.md CHANGELOG.md VERSION MSPA_VERSION MSPA_RELEASE "$root/mspa/"
cp ../LICENSE "$root/mspa/"

chmod -R a+rX "$root"
find "$root/mspa/binaries" -type f -exec chmod 755 {} +

mkdir -p dist
zip_name="MSPA-QGIS3-${version}.zip"
out="$(pwd)/dist"
rm -f "${out}/${zip_name}" "${out}/SHA256SUMS"
( cd "$stage" && zip -qr "${out}/${zip_name}" mspa )

( cd dist
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${zip_name}" > SHA256SUMS
  else
    shasum -a 256 "${zip_name}" > SHA256SUMS
  fi )

echo "Created:"
ls -lh "dist/${zip_name}" dist/SHA256SUMS
cat dist/SHA256SUMS
