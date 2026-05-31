#!/usr/bin/env bash
# setup.sh — Run once before opening in Xcode.
# Clones sdk-swift into vendor/ and patches out the .unsafeFlags line
# (which only suppresses warnings and blocks SPM from accepting it as a dependency).

set -euo pipefail

TAG="v3.0.0-6476-aa83168"
DEST="vendor/sdk-swift"

cd "$(dirname "$0")"

if [ -d "$DEST/.git" ]; then
  echo "✓ $DEST already exists, skipping clone."
else
  echo "→ Cloning sdk-swift $TAG …"
  mkdir -p vendor
  git clone \
    --branch "$TAG" \
    --depth 1 \
    https://github.com/bitwarden/sdk-swift.git \
    "$DEST"
  echo "✓ Cloned."
fi

# Patch: remove the .unsafeFlags line from the vendored Package.swift.
# This line only suppresses compiler warnings — removing it is safe.
PKGFILE="$DEST/Package.swift"
if grep -q 'unsafeFlags' "$PKGFILE"; then
  echo "→ Patching $PKGFILE to remove .unsafeFlags …"
  # Remove the entire swiftSettings line (may span one line)
  sed -i '' '/\.unsafeFlags/d' "$PKGFILE"
  sed -i '' '/swiftSettings:/d' "$PKGFILE"
  echo "✓ Patched."
else
  echo "✓ No .unsafeFlags found (already patched or changed upstream)."
fi

echo ""
echo "Done. Open BitwardenBar/Package.swift in Xcode and build."
