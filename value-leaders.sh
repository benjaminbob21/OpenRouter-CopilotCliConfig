#!/usr/bin/env bash
# value-leaders.sh — Check BobPilot paid models against OpenRouter Value Leaders top 10.
# Usage: bash value-leaders.sh
# Exit 0 if all monitored models are in the top 10; exit 1 if any fell off; exit 2 on fetch failure.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/models.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Fetching OpenRouter benchmarks + catalog..."
if ! curl -fsS --max-time 30 "https://openrouter.ai/api/frontend/v1/rankings/benchmarks" -o "$TMPDIR/benchmarks.json"; then
  echo "✗ Failed to fetch benchmarks. Check network." >&2
  exit 2
fi
if ! curl -fsS --max-time 30 "https://openrouter.ai/api/frontend/v1/catalog/models" -o "$TMPDIR/catalog.json"; then
  echo "✗ Failed to fetch catalog. Check network." >&2
  exit 2
fi

ENTRIES_JSON=$(python3 -c '
import json, sys
entries = []
for line in sys.stdin.read().splitlines():
    if "|" in line:
        entries.append(line.split("|", 2))
print(json.dumps(entries))
' <<< "$(printf '%s\n' "${MODELS[@]}")")
export ENTRIES_JSON

python3 - "$TMPDIR" <<'PY'
import json, os, sys
tmp = sys.argv[1]
bench = json.load(open(os.path.join(tmp, 'benchmarks.json')))
cat = json.load(open(os.path.join(tmp, 'catalog.json')))
aa = bench['data']['aaData']
pct = aa.get('percentilesBySlug', {})
models = cat.get('data', []) if isinstance(cat, dict) else cat

def price_of(m):
    ep = m.get('endpoint') or {}
    pricing = ep.get('pricing') or {}
    try:
        pp = float(pricing.get('prompt') or '0')
        cp = float(pricing.get('completion') or '0')
    except Exception:
        return None
    if pp <= 0 and cp <= 0:
        return None
    return (3 * pp + cp) / 4

rows = []
for m in models:
    slug = m.get('slug')
    permaslug = m.get('permaslug') or slug
    if not slug:
        continue
    p = pct.get(permaslug) or pct.get(slug)
    if not isinstance(p, dict):
        continue
    vals = [v for k, v in p.items() if isinstance(v, (int, float))]
    if not vals:
        continue
    avg = sum(vals) / len(vals)
    if avg < 50:
        continue
    pr = price_of(m)
    if pr is None or pr <= 0:
        continue
    rows.append((avg / (1e6 * pr), slug, permaslug, avg, pr))

rows.sort(key=lambda r: -r[0])
seen = set()
top10 = []
for score, slug, permaslug, avg, pr in rows:
    if slug in seen:
        continue
    seen.add(slug)
    top10.append((score, slug, permaslug, avg, pr))
    if len(top10) >= 10:
        break

entries = json.loads(os.environ.get('ENTRIES_JSON', '[]'))
monitored = []
for label, name, mid in entries:
    if mid.endswith(':free'):
        continue
    if mid == 'openai/gpt-oss-120b':
        continue
    if mid == '~deepseek/deepseek-v4-flash-latest':
        continue
    monitored.append((name, mid))

def std(mid):
    return mid.split(':')[0]

top_slugs = {slug for _, slug, _, _, _ in top10}
print("=== OpenRouter Value Leaders — Top 10 ===")
for i, (score, slug, permaslug, avg, pr) in enumerate(top10, 1):
    print(f"  {i:2d}. {slug}  (pct {avg:.1f}, ${pr * 1e6:.3f}/M, score {score:.1f})")

print("\n=== BobPilot monitored models ===")
out_list = []
for name, mid in monitored:
    ok = std(mid) in top_slugs
    print(f"  [{'IN' if ok else 'OUT'}] {name} -> {mid}")
    if not ok:
        out_list.append((name, mid))

print("\n=== RESULT ===")
if out_list:
    print("OUT_OF_TOP10")
    for name, mid in out_list:
        print(f"  {name}|{mid}")
    sys.exit(1)
else:
    print("ALL_IN_TOP10")
PY