#!/usr/bin/env bash
# Determine repo root dynamically for Bash and Zsh
if [ -n "$BASH_SOURCE" ]; then
  REPO_PATH="$BASH_SOURCE"
else
  REPO_PATH="${(%):-%x}"
fi
BOBPILOT_DIR="$(cd "$(dirname "$REPO_PATH")" && pwd)"
set -a
[ -f "$BOBPILOT_DIR/.env" ] && source "$BOBPILOT_DIR/.env"
set +a
export BOBPILOT_PROVIDER_BASE_URL=https://openrouter.ai/api/v1
export BOBPILOT_STATE="$BOBPILOT_DIR/state"
mkdir -p "$BOBPILOT_STATE"
LAST_MODEL="$BOBPILOT_STATE/last-model"
DEFAULT_MODEL="nvidia/nemotron-3-ultra-550b-a55b:free"
