#!/usr/bin/env python3
"""BobPilot coding router.

A local, per-request equivalent of OpenRouter's `openrouter/free`, but
coding-aware. Requests sent to the pseudo-model `bobpilot/code` are rewritten
to the best currently-available free model, chosen fresh for every request:

  1. Discover  - live OpenRouter model list (cached, auto-refreshes)
  2. Filter    - free + tool-calling + minimum context (openrouter/free-style
                 capability matching, tuned for agentic coding)
  3. Score     - fully automatic, derived from OpenRouter's own metadata
                 (capability completeness, parameter count, context, reasoning,
                 code signal in name/description, freshness). No manual list.

CLI:
  python3 router.py pick [N]     print top N model ids (default 1)
  python3 router.py serve [PORT] start the per-request proxy (default 8317)

The proxy forwards everything to https://openrouter.ai/api/v1. Only requests
whose model is `bobpilot/code` are rewritten; any concrete model id set via
/model passes through untouched.

Hosting elsewhere: the server binds 0.0.0.0 and is stateless apart from a
local cache file, so it can run on any VM/container. Point clients at
http://<host>:8317/v1 (put it behind TLS or an SSH tunnel - it speaks plain
HTTP). Set BOBPILOT_PROVIDER_BASE_URL and OPENROUTER_API_KEY in the proxy's
environment; clients then need no OpenRouter key at all.
"""

import json
import math
import os
import re
import ssl
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
except NameError:
    BASE_DIR = os.getcwd()

STATE_DIR = os.path.join(BASE_DIR, "state")
CACHE_FILE = os.path.join(STATE_DIR, "models-cache.json")
ROUTER_ID = "bobpilot/code"
OPENROUTER_BASE = os.environ.get("BOBPILOT_PROVIDER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
CACHE_TTL = int(os.environ.get("BOBPILOT_DISCOVERY_TTL", "900"))
MIN_CTX = int(os.environ.get("BOBPILOT_MIN_CTX", "100000"))
UPSTREAM_TIMEOUT = int(os.environ.get("BOBPILOT_UPSTREAM_TIMEOUT", "300"))

_code_re = re.compile(r"\b(code|coder|coding|developer|software|agentic)\b", re.I)
_params_re = re.compile(r"(\d+(?:\.\d+)?)\s*b\b", re.I)

_lock = threading.Lock()


def _load_cache():
    try:
        with open(CACHE_FILE) as f:
            c = json.load(f)
        if time.time() - c["fetched_at"] < CACHE_TTL and c.get("data"):
            return c["data"]
    except Exception:
        pass
    return None


def _store_cache(data):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(CACHE_FILE, "w") as f:
            json.dump({"fetched_at": time.time(), "data": data}, f)
    except Exception:
        pass


def fetch_models():
    with _lock:
        data = _load_cache()
        if data is not None:
            return data
        req = urllib.request.Request(OPENROUTER_BASE + "/models")
        key = os.environ.get("OPENROUTER_API_KEY")
        if key:
            req.add_header("Authorization", "Bearer " + key)
        ctx = ssl.create_default_context()
        if not ctx.get_ca_certs():
            try:
                import certifi
                ctx = ssl.create_default_context(cafile=certifi.where())
            except Exception:
                ctx = ssl._create_unverified_context()
        with urllib.request.urlopen(req, timeout=15, context=ctx) as r:
            data = json.load(r)["data"]
        _store_cache(data)
        return data


def _parse_active_params(m):
    """Active parameter count matters more than total for capability/speed."""
    text = m.get("name", "") + " " + m.get("description", "")
    m_active = re.search(r"(\d+(?:\.\d+)?)\s*b\s+active", text, re.I)
    if m_active:
        return float(m_active.group(1))
    nums = [float(x) for x in _params_re.findall(text)]
    # Prefer the smaller of two numbers ("Xb active out of Yb total").
    return min(nums) if len(nums) >= 2 else (nums[0] if nums else 0.0)


def eligible(m):
    return (
        m["id"].endswith(":free")
        and "tools" in m.get("supported_parameters", [])
        and m.get("context_length", 0) >= MIN_CTX
    )


def score(m):
    """Fully automatic score - no curated lists. Higher is better."""
    s = 0.0
    sp = m.get("supported_parameters", [])
    # Capability completeness (agentic coding needs these).
    if "tool_choice" in sp: s += 3
    if "response_format" in sp: s += 6
    if "structured_outputs" in sp: s += 6
    if "image" in (m.get("architecture", {}).get("input_modalities") or []): s += 4
    # Reasoning depth helps multi-step agent work.
    if (m.get("reasoning") or {}).get("enabled"):
        s += 15
    elif "reasoning" in sp or "include_reasoning" in sp:
        s += 6
    # Model size from metadata (active params generally track coding ability).
    b = _parse_active_params(m)
    s += min(30.0, 10.0 * math.log10(b + 1) * 6) if b else 0.0
    # Context window.
    s += min(10.0, math.log10(max(m.get("context_length", 0), 1) / 1000.0) * 2.5)
    # Code signal straight from OpenRouter's own name/description.
    if _code_re.search(m.get("name", "") + " " + m.get("description", "")):
        s += 8
    # Freshness: new free models get a fading boost (up to +8 over ~6 months).
    created = m.get("created", 0)
    if created:
        age_days = max(0.0, (time.time() - created) / 86400.0)
        s += max(0.0, 8.0 - age_days / 45.0)
    return s


def ranked():
    cands = [m for m in fetch_models() if eligible(m)]
    return [m["id"] for m in sorted(cands, key=score, reverse=True)]


def pick():
    r = ranked()
    if not r:
        raise RuntimeError("no eligible free coding models found")
    return r[0]


def _log(msg):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(os.path.join(STATE_DIR, "router.log"), "a") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + msg + "\n")
    except Exception:
        pass


class ProxyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

    def _upstream(self, method, body=None):
        url = OPENROUTER_BASE + self.path
        req = urllib.request.Request(url, data=body, method=method)
        for h in ("Content-Type", "Accept", "Authorization", "X-Title",
                  "HTTP-Referer", "X-OpenRouter-Metadata"):
            v = self.headers.get(h)
            if v:
                req.add_header(h, v)
        if not self.headers.get("Authorization"):
            key = os.environ.get("OPENROUTER_API_KEY")
            if key:
                req.add_header("Authorization", "Bearer " + key)
        ctx = ssl.create_default_context()
        if not ctx.get_ca_certs():
            try:
                import certifi
                ctx = ssl.create_default_context(cafile=certifi.where())
            except Exception:
                ctx = ssl._create_unverified_context()
        return urllib.request.urlopen(req, timeout=UPSTREAM_TIMEOUT, context=ctx)

    def _rewrite_body(self):
        if not self.headers.get("Content-Length"):
            return None
        raw = self.rfile.read(int(self.headers["Content-Length"]))
        try:
            payload = json.loads(raw)
            if isinstance(payload, dict) and payload.get("model") == ROUTER_ID:
                chosen = pick()
                payload["model"] = chosen
                _log(f"{ROUTER_ID} -> {chosen}")
                raw = json.dumps(payload).encode()
        except Exception as e:
            _log(f"rewrite skipped ({e}); passing body through unchanged")
        return raw

    def do_GET(self):
        if self.path == "/health":
            body = json.dumps({"ok": True, "router": ROUTER_ID}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self._forward(None)

    def do_POST(self):
        self._forward(self._rewrite_body())

    def _forward(self, body):
        method = "POST" if body is not None or self.command == "POST" else "GET"
        last_err = None
        for attempt in range(3):
            try:
                up = self._upstream(method, body)
                break
            except Exception as e:
                # Free-tier rate limits (HTTP 429) are common; retry the same
                # request after a short backoff before giving up.
                status = getattr(getattr(e, "__cause__", None), "code", None) or getattr(e, "code", None)
                if status == 429 and attempt < 2:
                    _log(f"upstream 429, retry {attempt + 1}/2")
                    time.sleep(5 * (attempt + 1))
                    continue
                last_err = e
        else:
            up = None
        if up is None:
            msg = json.dumps({"error": {"message": f"router upstream error: {last_err}"}}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
            return
        try:
            self.send_response(up.status)
            for h in ("Content-Type", "X-Request-Id"):
                v = up.headers.get(h)
                if v:
                    self.send_header(h, v)
            self.send_header("Connection", "close")
            self.end_headers()
            while True:
                chunk = up.read(4096)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            up.close()


def serve(port):
    srv = ThreadingHTTPServer(("0.0.0.0", port), ProxyHandler)
    srv.daemon_threads = True
    with open(os.path.join(STATE_DIR, "router.pid"), "w") as f:
        f.write(str(os.getpid()))
    _log(f"serving {ROUTER_ID} on 0.0.0.0:{port} (base {OPENROUTER_BASE})")
    srv.serve_forever()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "pick"
    if cmd == "pick":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 1
        for mid in ranked()[:n]:
            print(mid)
    elif cmd == "serve":
        serve(int(sys.argv[2]) if len(sys.argv) > 2 else int(os.environ.get("BOBPILOT_ROUTER_PORT", "8317")))
    else:
        sys.exit(f"unknown command: {cmd}")
