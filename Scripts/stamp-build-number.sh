#!/bin/bash
#
# Stamps the built app's Info.plist with a build number derived from git.
#
# CFBundleVersion  = number of commits on the current branch (monotonic,
#                    identical for the same checkout on any machine, and
#                    needs no project-file churn to increment).
# LCSourceVersion  = `git describe` output, including a -dirty marker, so a
#                    build made from uncommitted work is identifiable.
#
# Runs as a build phase before code signing. Never fails the build: if git
# is unavailable the static CURRENT_PROJECT_VERSION from the project file
# is left in place.

set -uo pipefail

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ ! -f "${PLIST}" ]; then
    echo "warning: stamp-build-number: no Info.plist at ${PLIST}; skipping"
    exit 0
fi

cd "${SRCROOT}" || exit 0

BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null)
if [ -z "${BUILD_NUMBER}" ]; then
    echo "warning: stamp-build-number: git unavailable; keeping CURRENT_PROJECT_VERSION"
    exit 0
fi

SOURCE_VERSION=$(git describe --always --dirty --tags 2>/dev/null || git rev-parse --short HEAD)

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${PLIST}" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${BUILD_NUMBER}" "${PLIST}"

/usr/libexec/PlistBuddy -c "Set :LCSourceVersion ${SOURCE_VERSION}" "${PLIST}" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :LCSourceVersion string ${SOURCE_VERSION}" "${PLIST}"

echo "stamp-build-number: build ${BUILD_NUMBER} (${SOURCE_VERSION})"
