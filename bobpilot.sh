#!/usr/bin/env bash
# Determine script directory in both bash and zsh
if [ -n "$BASH_SOURCE" ]; then
  SCRIPT_PATH="$BASH_SOURCE"
else
  # zsh specific variable to get script filename
  SCRIPT_PATH="${(%):-%N}"
fi
BOBPILOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
source "$BOBPILOT_DIR/config.sh"
source "$BOBPILOT_DIR/models.sh"

_launch(){
  if ! command -v copilot >/dev/null 2>&1; then
    echo "⚠️  GitHub Copilot CLI not found."
    echo "Install it with:  npm install -g @github/copilot"
    return 1
  fi
  local model="$1"
  local provider_model_id="${model%:free}"
  COPILOT_PROVIDER_BASE_URL="$BOBPILOT_PROVIDER_BASE_URL" \
  COPILOT_PROVIDER_TYPE=openai \
  COPILOT_PROVIDER_API_KEY="$OPENROUTER_API_KEY" \
  COPILOT_MODEL="$model" \
  COPILOT_PROVIDER_MODEL_ID="$provider_model_id" \
  COPILOT_PROVIDER_WIRE_MODEL="$model" \
  copilot
}

bobpilot(){
case "$1" in
free) m="${MODELS[0]}";;
latest) m="${MODELS[2]}";;
fast) m="${MODELS[3]}";;
smart) m="${MODELS[4]}";;
stable) m="${MODELS[5]}";;
premium) m="${MODELS[6]}";;
last)
 [ -f "$LAST_MODEL" ] && _launch "$(cat "$LAST_MODEL")"
 return;;
models)
 i=1
 for e in "${MODELS[@]}"; do IFS="|" read -r l n id <<< "$e"; printf "%d) %s %s\n" "$i" "$l" "$n"; ((i++)); done
 return;;
*)
 echo "=== BobPilot ==="
 [ -f "$LAST_MODEL" ] && echo "Last: $(cat "$LAST_MODEL")"
 i=1
 for e in "${MODELS[@]}"; do IFS="|" read -r l n id <<< "$e"; printf "%d) %-10s %s\n" "$i" "$l" "$n"; ((i++)); done
 printf "Choice (Enter=last/free): "
 read c
 if [ -z "$c" ]; then
   if [ -f "$LAST_MODEL" ]; then model=$(cat "$LAST_MODEL"); else model="$DEFAULT_MODEL"; fi
 else
   IFS="|" read -r _ _ model <<< "${MODELS[$((c))]}"
 fi
 echo "$model" > "$LAST_MODEL"
 _launch "$model"
 return;;
esac
IFS="|" read -r _ _ model <<< "$m"
echo "$model" > "$LAST_MODEL"
_launch "$model"
}
