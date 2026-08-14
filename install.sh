#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")" && pwd)"
LINE='source "'$ROOT'/bobpilot.sh"'
grep -F "$LINE" ~/.zshrc >/dev/null 2>&1 || echo "$LINE" >> ~/.zshrc

SKILL_DIR="$HOME/.copilot/skills/model-picker"
mkdir -p "$SKILL_DIR"
cp "$ROOT/skills/model-picker/SKILL.md" "$SKILL_DIR/SKILL.md"

echo "Installed BobPilot and model-picker skill. Restart terminal or run: source ~/.zshrc"
