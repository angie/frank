#!/bin/zsh
# Build Frank and install it to ~/Applications.
# Installing outside .build keeps the login item and notification
# registrations alive across `swift package clean`.
set -euo pipefail

cd "$(dirname "$0")/.."
scripts/make-app.sh

DEST="$HOME/Applications/Frank.app"
mkdir -p "$HOME/Applications"
pkill -x Frank 2>/dev/null || true
rm -rf "$DEST"
ditto .build/Frank.app "$DEST"
open "$DEST"
echo "installed $DEST"
