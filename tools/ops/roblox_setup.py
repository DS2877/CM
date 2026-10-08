#!/usr/bin/env python3
"""Creator Hub setup via Open Cloud, run ONLY inside GitHub Actions (.github/workflows/ops.yml).

- Creates every game pass, gift developer product and developer product listed in
  src/shared/Config/Products.luau that doesn't exist yet (matched by name, so re-running is safe).
- Writes the resulting Roblox IDs back into Products.luau (passId / giftProductId / productId).
- Sets the start place's Max Players (serverSize).
- Writes a sanitized log to tools/ops/ops-log.md (status codes + response bodies, never the key).

The API key comes from the environment variable ROBLOX_KEY (the Actions secret). It is never
printed or written to disk.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

UNIVERSE = "10769879996"
PLACE = "87874194731556"
SERVER_SIZE = 8
PRODUCTS_FILE = "src/shared/Config/Products.luau"
LOG_FILE = "tools/ops/ops-log.md"
API = "https://apis.roblox.com"

KEY = os.environ.get("ROBLOX_KEY", "")
log_lines = []


def log(line):
    # Defensive: never let the key reach the log, whatever an API echoes back.
    if KEY:
        line = line.replace(KEY, "***")
    print(line)
    log_lines.append(line)


def request(method, url, body=None, content_type=None):
    headers = {"x-api-key": KEY}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.status, r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            text = e.read().decode("utf-8", "replace")
            if e.code == 429 and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            return e.code, text
        except urllib.error.URLError as e:
            if attempt < 3:
                time.sleep(3)
                continue
            return 0, str(e)
    return 0, "retries exhausted"


def multipart(fields):
    boundary = "----cm" + uuid.uuid4().hex
    parts = []
    for k, v in fields.items():
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode("utf-8")
        )
    parts.append(f"--{boundary}--\r\n".encode("utf-8"))
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def short(text, n=600):
    text = text.strip().replace("\n", " ")
    return text if len(text) <= n else text[:n] + "…"


ID_KEYS = ("productId", "developerProductId", "gamePassId", "id", "targetId")


def find_id(obj):
    if isinstance(obj, dict):
        for k in ID_KEYS:
            v = obj.get(k)
            if isinstance(v, int) and v > 0:
                return v
            if isinstance(v, str) and v.isdigit():
                return int(v)
    return None


def items_of(obj):
    """Every dict with a 'name' inside a list response, wherever the API nests it."""
    out = []
    if isinstance(obj, list):
        for x in obj:
            if isinstance(x, dict) and "name" in x:
                out.append(x)
    elif isinstance(obj, dict):
        for v in obj.values():
            if isinstance(v, list):
                out.extend(items_of(v))
    return out


def list_existing(kind):
    path = (
        f"/game-passes/v1/universes/{UNIVERSE}/game-passes/creator"
        if kind == "pass"
        else f"/developer-products/v2/universes/{UNIVERSE}/developer-products/creator"
    )
    found = {}
    token = ""
    for _ in range(20):
        url = f"{API}{path}?pageSize=50" + (f"&pageToken={token}" if token else "")
        status, text = request("GET", url)
        log(f"- LIST {kind}: HTTP {status} {short(text, 300)}")
        if status != 200:
            return None
        data = json.loads(text or "{}")
        for it in items_of(data):
            i = find_id(it)
            if i:
                found[it["name"]] = i
        token = data.get("nextPageToken") if isinstance(data, dict) else None
        if not token:
            break
    return found


def create(kind, name, description, price):
    path = (
        f"/game-passes/v1/universes/{UNIVERSE}/game-passes"
        if kind == "pass"
        else f"/developer-products/v2/universes/{UNIVERSE}/developer-products"
    )
    body, ctype = multipart(
        {"name": name, "description": description, "price": str(price), "isForSale": "true"}
    )
    status, text = request("POST", API + path, body, ctype)
    log(f"- CREATE {kind} '{name}' ({price} R$): HTTP {status} {short(text)}")
    if status not in (200, 201):
        return None
    try:
        return find_id(json.loads(text))
    except json.JSONDecodeError:
        return None


def parse_catalog(src):
    """(id, name, description, price, isPass) for every entry in Products.luau."""
    out = []
    for m in re.finditer(
        r'id = "(\w+)",\s*name = "([^"]*)",\s*description = "([^"]*)",\s*price = (\d+),\s*(\w+) =', src
    ):
        out.append((m.group(1), m.group(2), m.group(3), int(m.group(4)), m.group(5) == "passId"))
    return out


def set_field(src, entry_id, field, value):
    start = src.index(f'id = "{entry_id}",')
    nxt = src.find("id = ", start + 5)
    end = nxt if nxt != -1 else len(src)
    block = src[start:end]
    new_block, n = re.subn(rf"\b{field} = \d+", f"{field} = {value}", block, count=1)
    if n != 1:
        raise RuntimeError(f"{field} not found for {entry_id}")
    return src[:start] + new_block + src[end:]


def main():
    if not KEY:
        print("ROBLOX_KEY missing", file=sys.stderr)
        return 1
    log(f"# Creator Hub setup – {time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime())}")
    log("")
    with open(PRODUCTS_FILE, encoding="utf-8") as f:
        src = f.read()
    catalog = parse_catalog(src)
    log(f"Catalog: {len(catalog)} entries in Products.luau")
    log("")

    log("## Listing existing")
    passes = list_existing("pass")
    products = list_existing("product")
    log("")
    log("## Creating")
    ok = True
    for entry_id, name, desc, price, is_pass in catalog:
        if is_pass:
            pid = (passes or {}).get(name) or create("pass", name, desc, price)
            if pid:
                src = set_field(src, entry_id, "passId", pid)
            else:
                ok = False
            gift_name = f"Gift: {name}"
            gid = (products or {}).get(gift_name) or create(
                "product", gift_name, f"Gift the {name} pass to a friend. {desc}", price
            )
            if gid:
                src = set_field(src, entry_id, "giftProductId", gid)
            else:
                ok = False
            log(f"  -> {entry_id}: pass {pid}, gift {gid}")
        else:
            pid = (products or {}).get(name) or create("product", name, desc, price)
            if pid:
                src = set_field(src, entry_id, "productId", pid)
            else:
                ok = False
            log(f"  -> {entry_id}: product {pid}")
    with open(PRODUCTS_FILE, "w", encoding="utf-8") as f:
        f.write(src)

    log("")
    log("## Max Players")
    body = json.dumps({"serverSize": SERVER_SIZE}).encode()
    status, text = request(
        "PATCH",
        f"{API}/cloud/v2/universes/{UNIVERSE}/places/{PLACE}?updateMask=serverSize",
        body,
        "application/json",
    )
    log(f"- PATCH serverSize={SERVER_SIZE}: HTTP {status} {short(text, 300)}")
    ok = ok and status == 200

    log("")
    log("Result: " + ("ALL OK" if ok else "SOME STEPS FAILED (see HTTP codes above)"))
    with open(LOG_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(log_lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
