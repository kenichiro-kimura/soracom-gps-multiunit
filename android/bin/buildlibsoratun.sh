#!/usr/bin/env bash
set -euo pipefail

MIN_ANDROID_API="${MIN_ANDROID_API:-29}"
OUTPUT_DIR="${OUTPUT_DIR:-android-libs}"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

resolve_ndk_home() {
  if [[ -n "${ANDROID_NDK_HOME:-}" ]]; then
    echo "${ANDROID_NDK_HOME}"
    return
  fi
  if [[ -n "${ANDROID_NDK_ROOT:-}" ]]; then
    echo "${ANDROID_NDK_ROOT}"
    return
  fi
  if [[ -n "${ANDROID_HOME:-}" && -d "${ANDROID_HOME}/ndk" ]]; then
    find "${ANDROID_HOME}/ndk" -mindepth 1 -maxdepth 1 -type d | sort | tail -n1
    return
  fi
  if [[ -n "${ANDROID_SDK_ROOT:-}" && -d "${ANDROID_SDK_ROOT}/ndk" ]]; then
    find "${ANDROID_SDK_ROOT}/ndk" -mindepth 1 -maxdepth 1 -type d | sort | tail -n1
    return
  fi
}

ANDROID_NDK_HOME="$(resolve_ndk_home)"
if [[ -z "${ANDROID_NDK_HOME}" || ! -d "${ANDROID_NDK_HOME}" ]]; then
  echo "ANDROID_NDK_HOME / ANDROID_NDK_ROOT が見つかりません。"
  exit 1
fi

PREBUILT_DIR="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt"
HOST_TAG="$(find "${PREBUILT_DIR}" -mindepth 1 -maxdepth 1 -type d | sort | head -n1 | xargs -n1 basename)"
TOOLCHAIN_BIN="${PREBUILT_DIR}/${HOST_TAG}/bin"

if [[ ! -d "${TOOLCHAIN_BIN}" ]]; then
  echo "NDK toolchain が見つかりません: ${TOOLCHAIN_BIN}"
  exit 1
fi

echo "==> Clean"
rm -rf "${ROOT_DIR}/${OUTPUT_DIR}"
mkdir -p "${ROOT_DIR}/${OUTPUT_DIR}/jniLibs" "${ROOT_DIR}/${OUTPUT_DIR}/include"

build_abi() {
  local abi="$1"
  local goarch="$2"
  local cc_prefix="$3"
  local goarm="${4:-}"

  local abi_dir="${ROOT_DIR}/${OUTPUT_DIR}/jniLibs/${abi}"
  mkdir -p "${abi_dir}"

  echo "==> Build ${abi}"
  if [[ -n "${goarm}" ]]; then
    CGO_ENABLED=1 \
    GOOS=android \
    GOARCH="${goarch}" \
    GOARM="${goarm}" \
    CC="${TOOLCHAIN_BIN}/${cc_prefix}${MIN_ANDROID_API}-clang" \
    go build -ldflags="-s -w" -buildmode=c-shared \
      -o "${abi_dir}/libsoratun.so" .
  else
    CGO_ENABLED=1 \
    GOOS=android \
    GOARCH="${goarch}" \
    CC="${TOOLCHAIN_BIN}/${cc_prefix}${MIN_ANDROID_API}-clang" \
    go build -ldflags="-s -w" -buildmode=c-shared \
      -o "${abi_dir}/libsoratun.so" .
  fi

  cp "${abi_dir}/libsoratun.h" "${ROOT_DIR}/${OUTPUT_DIR}/include/libsoratun.h"
}

build_abi "arm64-v8a" "arm64" "aarch64-linux-android"
build_abi "armeabi-v7a" "arm" "armv7a-linux-androideabi" "7"
build_abi "x86_64" "amd64" "x86_64-linux-android"

echo "==> Done: ${OUTPUT_DIR}"
