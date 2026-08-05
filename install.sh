#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")" && pwd)"
LINE='source "'$ROOT'/bobpilot.sh"'
grep -F "$LINE" ~/.zshrc >/dev/null 2>&1 || echo "$LINE" >> ~/.zshrc
echo "Installed. Restart terminal or run: source ~/.zshrc"
