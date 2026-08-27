#!/bin/bash
#
# Forces macOS to forget the cached icon for a built copy of the app.
#
# macOS caches app icons in IconServices keyed by bundle path, so a rebuild
# that changes the icon usually keeps showing the previous one — including
# in the Dock of an app you just relaunched. The bundle is correct; only
# the cache is stale. Nothing here needs sudo.
#
# Usage: Scripts/refresh-icon-cache.sh [path-to-Liquid Chat.app]
#        defaults to the Debug build in DerivedData.

set -uo pipefail

APP="${1:-$(ls -d ~/Library/Developer/Xcode/DerivedData/Liquid_Chat-*/Build/Products/Debug/"Liquid Chat.app" 2>/dev/null | head -1)}"

if [ -z "${APP}" ] || [ ! -d "${APP}" ]; then
    echo "error: no app bundle found; pass one explicitly" >&2
    exit 1
fi

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "Refreshing icon for ${APP}"
osascript -e 'tell application "Liquid Chat" to quit' 2>/dev/null || true
touch "${APP}"
"${LSREGISTER}" -f -R -trusted "${APP}"
killall iconservicesagent 2>/dev/null || true
killall Dock 2>/dev/null || true

echo "Done. Relaunch the app to see the new icon."
