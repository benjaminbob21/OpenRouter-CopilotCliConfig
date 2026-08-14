#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")" && pwd)"
LINE='source "'$ROOT'/bobpilot.sh"'

detect_os(){
  case "$(uname -s)" in
    Darwin*) echo "macos";;
    MINGW*|MSYS*|CYGWIN*|Windows*) echo "windows";;
    Linux*)  echo "linux";;
    *)       echo "unknown";;
  esac
}

install_copilot(){
  local os="$1"
  echo "⚠️  GitHub Copilot CLI not found. Attempting to install for $os..."
  case "$os" in
    macos)
      if command -v brew >/dev/null 2>&1; then
        echo "✓ Using Homebrew"
        brew install copilot-cli@prerelease
      else
        echo "✓ Using official installer (curl)"
        curl -fsSL https://gh.io/copilot-install | bash
      fi
      ;;
    linux)
      echo "✓ Using official installer (curl)"
      curl -fsSL https://gh.io/copilot-install | bash
      ;;
    windows)
      if command -v winget >/dev/null 2>&1; then
        echo "✓ Using winget"
        winget install GitHub.Copilot
      elif command -v npm >/dev/null 2>&1; then
        echo "✓ Using npm"
        npm install -g @github/copilot
      else
        echo "✗ Auto-install failed on Windows."
        echo "  Run this in PowerShell:  winget install GitHub.Copilot"
        exit 1
      fi
      ;;
    *)
      echo "✗ Unrecognized OS. Please install manually:  npm install -g @github/copilot"
      exit 1
      ;;
  esac

  if command -v copilot >/dev/null 2>&1; then
    echo "✓ GitHub Copilot CLI installed"
    return 0
  else
    echo "✗ Install completed but 'copilot' is not on PATH."
    echo "  Restart your terminal and re-run install, or install manually:  npm install -g @github/copilot"
    exit 1
  fi
}

OS="$(detect_os)"
echo "Detected OS: $OS"

if ! command -v copilot >/dev/null 2>&1; then
  install_copilot "$OS"
else
  echo "✓ GitHub Copilot CLI detected"
fi

grep -F "$LINE" ~/.zshrc >/dev/null 2>&1 || echo "$LINE" >> ~/.zshrc

SKILL_DIR="$HOME/.copilot/skills/model-picker"
mkdir -p "$SKILL_DIR"
cp "$ROOT/skills/model-picker/SKILL.md" "$SKILL_DIR/SKILL.md"

echo "Installed BobPilot and model-picker skill. Restart terminal or run: source ~/.zshrc"
