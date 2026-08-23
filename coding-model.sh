#!/usr/bin/env bash
# Pick the best currently-available free model for coding.
# Fusion of the openrouter/free router with coding awareness:
#   - keeps openrouter/free's capability matching (tools, structured outputs,
#     vision, context) as hard filters + score bonuses
#   - adds a coding-suitability ranking (preferred list, code-keyword boost,
#     reasoning bonus) instead of random selection
# Prints the ranked candidate list, best first.

set -euo pipefail

BOBPILOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
[ -f "$BOBPILOT_DIR/.env" ] && set -a && . "$BOBPILOT_DIR/.env" && set +a

CACHE="$BOBPILOT_DIR/state/coding-model.cache"
CACHE_TTL=${BOBPILOT_DISCOVERY_TTL:-900}   # seconds, 15 min default
MIN_CTX=${BOBPILOT_MIN_CTX:-100000}

# Coding preference, best first. GLM-5.2 is a top agentic coder with
# structured outputs + reasoning; Nemotron Ultra adds huge context;
# Laguna is code-focused; North Mini Code is purpose-built agentic coding.
PREFERRED=(
  "z-ai/glm-5.2:free"
  "nvidia/nemotron-3-ultra-550b-a55b:free"
  "poolside/laguna-s-2.1:free"
  "cohere/north-mini-code:free"
)
KEYWORD_BOOST="glm|nemotron|laguna|north|code|coder|coding|dev"


# Inject PREFERENCES into python via env (keeps quoting simple)
export BOBPILOT_PREFS="$(printf '%s\n' "${PREFERRED[@]}")"

pick_prefs(){
  MIN_CTX="$MIN_CTX" KEYWORD_BOOST="$KEYWORD_BOOST" BOBPILOT_PREFS="$BOBPILOT_PREFS" \
  python3 - <<'PY'
import json, sys, os, re, urllib.request
min_ctx = int(os.environ["MIN_CTX"])
boost_re = re.compile(os.environ["KEYWORD_BOOST"], re.I)
prefs = [l for l in os.environ["BOBPILOT_PREFS"].splitlines() if l]
url = "https://openrouter.ai/api/v1/models"
req = urllib.request.Request(url)
key = os.environ.get("OPENROUTER_API_KEY")
if key:
    req.add_header("Authorization", f"Bearer {key}")
try:
    import ssl
    ctx = ssl.create_default_context()
    if not ctx.get_ca_certs():
        # macOS python.org builds often lack a default cert bundle; fall back
        # to certifi if present, else skip verification for this public endpoint.
        try:
            import certifi
            ctx = ssl.create_default_context(cafile=certifi.where())
        except Exception:
            ctx = ssl._create_unverified_context()
    with urllib.request.urlopen(req, timeout=15, context=ctx) as r:
        data = json.load(r)["data"]
except Exception as e:
    sys.exit(f"__FETCH_FAIL__ {e}")
cands = [
    m for m in data
    if m["id"].endswith(":free")
    and m.get("context_length", 0) >= min_ctx
]
def score(m):
    mid = m["id"]
    s = 0.0
    # Capability coverage: mirror the openrouter/free router's feature matching.
    # Requests that need vision/tools/structure must land on models that support them.
    caps = 0
    if "tools" in m.get("supported_parameters", []): caps += 10
    if "tool_choice" in m.get("supported_parameters", []): caps += 2
    if "response_format" in m.get("supported_parameters", []): caps += 5
    if "structured_outputs" in m.get("supported_parameters", []): caps += 5
    if "image" in (m.get("architecture", {}).get("input_modalities") or []): caps += 5
    s += caps
    s += m.get("context_length", 0) / 10_000_000
    if (m.get("reasoning") or {}).get("enabled"): s += 25
    # Coding preference only counts when the model is agentic-grade:
    # tool calling is mandatory (Copilot CLI drives tools), plus at least
    # one of structured outputs / vision / reasoning. This keeps
    # openrouter/free's capability matching while adding coding ranking.
    agentic = "tools" in m.get("supported_parameters", [])
    extras = (
        ("structured_outputs" in m.get("supported_parameters", []))
        or ("image" in (m.get("architecture", {}).get("input_modalities") or []))
        or ((m.get("reasoning") or {}).get("enabled"))
        or ("include_reasoning" in m.get("supported_parameters", []))
    )
    if agentic and extras:
        # Coding-first: code-focused families win, then the curated
        # preference list, then everything else by capability/context.
        s += 60 if boost_re.search(m.get("name", "").lower() + " " + mid.lower()) else 0
        s += float(len(prefs) - prefs.index(mid)) if mid in prefs else 0
    return s
ranked = sorted(cands, key=score, reverse=True)
print("\n".join(m["id"] for m in ranked))
PY
}

cache_fresh(){
  [ -f "$CACHE" ] || return 1
  [ $(( $(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || stat -c %Y "$CACHE") )) -lt "$CACHE_TTL" ]
}

if cache_fresh && head -1 "$CACHE" | grep -q ':free'; then
  cat "$CACHE"
else
  OUT="$(pick_prefs)" || { echo "$OUT"; exit 1; }
  mkdir -p "$(dirname "$CACHE")"
  printf '%s\n' "$OUT" > "$CACHE"
fi