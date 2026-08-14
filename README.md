# BobOpenRouter

Portable launcher for GitHub Copilot CLI + OpenRouter.

## Prerequisites

- [GitHub Copilot CLI](https://github.com/github/copilot-cli) — required:
  ```bash
  npm install -g @github/copilot
  ```
  (Install will auto-detect your OS — macOS/Windows/Linux — and install it for you if missing.)

## Install

1. Create `.env`:

```
OPENROUTER_API_KEY=sk-or-v1-...
```

2. Run:

```bash
./install.sh
```

3. Restart your shell.

Use:
- `copilot` -> GitHub credits
- `bobpilot` -> OpenRouter
