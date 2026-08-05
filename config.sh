#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"
set +a
export BOBPILOT_PROVIDER_BASE_URL=https://openrouter.ai/api/v1
export BOBPILOT_STATE="$SCRIPT_DIR/state"
mkdir -p "$BOBPILOT_STATE"
LAST_MODEL="$BOBPILOT_STATE/last-model"
DEFAULT_MODEL="nvidia/nemotron-3-ultra-550b-a55b:free"
