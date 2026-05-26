#!/usr/bin/env bash
set -euo pipefail

MIN_IOS_VERSION="${MIN_IOS_VERSION:-13.0}"
OUTPUT_XCFRAMEWORK="${OUTPUT_XCFRAMEWORK:-libsoratun.xcframework}"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
IOS_DIR="${BUILD_DIR}/ios"
SIM_DIR="${BUILD_DIR}/sim"

GO_CLANGWRAP="$(go env GOROOT)/misc/ios/clangwrap.sh"

echo "==> Clean"
rm -rf "${BUILD_DIR}" "${ROOT_DIR}/${OUTPUT_XCFRAMEWORK}"
mkdir -p "${IOS_DIR}/include" "${SIM_DIR}/include"

echo "==> Build for iOS device"
CGO_ENABLED=1 \
GOOS=ios \
GOARCH=arm64 \
SDK=iphoneos \
CC="${GO_CLANGWRAP}" \
CGO_CFLAGS="-isysroot $(xcrun --sdk iphoneos --show-sdk-path) -miphoneos-version-min=${MIN_IOS_VERSION}" \
CGO_LDFLAGS="-isysroot $(xcrun --sdk iphoneos --show-sdk-path) -miphoneos-version-min=${MIN_IOS_VERSION}" \
go build -ldflags="-s -w" -buildmode=c-archive -tags ios \
  -o "${IOS_DIR}/libsoratun.a" .

cp "${IOS_DIR}/libsoratun.h" "${IOS_DIR}/include/libsoratun.h"

echo "==> Build for iOS simulator"
CGO_ENABLED=1 \
GOOS=ios \
GOARCH=arm64 \
SDK=iphonesimulator \
CC="${GO_CLANGWRAP}" \
CGO_CFLAGS="-isysroot $(xcrun --sdk iphonesimulator --show-sdk-path) -mios-simulator-version-min=${MIN_IOS_VERSION}" \
CGO_LDFLAGS="-isysroot $(xcrun --sdk iphonesimulator --show-sdk-path) -mios-simulator-version-min=${MIN_IOS_VERSION}" \
go build -ldflags="-s -w" -buildmode=c-archive -tags ios \
  -o "${SIM_DIR}/libsoratun.a" .

cp "${SIM_DIR}/libsoratun.h" "${SIM_DIR}/include/libsoratun.h"

echo "==> Create XCFramework"
xcodebuild -create-xcframework \
  -library "${IOS_DIR}/libsoratun.a" -headers "${IOS_DIR}/include" \
  -library "${SIM_DIR}/libsoratun.a" -headers "${SIM_DIR}/include" \
  -output "${ROOT_DIR}/${OUTPUT_XCFRAMEWORK}"

echo "==> Verify"
plutil -p "${ROOT_DIR}/${OUTPUT_XCFRAMEWORK}/Info.plist"

echo "==> Done: ${OUTPUT_XCFRAMEWORK}"