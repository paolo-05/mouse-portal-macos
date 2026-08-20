#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
VERSION="${VERSION:-0.1.0}"

"$PROJECT_DIR/scripts/build-app.sh"
cd "$PROJECT_DIR/.build/app"
ditto -c -k --sequesterRsrc --keepParent MousePortal.app "MousePortal-$VERSION-macOS.zip"
echo "$PROJECT_DIR/.build/app/MousePortal-$VERSION-macOS.zip"
