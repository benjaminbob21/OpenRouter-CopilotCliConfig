#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")" && pwd)"
LINE='source "'$ROOT'/bobpilot.sh"'
grep -vF "$LINE" ~/.zshrc > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc
rm -rf "$HOME/.copilot/skills/model-picker"
echo "Removed BobPilot and model-picker skill."
