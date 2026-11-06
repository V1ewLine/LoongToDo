#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
BUILD="$PWD/.build/manual"
mkdir -p "$BUILD" "$PWD/.build/clang-cache"
python3 scripts/prepare-toolchain.py
ARCH="$(uname -m)"
xcrun swiftc -O -swift-version 5 -target "$ARCH-apple-macosx14.0" -vfsoverlay .build/toolchain/overlay.json \
  -module-cache-path "$PWD/.build/clang-cache" -emit-module -emit-library -static \
  -module-name TodoCore Sources/TodoCore/*.swift \
  -emit-module-path "$BUILD/TodoCore.swiftmodule" -o "$BUILD/libTodoCore.a"
xcrun swiftc -O -swift-version 5 -target "$ARCH-apple-macosx14.0" -vfsoverlay .build/toolchain/overlay.json \
  -module-cache-path "$PWD/.build/clang-cache" -I "$BUILD" -L "$BUILD" -lTodoCore \
  -parse-as-library Sources/LoongToDo/*.swift -o "$BUILD/LoongToDo"
APP="$PWD/dist/LoongTodo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/LoongToDo" "$APP/Contents/MacOS/LoongToDo"
cp Resources/Info.plist "$APP/Contents/Info.plist"
xcrun swiftc -O -swift-version 5 -vfsoverlay .build/toolchain/overlay.json -module-cache-path "$PWD/.build/clang-cache" \
  -parse-as-library Sources/LoongToDo/BrandMark.swift scripts/make-icon.swift -o "$BUILD/make-icon"
"$BUILD/make-icon" "$PWD/.build/AppIcon.iconset" "$PWD/Resources/Brand"
python3 scripts/pack-icon.py .build/AppIcon.iconset "$BUILD/AppIcon.icns"
python3 scripts/install-app-icon.py "$BUILD/AppIcon.icns" "$APP"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
printf 'Built: %s\n' "$APP"
