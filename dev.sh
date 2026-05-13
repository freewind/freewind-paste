#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEVELOPER_DIR="/System/Volumes/Data/Applications/Xcode.app/Contents/Developer"
DERIVED_DATA_PATH="${ROOT_DIR}/.build-xcode/dev-derived-data"
APP_NAME="PasteBar.app"
APP_BUNDLE="${DERIVED_DATA_PATH}/Build/Products/Debug/${APP_NAME}"
APP_BIN="${APP_BUNDLE}/Contents/MacOS/PasteBar"
INJECTION_APP="/Applications/InjectionIII.app"
LOG_PATH="${ROOT_DIR}/build/dev.log"

export DEVELOPER_DIR

if [[ ! -d "${INJECTION_APP}" ]]; then
  printf 'Missing InjectionIII: %s\n' "${INJECTION_APP}" >&2
  printf 'Install it from: https://github.com/johnno1962/InjectionIII/releases\n' >&2
  exit 1
fi

rtk mkdir -p "${ROOT_DIR}/build"
rtk xcodegen generate --spec "${ROOT_DIR}/project.yml"

rtk xcodebuild \
  -project "${ROOT_DIR}/PasteBar.xcodeproj" \
  -scheme PasteBar \
  -configuration Debug \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  build

if [[ ! -x "${APP_BIN}" ]]; then
  printf 'Missing built app binary: %s\n' "${APP_BIN}" >&2
  exit 1
fi

rtk ln -sfn "${APP_BUNDLE}" "${ROOT_DIR}/build/${APP_NAME}"
rtk pkill -x PasteBar || true

env \
  INJECTION_DIRECTORIES="${ROOT_DIR}" \
  "${APP_BIN}" >"${LOG_PATH}" 2>&1 &

printf 'Launched app: %s\n' "${APP_BUNDLE}"
printf 'Injection watch root: %s\n' "${ROOT_DIR}"
printf 'Dev log: %s\n' "${LOG_PATH}"
