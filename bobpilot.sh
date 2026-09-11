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

# Launch Copilot with the selected model.
_launch(){
  if ! command -v copilot >/dev/null 2>&1; then
    echo "⚠️  GitHub Copilot CLI not found."
    echo "Install it with:  npm install -g @github/copilot"
    return 1
  fi
  local model="$1"
  # OpenRouter model IDs are opaque strings; the :free suffix is part of the ID.
  # COPILOT_MODEL initializes both values without pinning the wire model. This
  # lets Copilot's /model command update the provider model mid-session.
  #
  # A persisted "model" field in ~/.copilot/settings.json OVERRIDES COPILOT_MODEL,
  # so every launch would silently use that stale model instead of the one picked
  # here. Clear it so the launch pick (COPILOT_MODEL) actually takes effect.
  if [ -f "$HOME/.copilot/settings.json" ]; then
    python3 - "$HOME/.copilot/settings.json" <<'PY'
import json, sys
p = sys.argv[1]
try:
    with open(p) as f:
        cfg = json.load(f)
except Exception:
    cfg = {}
if cfg.get("model"):
    cfg.pop("model", None)
    with open(p, "w") as f:
        json.dump(cfg, f, indent=2)
PY
  fi
  COPILOT_PROVIDER_BASE_URL="$BOBPILOT_PROVIDER_BASE_URL" \
  COPILOT_PROVIDER_TYPE=openai \
  COPILOT_PROVIDER_API_KEY="$OPENROUTER_API_KEY" \
  COPILOT_MODEL="$model" \
  copilot
}

bobpilot(){
case "$1" in
free) m="${MODELS[0]}";;
latest) m="${MODELS[4]}";;
fast) m="${MODELS[2]}";;
smart) m="${MODELS[6]}";;
stable) m="${MODELS[7]}";;
premium) m="${MODELS[8]}";;
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
   if ! [[ "$c" =~ ^[0-9]+$ ]] || [ "$c" -lt 1 ] || [ "$c" -gt "${#MODELS[@]}" ]; then
     echo "✗ Invalid choice: $c"
     return 1
   fi
   if [ -n "$BASH_VERSION" ]; then
     IFS="|" read -r _ _ model <<< "${MODELS[$((c - 1))]}"
   else
     # Zsh arrays are one-based; Bash arrays are zero-based.
     IFS="|" read -r _ _ model <<< "${MODELS[$c]}"
   fi
 fi
 echo "$model" > "$LAST_MODEL"
 _launch "$model"
 return;;
esac
IFS="|" read -r _ _ model <<< "$m"
echo "$model" > "$LAST_MODEL"
_launch "$model"
}
