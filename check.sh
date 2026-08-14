#!/bin/bash
# Minimal sanity check for the policy pages.
#
# These 11 files are deployed to purposelabstudio.com/privacy-policies/ but live
# in a separate repo, so they sit outside the main site's test suite entirely.
# That blind spot is how all 11 shipped with no meta description until Bing's
# Site Scan found it from the outside on 2026-08-01.
#
# Deliberately dependency-free: no npm, no node. These files change twice a year.
#
# Usage: bash check.sh

set -euo pipefail

fails=0
checked=0

for f in *.html; do
  checked=$((checked + 1))
  grep -qi '<title>[^<]\+</title>' "$f" || { echo "FAIL  no <title>          $f"; fails=$((fails + 1)); }
  grep -qi 'name="description" content="[^"]\+"' "$f" || { echo "FAIL  no meta description  $f"; fails=$((fails + 1)); }
  grep -qi '<meta name="viewport"' "$f" || { echo "FAIL  no viewport         $f"; fails=$((fails + 1)); }
done

# Folio keeps notebook content local by default. The only cloud copy is one the
# person explicitly asks Folio to place in their own Google Drive or iCloud
# account. Legal copy must name that boundary and must not promise that content
# is never transmitted under any circumstances.
for f in folio.html folio-terms.html; do
  grep -qi 'personal Google Drive or iCloud account you choose' "$f" || {
    echo "FAIL  Folio personal-cloud boundary missing  $f"
    fails=$((fails + 1))
  }
done
grep -qi 'never sent to Folio or PurposeLab servers' folio.html || {
  echo "FAIL  Folio server boundary missing  folio.html"
  fails=$((fails + 1))
}
if grep -q 'never read, access, analyze, or transmit your journal entries' folio.html; then
  echo "FAIL  Folio still makes an absolute no-transmission claim  folio.html"
  fails=$((fails + 1))
fi

# A loop over an empty glob would report a clean pass.
if [ "$checked" -lt 5 ]; then
  echo "FAIL  only $checked files checked — run this from the repo root"
  fails=$((fails + 1))
fi

if [ "$fails" -gt 0 ]; then
  echo "$fails problem(s) across $checked pages"
  exit 1
fi
echo "PASS  $checked policy pages: title, description and viewport all present"
