#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="${ROOT_DIR:-${SCRIPT_DIR}}"

exec "${ROOT_DIR}/bin/swift-compile.sh" "$@"
