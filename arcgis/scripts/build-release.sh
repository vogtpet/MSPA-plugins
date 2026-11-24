#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Build the MSPA ArcGIS release archive.
#
# Requires the resources fetched by scripts/fetch-resources.sh.
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "$0")/.."

version="$(tr -d '[:space:]' < VERSION)"
for file in mspa/resources/mspa_win64.exe \
            MSPA_Guide.pdf; do
  if [[ ! -f "$file" ]]; then
    echo "error: $file is missing; run scripts/fetch-resources.sh" >&2
    exit 1
  fi
done

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
root="$stage/MSPA-ArcGIS"
mkdir -p "$root"

cp -R mspa "$root/"
find "$root/mspa" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true

cp input.tif README.md VERSION MSPA_VERSION MSPA_RELEASE CHANGELOG.md \
   MSPA_Guide.pdf "$root/"
cp ../LICENSE "$root/"

chmod -R a+rX "$root"
chmod 755 "$root/mspa/resources/mspa_win64.exe"

mkdir -p dist
zip_name="MSPA-ArcGIS-${version}.zip"
out="$(pwd)/dist"
rm -f "${out}/${zip_name}" "${out}/SHA256SUMS"
( cd "$stage" && zip -qr "${out}/${zip_name}" MSPA-ArcGIS )

( cd dist
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${zip_name}" > SHA256SUMS
  else
    shasum -a 256 "${zip_name}" > SHA256SUMS
  fi )

echo "Created:"
ls -lh "dist/${zip_name}" dist/SHA256SUMS
cat dist/SHA256SUMS
