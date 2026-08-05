#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")" && pwd)"
LINE='source "'$ROOT'/bobpilot.sh"'
grep -vF "$LINE" ~/.zshrc > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc
echo "Removed."
