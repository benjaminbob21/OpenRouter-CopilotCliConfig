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

### `bobpilot code` — per-request coding router

Launches Copilot against a tiny local proxy (`router.py`) that routes **every
request** to the best free model at that moment — the per-request behavior of
`openrouter/free`, but ranked for coding instead of random:

1. **Discover** — live OpenRouter model list, cached 15 min, self-updating
2. **Filter** — free + tool-calling + ≥100k context (capability matching)
3. **Score** — fully automatic from OpenRouter metadata (capability
   completeness, active parameter count, context, reasoning, code signal,
   freshness); new free models join the pool on their own, no lists to edit

Only requests with model `bobpilot/code` are rewritten — `/model <id>` for a
concrete model passes straight through. 429s from free-tier providers are
retried with backoff. The proxy auto-starts on first `bobpilot code` and can
be stopped with `bobpilot code-stop`. Logs: `state/router.log`.

**Hosting remotely:** the proxy is stateless (only a local cache file) and
binds `0.0.0.0`, so it runs on any VM/container with Python 3:

```bash
BOBPILOT_PROVIDER_BASE_URL=https://openrouter.ai/api/v1 \
OPENROUTER_API_KEY=sk-or-v1-... python3 router.py serve 8317
```

Put it behind TLS (caddy/nginx) or an SSH tunnel — it speaks plain HTTP — then
set `COPILOT_PROVIDER_BASE_URL=http(s)://<host>:8317/v1` on clients and
allow-list that URL in `~/.copilot/settings.json` (`allowedUrls`). With
`OPENROUTER_API_KEY` set on the proxy, clients need no key. Tune
`BOBPILOT_ROUTER_PORT`, `BOBPILOT_DISCOVERY_TTL`, `BOBPILOT_MIN_CTX`.

**Local proxy URL allow-list:** Copilot CLI only calls URLs in
`allowedUrls` (`~/.copilot/settings.json`). Add the router once:

```bash
copilot /allow-url http://127.0.0.1:8317   # or edit allowedUrls manually
```
