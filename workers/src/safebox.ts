// ---------------------------------------------------------------------------
// Vany SafeBox — Encrypted Dead-Drop with Alphanumeric Access
//
// Flow (all encryption is client-side):
//   1. Client generates 8-char box ID [A-Z0-9], user sets their own password
//   2. Client derives AES-256-GCM key via PBKDF2(boxId+":"+password, 100K iterations)
//   3. Client encrypts plaintext, computes box_hash = SHA256(boxId)[:16]
//   4. Client POSTs {box_hash, ciphertext, iv} to /box
//   5. Server stores opaque blob in KV with TTL=24h
//   6. Recipient GETs /box/:id, decrypts client-side with password
//
// Routes:
//   POST /box           → store {box_hash, ciphertext, iv}
//   GET  /box/:id       → fetch {ciphertext, iv, created_at, expires_at}
//   GET  /box           → web UI (browser) or CLI help (curl)
// ---------------------------------------------------------------------------

const CHARSET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const BOX_ID_LENGTH = 8;
const BOX_ID_REGEX = /^[A-Z0-9]{8}$/;

/** Validate box ID: exactly 8 uppercase alphanumeric chars */
function validateBoxId(id: string): boolean {
  return BOX_ID_REGEX.test(id);
}

/** Generate a random box ID */
function generateBoxId(): string {
  const arr = new Uint32Array(BOX_ID_LENGTH);
  crypto.getRandomValues(arr);
  return Array.from(arr, v => CHARSET[v % CHARSET.length]).join("");
}

/** SHA-256(boxId)[:16] → KV address */
async function hashBoxId(boxId: string): Promise<string> {
  const data = new TextEncoder().encode(boxId);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, "0")).join("").slice(0, 16);
}

interface BoxData {
  ciphertext: string;
  iv: string;
  created_at: number;
  expires_at: number;
}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const BOX_TTL = 86400; // 24h
const MAX_CIPHERTEXT_SIZE = 100000; // ~50KB plaintext after base64

// ---- Handlers ----

/** POST /box — store encrypted box (client already encrypted) */
export async function handleBoxCreate(request: Request, kv: KVNamespace): Promise<Response> {
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "Invalid JSON body" }, { status: 400, headers: CORS_HEADERS });
  }

  // CLI mode: server-side encryption (plaintext + password)
  if (typeof body.plaintext === 'string' && typeof body.password === 'string') {
    const plaintext = (body.plaintext as string).trim();
    const password = body.password as string;
    if (!plaintext) return Response.json({ error: "Empty message" }, { status: 400, headers: CORS_HEADERS });
    if (!password) return Response.json({ error: "Empty password" }, { status: 400, headers: CORS_HEADERS });
    if (new TextEncoder().encode(plaintext).length > 50000) {
      return Response.json({ error: "Content too large (max ~50KB)" }, { status: 413, headers: CORS_HEADERS });
    }
    const boxId = generateBoxId();
    const boxHash = await hashBoxId(boxId);
    const existing = await kv.get(`box:${boxHash}`);
    if (existing) return Response.json({ error: "Collision. Try again." }, { status: 409, headers: CORS_HEADERS });
    const key = await deriveKey(boxId, password);
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const ct = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(plaintext));
    const now = Date.now();
    const data: BoxData = {
      ciphertext: btoa(String.fromCharCode(...new Uint8Array(ct))),
      iv: btoa(String.fromCharCode(...iv)),
      created_at: now,
      expires_at: now + BOX_TTL * 1000,
    };
    await kv.put(`box:${boxHash}`, JSON.stringify(data), { expirationTtl: BOX_TTL });
    return Response.json({ ok: true, box_id: boxId, expires_at: data.expires_at, ttl: BOX_TTL }, { headers: CORS_HEADERS });
  }

  // Web mode: client already encrypted
  const boxHash = body.box_hash as string | undefined;
  const ciphertext = body.ciphertext as string | undefined;
  const iv = body.iv as string | undefined;
  if (!boxHash || !ciphertext || !iv) {
    return Response.json({ error: "Missing box_hash, ciphertext, or iv" }, { status: 400, headers: CORS_HEADERS });
  }

  // Validate box_hash is hex, 16 chars
  if (!/^[0-9a-f]{16}$/.test(boxHash)) {
    return Response.json({ error: "Invalid box_hash format" }, { status: 400, headers: CORS_HEADERS });
  }

  if (ciphertext.length > MAX_CIPHERTEXT_SIZE) {
    return Response.json({ error: "Content too large (max ~50KB)" }, { status: 413, headers: CORS_HEADERS });
  }

  // Check collision
  const existing = await kv.get(`box:${boxHash}`);
  if (existing) {
    return Response.json({ error: "Box ID collision. Try again." }, { status: 409, headers: CORS_HEADERS });
  }

  const now = Date.now();
  const data: BoxData = {
    ciphertext,
    iv,
    created_at: now,
    expires_at: now + BOX_TTL * 1000,
  };

  await kv.put(`box:${boxHash}`, JSON.stringify(data), { expirationTtl: BOX_TTL });

  return Response.json({
    ok: true,
    box_hash: boxHash,
    expires_at: data.expires_at,
    ttl: BOX_TTL,
  }, { headers: CORS_HEADERS });
}

/** Derive AES-256-GCM key from boxId + password (same as client-side) */
async function deriveKey(boxId: string, pass: string): Promise<CryptoKey> {
  const raw = new TextEncoder().encode(boxId + ":" + pass);
  const km = await crypto.subtle.importKey("raw", raw, "PBKDF2", false, ["deriveKey"]);
  return crypto.subtle.deriveKey(
    { name: "PBKDF2", salt: new TextEncoder().encode("vany-safebox-v1"), iterations: 100000, hash: "SHA-256" },
    km, { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]
  );
}

/** GET /box/:id — fetch encrypted box, optionally decrypt if ?pass= provided */
export async function handleBoxFetch(boxIdSegment: string, kv: KVNamespace, password?: string): Promise<Response> {
  const boxId = decodeURIComponent(boxIdSegment).toUpperCase();
  if (!validateBoxId(boxId)) {
    return Response.json(
      { error: "Invalid box ID. Use 8 characters (A-Z, 0-9), e.g. A3K9X2B7" },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const boxHash = await hashBoxId(boxId);
  const raw = await kv.get(`box:${boxHash}`);
  if (!raw) {
    return Response.json({ error: "Box not found or expired" }, { status: 404, headers: CORS_HEADERS });
  }

  const data: BoxData = JSON.parse(raw);

  // If password provided, decrypt and return plaintext
  if (password) {
    try {
      const key = await deriveKey(boxId, password);
      const ct = Uint8Array.from(atob(data.ciphertext), c => c.charCodeAt(0));
      const iv = Uint8Array.from(atob(data.iv), c => c.charCodeAt(0));
      const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, ct);
      return new Response(new TextDecoder().decode(plain) + "\n", {
        headers: { ...CORS_HEADERS, "Content-Type": "text/plain; charset=utf-8" },
      });
    } catch {
      return Response.json({ error: "Wrong password" }, { status: 403, headers: CORS_HEADERS });
    }
  }

  return Response.json({
    ciphertext: data.ciphertext,
    iv: data.iv,
    created_at: data.created_at,
    expires_at: data.expires_at,
  }, { headers: CORS_HEADERS });
}

/** GET /box — web UI (browser) or CLI help (curl) */
export function handleBoxPage(isCli: boolean): Response {
  if (isCli) {
    return new Response(CLI_HELP, { headers: { ...CORS_HEADERS, "Content-Type": "text/plain; charset=utf-8" } });
  }
  return new Response(WEB_PAGE, { headers: { ...CORS_HEADERS, "Content-Type": "text/html; charset=utf-8" } });
}

const CLI_HELP = `#!/bin/bash
# Vany SafeBox — Interactive CLI
# Usage: curl -s vany.sh/box | bash
set -e
G='\\033[0;32m'; P='\\033[0;35m'; D='\\033[2m'; B='\\033[1m'; R='\\033[0m'
Y='\\033[0;33m'; RED='\\033[0;31m'
BASE="https://vany.sh"
echo ""
echo -e "  \${P}\${B}SafeBox\${R} \${D}— Encrypted Dead-Drop\${R}"
echo -e "  \${D}8-char ID + password. Auto-expires in 24h.\${R}"
echo ""
echo -e "  \${G}1\${R}) Create a new box"
echo -e "  \${G}2\${R}) Open an existing box"
echo ""
read -rp "  Choose [1/2]: " choice < /dev/tty
if [[ "$choice" == "1" ]]; then
  echo ""
  read -rsp "  Password: " pass < /dev/tty; echo ""
  [[ -z "$pass" ]] && { echo -e "  \${RED}Password required.\${R}"; exit 1; }
  echo -e "  \${D}Message (Ctrl-D when done):\${R}"
  msg=$(cat < /dev/tty)
  [[ -z "$msg" ]] && { echo ""; echo -e "  \${RED}Message required.\${R}"; exit 1; }
  echo ""
  echo -e "  \${D}Encrypting...\${R}"
  if command -v jq &>/dev/null; then
    json=$(jq -n --arg p "$pass" --arg m "$msg" '{plaintext:$m,password:$p}')
  elif command -v python3 &>/dev/null; then
    json=$(printf '%s' "$msg" | python3 -c "import json,sys;print(json.dumps({'plaintext':sys.stdin.read(),'password':sys.argv[1]}))" "$pass")
  else
    echo -e "  \${RED}jq or python3 required for JSON encoding.\${R}"; exit 1
  fi
  resp=$(curl -s -w '\\n%{http_code}' -X POST "$BASE/box" -H "Content-Type: application/json" -d "$json")
  code=$(echo "$resp" | tail -1)
  body=$(echo "$resp" | sed '$d')
  if [[ "$code" != "200" ]]; then
    err=$(echo "$body" | grep -o '"error":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "  \${RED}\${err:-Request failed ($code)}\${R}"; exit 1
  fi
  box_id=$(echo "$body" | grep -o '"box_id":"[^"]*"' | head -1 | cut -d'"' -f4)
  echo ""
  echo -e "  \${G}\${B}Box created!\${R}"
  echo ""
  echo -e "  Box ID:   \${P}\${B}\${box_id}\${R}"
  echo -e "  Expires:  \${Y}24 hours\${R}"
  echo ""
  echo -e "  \${D}Retrieve:\${R}"
  echo "  curl -s \\"\${BASE}/box/\${box_id}?pass=YOUR_PASSWORD\\""
  echo ""
elif [[ "$choice" == "2" ]]; then
  echo ""
  read -rp "  Box ID: " box_id < /dev/tty
  box_id=$(echo "$box_id" | tr '[:lower:]' '[:upper:]')
  [[ ! "$box_id" =~ ^[A-Z0-9]{8}$ ]] && { echo -e "  \${RED}Invalid box ID (8 chars, A-Z 0-9).\${R}"; exit 1; }
  read -rsp "  Password: " pass < /dev/tty; echo ""
  [[ -z "$pass" ]] && { echo -e "  \${RED}Password required.\${R}"; exit 1; }
  echo ""
  echo -e "  \${D}Decrypting...\${R}"
  resp=$(curl -s -w '\\n%{http_code}' -G "$BASE/box/$box_id" --data-urlencode "pass=$pass")
  code=$(echo "$resp" | tail -1)
  body=$(echo "$resp" | sed '$d')
  if [[ "$code" != "200" ]]; then
    err=$(echo "$body" | grep -o '"error":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "  \${RED}\${err:-Failed (HTTP $code)}\${R}"; exit 1
  fi
  echo ""
  echo -e "  \${G}\${B}Content:\${R}"
  echo ""
  echo "$body"
  echo ""
else
  echo -e "  \${RED}Invalid choice.\${R}"; exit 1
fi
`;

const WEB_PAGE = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Vany SafeBox</title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>&#x1F510;</text></svg>">
<style>
:root {
  --bg: #232323; --bg2: #343434; --bg3: #404040;
  --text: #e7e7e7; --dim: #9ab0a6; --muted: #6a7a70;
  --green: #2eb787; --lgreen: #9acfa0; --blue: #6090e3;
  --orange: #d59719; --red: #a25138; --purple: #a492ff;
  --yellow: #e5e885; --border: #4a4a4a;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'SF Mono', Monaco, Consolas, monospace; background: var(--bg); color: var(--text); min-height: 100vh; display: flex; justify-content: center; align-items: center; padding: 20px; }
.app { max-width: 420px; width: 100%; }
.header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }
.header h1 { color: var(--purple); font-size: 16px; }
.header .ttl { color: var(--dim); font-size: 10px; }
.top-row { display: flex; gap: 12px; margin-bottom: 12px; }
.field { flex: 1; }
.field label { display: block; color: var(--dim); font-size: 10px; margin-bottom: 4px; }
.field input { width: 100%; background: var(--bg); border: 1px solid var(--border); color: var(--text); font-family: inherit; font-size: 13px; padding: 10px; text-align: center; letter-spacing: 2px; }
.field input:focus { outline: none; border-color: var(--purple); }
.field input::placeholder { color: var(--muted); letter-spacing: 2px; }
.msg-label { color: var(--dim); font-size: 10px; margin-bottom: 4px; }
textarea { width: 100%; background: var(--bg); border: 1px solid var(--border); color: var(--text); font-family: inherit; font-size: 12px; padding: 10px; resize: vertical; min-height: 120px; }
textarea:focus { outline: none; border-color: var(--purple); }
textarea[readonly] { color: var(--lgreen); }
.charcount { text-align: right; margin-top: 4px; color: var(--muted); font-size: 10px; }
.action-btn { width: 100%; margin-top: 12px; padding: 12px; font-family: inherit; font-size: 13px; font-weight: 600; cursor: pointer; border: 1px solid var(--purple); background: var(--purple); color: var(--bg); transition: all 0.15s; text-transform: uppercase; letter-spacing: 1px; }
.action-btn:hover { opacity: 0.9; }
.action-btn:disabled { opacity: 0.3; cursor: not-allowed; }
.action-btn.open { background: var(--green); border-color: var(--green); }
.action-btn.generate { background: var(--bg2); border-color: var(--purple); color: var(--purple); }
.status { margin-top: 12px; padding: 10px; font-size: 11px; }
.status.ok { background: rgba(46,183,135,0.1); border: 1px solid var(--green); color: var(--green); }
.status.err { background: rgba(162,81,56,0.1); border: 1px solid var(--red); color: var(--red); }
.cli-cmd { margin-top: 8px; padding: 8px; background: var(--bg); border: 1px solid var(--border); font-size: 10px; color: var(--dim); word-break: break-all; cursor: pointer; }
.cli-cmd:hover { border-color: var(--purple); }
.footer { text-align: center; margin-top: 20px; color: var(--muted); font-size: 10px; }
.footer a { color: var(--blue); text-decoration: none; }
.hidden { display: none; }
</style>
</head>
<body>
<div class="app">
  <div class="header">
    <h1>&#x1F510; SafeBox</h1>
    <span class="ttl">24h auto-expire</span>
  </div>

  <div class="top-row">
    <div class="field">
      <label>Box ID</label>
      <input type="text" id="box-id" placeholder="--------" maxlength="8" style="text-transform:uppercase;" />
    </div>
    <div class="field">
      <label>Password</label>
      <input type="password" id="box-pass" placeholder="********" />
    </div>
  </div>

  <div class="msg-label">Message</div>
  <textarea id="box-msg" placeholder="Type or paste your secret..." maxlength="50000"></textarea>
  <div class="charcount"><span id="charcount">0 / 50,000</span></div>

  <button class="action-btn generate" id="action-btn" onclick="doAction()">Generate</button>

  <div id="status-area" class="hidden"></div>
  <div id="cli-area" class="hidden">
    <div class="cli-cmd" id="cli-cmd" onclick="copyCli()" title="Click to copy"></div>
  </div>

  <div class="footer">
    Server never sees plaintext. &middot; <a href="https://vany.sh">vany.sh</a>
  </div>
</div>

<script>
const CHARSET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

function genId() {
  const a = new Uint32Array(8);
  crypto.getRandomValues(a);
  return Array.from(a, v => CHARSET[v % CHARSET.length]).join("");
}

async function boxHash(id) {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(id));
  return Array.from(new Uint8Array(h)).map(b => b.toString(16).padStart(2,"0")).join("").slice(0,16);
}

async function deriveKey(boxId, pass) {
  const raw = new TextEncoder().encode(boxId + ":" + pass);
  const km = await crypto.subtle.importKey("raw", raw, "PBKDF2", false, ["deriveKey"]);
  return crypto.subtle.deriveKey(
    { name: "PBKDF2", salt: new TextEncoder().encode("vany-safebox-v1"), iterations: 100000, hash: "SHA-256" },
    km, { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]
  );
}

async function enc(text, boxId, pass) {
  const key = await deriveKey(boxId, pass);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(text));
  return { ct: btoa(String.fromCharCode(...new Uint8Array(ct))), iv: btoa(String.fromCharCode(...iv)) };
}

async function dec(ct64, iv64, boxId, pass) {
  const key = await deriveKey(boxId, pass);
  const ct = Uint8Array.from(atob(ct64), c => c.charCodeAt(0));
  const iv = Uint8Array.from(atob(iv64), c => c.charCodeAt(0));
  return new TextDecoder().decode(await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, ct));
}

const elId = document.getElementById("box-id");
const elPass = document.getElementById("box-pass");
const elMsg = document.getElementById("box-msg");
const elBtn = document.getElementById("action-btn");
const elStatus = document.getElementById("status-area");
const elCli = document.getElementById("cli-area");

function updateBtn() {
  const id = elId.value.trim();
  const pass = elPass.value;
  const msg = elMsg.value.trim();
  elStatus.classList.add("hidden");
  if (!id) {
    elBtn.textContent = "Generate";
    elBtn.disabled = false;
    elBtn.className = "action-btn generate";
  } else if (id.length === 8 && pass && msg) {
    elBtn.textContent = "Save";
    elBtn.disabled = false;
    elBtn.className = "action-btn";
  } else if (id.length === 8 && pass && !msg) {
    elBtn.textContent = "Open";
    elBtn.disabled = false;
    elBtn.className = "action-btn open";
  } else {
    elBtn.textContent = id ? (pass ? "Open" : "...") : "Generate";
    elBtn.disabled = !!id && !pass;
    elBtn.className = "action-btn generate";
  }
}

elId.addEventListener("input", updateBtn);
elPass.addEventListener("input", updateBtn);
elMsg.addEventListener("input", function() {
  document.getElementById("charcount").textContent = this.value.length + " / 50,000";
  updateBtn();
});

async function doAction() {
  const action = elBtn.textContent;
  if (action === "Generate") return doGenerate();
  if (action === "Save") return doSave();
  if (action === "Open") return doOpen();
}

function doGenerate() {
  elId.value = genId();
  elId.readOnly = true;
  elPass.focus();
  updateBtn();
}

async function doSave() {
  const boxId = elId.value.trim().toUpperCase();
  const pass = elPass.value;
  const msg = elMsg.value.trim();
  if (!/^[A-Z0-9]{8}$/.test(boxId) || !pass || !msg) return;
  elBtn.disabled = true; elBtn.textContent = "Encrypting...";
  try {
    const { ct, iv } = await enc(msg, boxId, pass);
    const bh = await boxHash(boxId);
    const resp = await fetch("/box", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ box_hash: bh, ciphertext: ct, iv })
    });
    const data = await resp.json();
    if (!resp.ok) throw new Error(data.error || "Failed");
    showStatus("ok", "Saved! Box ID: " + boxId + " — expires in 24h.");
    document.getElementById("cli-cmd").textContent = 'curl -s "https://vany.sh/box/' + boxId + '?pass=YOUR_PASSWORD"';
    elCli.classList.remove("hidden");
    elMsg.readOnly = true;
  } catch (e) { showStatus("err", e.message); }
  finally { updateBtn(); }
}

async function doOpen() {
  const boxId = elId.value.trim().toUpperCase();
  const pass = elPass.value;
  if (!/^[A-Z0-9]{8}$/.test(boxId) || !pass) return;
  elBtn.disabled = true; elBtn.textContent = "Decrypting...";
  try {
    const resp = await fetch("/box/" + encodeURIComponent(boxId));
    const data = await resp.json();
    if (!resp.ok) throw new Error(data.error || "Box not found");
    const text = await dec(data.ciphertext, data.iv, boxId, pass);
    elMsg.value = text;
    elMsg.readOnly = true;
    showStatus("ok", "Decrypted! Expires: " + new Date(data.expires_at).toLocaleString());
  } catch (e) {
    if (e.name === "OperationError") showStatus("err", "Wrong password.");
    else showStatus("err", e.message);
  }
  finally { updateBtn(); }
}

function showStatus(type, msg) {
  elStatus.className = "status " + type;
  elStatus.textContent = msg;
  elStatus.classList.remove("hidden");
}

function copyCli() {
  navigator.clipboard.writeText(document.getElementById("cli-cmd").textContent);
  document.getElementById("cli-cmd").style.borderColor = "var(--green)";
  setTimeout(() => document.getElementById("cli-cmd").style.borderColor = "", 1500);
}

const sp = new URLSearchParams(location.search);
if (sp.has("id")) {
  elId.value = sp.get("id").toUpperCase();
  if (sp.has("pass")) {
    elPass.value = sp.get("pass");
    setTimeout(doOpen, 100);
  }
  updateBtn();
}
</script>
</body>
</html>`;
