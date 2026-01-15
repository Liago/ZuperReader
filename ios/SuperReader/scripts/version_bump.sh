#!/bin/bash

#  version_bump.sh
#  SuperReader
#
#  Created by Antigravity on 15/01/2026.
#  Copyright © 2026 Liago. All rights reserved.

set -e

echo "Starting Configurable Version Bump..."

# 1. Get the Git Commit Count (Build Number)
# Use 'git rev-list --count HEAD' to get a monotonically increasing integer.
# If git is not found or fails, default to 1 to prevent build failure, but warn.
if ! git_count=$(git rev-list --count HEAD 2>/dev/null); then
    echo "warning: Unable to get git commit count. Defaulting build number to 1."
    git_count=1
fi

BUILD_NUMBER="$git_count"
echo "Detected Build Number (Git Step): $BUILD_NUMBER"

# 2. Locate the Info.plist in the build product
# Xcode exposes ${TARGET_BUILD_DIR} and ${INFOPLIST_PATH}
APP_INFO_PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

echo "Target Info.plist path: ${APP_INFO_PLIST}"

if [ ! -f "${APP_INFO_PLIST}" ]; then
    echo "error: Info.plist not found at ${APP_INFO_PLIST}"
    exit 1
fi

# 3. Update CFBundleVersion in the compiled Info.plist
# We use PlistBuddy to modify the plist binary/text in place.
# We do NOT touch the source Info.plist to avoid dirty git changes.
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "${APP_INFO_PLIST}"

echo "Successfully updated CFBundleVersion to $BUILD_NUMBER in ${APP_INFO_PLIST}"
