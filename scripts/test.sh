#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
BUILD="$PWD/.build/checks"
mkdir -p "$BUILD" "$PWD/.build/clang-cache"
python3 scripts/prepare-toolchain.py
ARCH="$(uname -m)"
xcrun swiftc -swift-version 5 -target "$ARCH-apple-macosx14.0" -vfsoverlay .build/toolchain/overlay.json \
  -module-cache-path "$PWD/.build/clang-cache" -emit-module -emit-library -static \
  -module-name TodoCore Sources/TodoCore/*.swift \
  -emit-module-path "$BUILD/TodoCore.swiftmodule" -o "$BUILD/libTodoCore.a"
xcrun swiftc -swift-version 5 -target "$ARCH-apple-macosx14.0" -vfsoverlay .build/toolchain/overlay.json \
  -module-cache-path "$PWD/.build/clang-cache" -I "$BUILD" -L "$BUILD" -lTodoCore \
  -parse-as-library Tests/TodoCoreTests/*.swift -o "$BUILD/TodoCoreChecks"
"$BUILD/TodoCoreChecks"
