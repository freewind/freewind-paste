#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEVELOPER_DIR="/System/Volumes/Data/Applications/Xcode.app/Contents/Developer"
APP_NAME="PasteBar.app"
PROJECT_FILE="${ROOT_DIR}/PasteBar.xcodeproj"
SCHEME_NAME="PasteBar"
CONFIGURATION="Debug"
APP_LOG_PATH="${ROOT_DIR}/build/dev.log"
BUILD_LOG_PATH="${ROOT_DIR}/build/xcodebuild.log"
WATCH_INTERVAL="${WATCH_INTERVAL:-1}"
WATCH_TARGETS=(
  "PasteBar"
  "Package.swift"
  "project.yml"
  "PasteBar.xcodeproj"
)

export DEVELOPER_DIR

rtk mkdir -p "${ROOT_DIR}/build"

generate_project() {
  if [[ -f "${ROOT_DIR}/project.yml" ]]; then
    rtk xcodegen generate --spec "${ROOT_DIR}/project.yml"
  fi
}

build_settings() {
  export DEVELOPER_DIR
  xcodebuild \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME_NAME}" \
    -configuration "${CONFIGURATION}" \
    -showBuildSettings 2>/dev/null
}

resolve_build_dir() {
  build_settings | awk '/^[[:space:]]*TARGET_BUILD_DIR = / { print substr($0, index($0, "=") + 2); exit }'
}

resolve_app_bundle() {
  local build_dir
  build_dir="$(resolve_build_dir)"
  if [[ -z "${build_dir}" ]]; then
    return 1
  fi

  printf '%s/%s\n' "${build_dir}" "${APP_NAME}"
}

build_app() {
  printf '\n==> Building %s (%s)\n' "${SCHEME_NAME}" "${CONFIGURATION}"
  if ! rtk xcodebuild \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME_NAME}" \
    -configuration "${CONFIGURATION}" \
    build | tee "${BUILD_LOG_PATH}"; then
    printf 'Build failed. Keep current app.\n' >&2
    return 1
  fi
}

restart_app() {
  local app_bundle app_bin

  app_bundle="$(resolve_app_bundle)"
  app_bin="${app_bundle}/Contents/MacOS/PasteBar"

  if [[ ! -x "${app_bin}" ]]; then
    printf 'Missing built app binary: %s\n' "${app_bin}" >&2
    return 1
  fi

  rtk ln -sfn "${app_bundle}" "${ROOT_DIR}/build/${APP_NAME}"
  rtk pkill -x PasteBar || true
  nohup "${app_bin}" >"${APP_LOG_PATH}" 2>&1 </dev/null &
  disown || true

  printf 'Launched app: %s\n' "${app_bundle}"
  printf 'App log: %s\n' "${APP_LOG_PATH}"
  printf 'Build log: %s\n' "${BUILD_LOG_PATH}"
}

watch_fingerprint() {
  (
    cd "${ROOT_DIR}"
    git ls-files -co --exclude-standard -- "${WATCH_TARGETS[@]}" 2>/dev/null || true
  ) |
    LC_ALL=C sort |
    while IFS= read -r rel_path; do
      [[ -f "${ROOT_DIR}/${rel_path}" ]] || continue
      stat -f '%m %N' "${ROOT_DIR}/${rel_path}"
    done |
    shasum -a 1 | awk '{print $1}'
}

generate_project
build_app
restart_app

last_fingerprint="$(watch_fingerprint)"
printf 'Watching for changes under: %s\n' "${WATCH_TARGETS[*]}"

while true; do
  sleep "${WATCH_INTERVAL}"
  next_fingerprint="$(watch_fingerprint)"
  if [[ "${next_fingerprint}" == "${last_fingerprint}" ]]; then
    continue
  fi

  printf '\n==> Change detected\n'
  sleep 0.2
  generate_project
  if build_app; then
    restart_app
    last_fingerprint="$(watch_fingerprint)"
  fi
done
