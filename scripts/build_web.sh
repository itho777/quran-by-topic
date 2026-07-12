#!/bin/bash
set -e

# Define Flutter version (matches Github Actions build)
FLUTTER_VERSION="3.24.4"

echo "=== System Information ==="
uname -a
echo "========================="

echo "=== Downloading Flutter SDK ($FLUTTER_VERSION) ==="
# Clone specific version to $HOME/flutter for execution
git clone https://github.com/flutter/flutter.git --depth 1 -b $FLUTTER_VERSION $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

echo "=== Verification ==="
flutter --version

echo "=== Build Configuration ==="
flutter config --no-analytics
flutter config --enable-web

echo "=== Getting pub packages ==="
flutter pub get

echo "=== Building Flutter Web (Release) ==="
flutter build web --release

echo "=== Build Succeeded ==="
