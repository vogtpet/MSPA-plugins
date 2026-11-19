#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Download the current MSPA guide from the JRC MSPA page.
#
# Usage: ./scripts/fetch-guide.sh [destination]
#        (default: www/MSPA_Guide.pdf, relative to the r/ directory)
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "$0")/.."

dest="${1:-www/MSPA_Guide.pdf}"
url="https://ies-ows.jrc.ec.europa.eu/gtb/GTB/MSPA_Guide.pdf"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

echo "Fetching ${url}"
curl -fsSL --retry 3 -o "$tmp" "$url"

if [ ! -s "$tmp" ]; then
  echo "error: the downloaded file is empty" >&2
  exit 1
fi
if [ "$(head -c 4 "$tmp")" != "%PDF" ]; then
  echo "error: the downloaded file is not a PDF" >&2
  exit 1
fi

mkdir -p "$(dirname "$dest")"
mv "$tmp" "$dest"
chmod 644 "$dest"

echo "Saved ${dest} ($(wc -c < "$dest" | tr -d ' ') bytes)"
