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
- `bobpilot` -> OpenRouter (interactive model picker)
- `bobpilot code` -> smart coding router

### `bobpilot code`

Launches Copilot with the best free model for coding, chosen dynamically:
queries OpenRouter's live model list, keeps `:free` models with agentic-grade
capability (tool calling + structured outputs/vision/reasoning — the same
feature-matching idea as OpenRouter's `openrouter/free` router), then ranks
them by a coding preference list instead of picking randomly. The ranking is
cached for 15 min (`state/coding-model.cache`; tune via
`BOBPILOT_DISCOVERY_TTL`, minimum context via `BOBPILOT_MIN_CTX`). Edit the
`PREFERRED` array in `coding-model.sh` as new free models appear.
