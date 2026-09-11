---
name: value-leaders
description: Check that all BobPilot paid models are still in OpenRouter's Value Leaders top 10, and remove any that fell off (like when a model's price rises and it drops out of value territory). Use when the user asks to check value leaders, verify models are still good value, or clean up models that wasted credits. Excludes free models, GPT OSS 120B, and the always-latest alias.
---

# BobPilot Value Leaders Check

When invoked, verify every monitored BobPilot model is still in OpenRouter's Value Leaders top 10, and remove any that fell off.

## Step 1 — Run the check

Run this from the BobPilot repo (`/Users/bob/Downloads/BobOpenRouter`):

```bash
bash value-leaders.sh
```

This fetches OpenRouter's live benchmarks + model catalog and computes the Value Leaders ranking (the same algorithm the Discover page uses: avg benchmark percentile / weighted price, percentile ≥ 50, deduped by clean slug, top 10).

## Step 2 — Interpret the result

- **`ALL_IN_TOP10`** — every monitored model is fine. Report the top-10 list briefly and stop. No edits.
- **`OUT_OF_TOP10`** — the script lists each fallen model as `Name|model-id`. Proceed to Step 3.
- **Exit code 2 / fetch failure** — network or OpenRouter issue. Report it and stop; do NOT edit anything.

## Step 3 — Remove fallen models (only after user confirms)

For each model listed under `OUT_OF_TOP10`, remove it from all three places. **Always confirm with the user before editing** — show which models fell off and what you'll remove.

### 3a. `models.sh`

Delete the `"LABEL|Name|model-id"` line for the fallen model.

### 3b. `skills/model-picker/SKILL.md`

Delete the matching `- Name — \`model-id\`` bullet from the Choices list.

### 3c. `bobpilot.sh` — fix the case mapping

The `bobpilot` case uses **hardcoded array indices** that shift when models are removed. After editing `models.sh`, recompute every index by re-reading the array:

```bash
source models.sh
for i in "${!MODELS[@]}"; do IFS="|" read -r l n id <<< "${MODELS[$i]}"; echo "$i $n -> $id"; done
```

Then update the case mapping so each alias points at the correct new index:
- `free` → index of the first `:free` model
- `latest` → index of the `~deepseek/deepseek-v4-flash-latest` model
- `fast` → index of the first `⚡ Fast`/`🟠 Fast` model
- `smart` → index of the `🔵 Smart` model
- `stable` → index of the `🔵 Stable` model
- `premium` → index of the `🟣 Premium` model

If a removed model was the only one for an alias (e.g. the only `🟣 Premium`), point that alias at the next-highest remaining model and tell the user which alias you remapped.

## Step 4 — Verify

Re-run `bash value-leaders.sh` and confirm the fallen models are gone from the monitored list. Then tell the user what changed and that they should re-run `bash install.sh` to refresh the installed model-picker skill.

## Notes

- **Never** remove free models (`:free`), `openai/gpt-oss-120b`, or `~deepseek/deepseek-v4-flash-latest` — the script already excludes them from monitoring.
- The value list uses dated permaslugs (e.g. `deepseek/deepseek-v4-flash-20260731`); the script matches on the clean slug (e.g. `deepseek/deepseek-v4-flash-0731`), so a model is "in" if its clean slug appears in the top 10.
- If the user wants to swap a removed model for a replacement, suggest one from the current top-10 list that isn't already configured.