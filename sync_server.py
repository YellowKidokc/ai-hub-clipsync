"""
POF 2828 — Clipboard Sync Server (Desktop Tier)
Port 3456 — Lightweight Python backend for clipboard3.html PWA
Features: Clips CRUD, bookmarks, tags, window pin/position
"""
import configparser, ctypes, json, os, re, shutil, sqlite3, threading, uuid, subprocess
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, unquote
from urllib.request import Request, urlopen
from datetime import datetime
from pathlib import Path
import xml.etree.ElementTree as ET
import time

PORT = 3456
BASE = Path(__file__).parent
MODULES_DIR = BASE / "modules"
DB_PATH = BASE / "Data" / "clipboard.db"
DB_PATH.parent.mkdir(parents=True, exist_ok=True)
CONFIG_DIR = BASE / "config"
PROMPTS_PATH = CONFIG_DIR / "prompts.json"
APP_PAGES = {
    "/": ("theophysics-hub.html", "hub"),
    "/prompts": ("prompt_picker.html", "prompts"),
    "/links": ("research_links.html", "links"),
    "/comms": ("comms-dashboard.html", "comms"),
    "/calendar": ("task-calendar.html", "calendar"),
    "/hub": ("theophysics-hub.html", "hub"),
}
EXTERNAL_APP_PAGES = {
    "/clipboard": (Path(r"D:\nerve-package-deploy\html\clipboard.html"), "clipboard"),
    "/mission": (Path(r"\\dlowenas\HPWorkstation\Desktop\mission_control.html"), "mission"),
}
APP_MANIFESTS = {
    "clipboard": ("POF Clipboard", "/clipboard", "#e8a912"),
    "prompts": ("POF Prompts", "/prompts", "#8070c8"),
    "links": ("POF Links", "/links", "#4ac4d4"),
    "comms": ("Theophysics Comms", "/comms", "#4f8ef7"),
    "calendar": ("POF Calendar", "/calendar", "#2ecc8e"),
    "mission": ("Mission Control", "/mission", "#f2c94c"),
    "hub": ("AI-HUB", "/hub", "#e8a912"),
}

# ── File Vault folders ────────────────────────
HOME = Path.home()
FILE_FOLDERS = {
    "documents": HOME / "Documents",
    "videos": HOME / "Videos",
    "music": HOME / "Music",
    "pictures": HOME / "Pictures",
    "nlp": HOME / "Documents" / "AI-HUB-NLP",
    "articles_md": Path(r"D:\GTQ-BUILD\articles\MD"),
}
SYNC_FOLDER_LABELS = {
    "documents": "Documents",
    "videos": "Videos",
    "music": "Music",
    "pictures": "Pictures",
    "nlp": "NLP",
    "articles_md": "Articles MD",
}
SYNC_MANIFEST_PATH = CONFIG_DIR / "sync_manifest.json"

# ── Database ──────────────────────────────────
def get_db():
    conn = sqlite3.connect(str(DB_PATH), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn

def init_db():
    db = get_db()
    db.executescript("""
    CREATE TABLE IF NOT EXISTS clips (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL DEFAULT '',
        title TEXT DEFAULT '',
        category TEXT DEFAULT 'clipboard',
        pinned INTEGER DEFAULT 0,
        starred INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        slot INTEGER,
        tags TEXT DEFAULT '[]',
        fields TEXT DEFAULT '[]',
        categories TEXT DEFAULT '[]',
        ts TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS bookmarks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        description TEXT DEFAULT '',
        category TEXT DEFAULT 'other',
        created_at TEXT DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        color TEXT DEFAULT '#888'
    );
    """)
    db.commit()
    return db

DB = init_db()
LOCK = threading.Lock()

# Window state (in-memory, persisted to JSON)
WIN_STATE_FILE = BASE / "Data" / "window_state.json"
def load_win_state():
    try: return json.loads(WIN_STATE_FILE.read_text())
    except: return {}
def save_win_state(s):
    WIN_STATE_FILE.write_text(json.dumps(s, indent=2))
WIN_STATE = load_win_state()
TTS_COMMAND = None
FILED_CLIPS_DIR = BASE / "Data" / "filed_clips"
BACKUP_INI = CONFIG_DIR / "clipboard_backup.ini"
BACKUP_STATE = BASE / "Data" / "clipboard_backup_state.json"

def ensure_backup_ini():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if BACKUP_INI.exists():
        return
    cfg = configparser.ConfigParser()
    cfg["backup"] = {
        "enabled": "yes",
        "folder": str(BASE / "Data" / "backups"),
        "keep_days": "60",
    }
    with BACKUP_INI.open("w", encoding="utf-8") as f:
        cfg.write(f)

def read_backup_config():
    ensure_backup_ini()
    cfg = configparser.ConfigParser()
    cfg.read(BACKUP_INI, encoding="utf-8")
    section = cfg["backup"] if cfg.has_section("backup") else {}
    enabled = str(section.get("enabled", "yes")).lower() in ("1", "yes", "true", "on")
    folder = Path(section.get("folder", str(BASE / "Data" / "backups")))
    keep_days = int(section.get("keep_days", "60"))
    return enabled, folder, keep_days

def backup_clipboard_db(reason="daily"):
    enabled, folder, keep_days = read_backup_config()
    if not enabled or not DB_PATH.exists():
        return None
    folder.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    db_copy = folder / f"clipboard_{stamp}_{reason}.db"
    json_copy = folder / f"clipboard_{stamp}_{reason}.json"
    with LOCK:
        DB.commit()
        shutil.copy2(DB_PATH, db_copy)
        rows = DB.execute("SELECT * FROM clips ORDER BY created_at DESC").fetchall()
    json_copy.write_text(json.dumps([row_to_dict(r) for r in rows], indent=2), encoding="utf-8")
    cutoff = time.time() - (keep_days * 86400)
    for old in folder.glob("clipboard_*.*"):
        try:
            if old.stat().st_mtime < cutoff:
                old.unlink()
        except Exception:
            pass
    BACKUP_STATE.write_text(json.dumps({
        "last_backup_date": datetime.now().strftime("%Y-%m-%d"),
        "last_backup_at": datetime.now().isoformat(),
        "last_backup_db": str(db_copy),
        "last_backup_json": str(json_copy),
        "reason": reason,
    }, indent=2), encoding="utf-8")
    return {"db": str(db_copy), "json": str(json_copy)}

def backup_daily_loop():
    time.sleep(5)
    while True:
        try:
            today = datetime.now().strftime("%Y-%m-%d")
            state = {}
            if BACKUP_STATE.exists():
                state = json.loads(BACKUP_STATE.read_text(encoding="utf-8"))
            if state.get("last_backup_date") != today:
                backup_clipboard_db("daily")
        except Exception as e:
            print(f"Clipboard backup skipped: {e}")
        time.sleep(3600)

# ── Helpers ───────────────────────────────────
def row_to_dict(row):
    if row is None: return None
    d = dict(row)
    for k in ('tags', 'fields', 'categories'):
        if k in d and isinstance(d[k], str):
            try: d[k] = json.loads(d[k])
            except: d[k] = []
    for k in ('pinned', 'starred', 'deleted'):
        if k in d: d[k] = bool(d[k])
    return d

def new_id():
    return f"c_{int(datetime.now().timestamp()*1000)}_{uuid.uuid4().hex[:6]}"

def save_clip_record(body):
    content = body.get("content", "")
    if not content:
        return None
    cid = body.get("id") or new_id()
    now = datetime.utcnow().isoformat() + "Z"
    slot = body.get("slot")
    category = body.get("category", "clipboard")
    tags = body.get("tags", [])
    if slot is None and category == "clipboard":
        existing = DB.execute(
            "SELECT id FROM clips WHERE content=? AND deleted=0 ORDER BY created_at DESC LIMIT 1",
            (content,)
        ).fetchone()
        if existing:
            return existing["id"]
    title = body.get("title", "")
    if not title:
        title = next((line.strip() for line in content.splitlines() if line.strip()), "Clipboard")[:80]
    with LOCK:
        DB.execute("""INSERT OR REPLACE INTO clips
            (id,content,title,category,pinned,starred,deleted,slot,tags,fields,categories,ts,created_at,updated_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (cid, content, title, category,
             int(body.get("pinned", False)), int(body.get("starred", False)),
             int(body.get("deleted", False)), slot,
             json.dumps(tags), json.dumps(body.get("fields", [])),
             json.dumps(body.get("categories", [])),
             body.get("ts", now), now, now))
        DB.commit()
    return cid

def read_windows_clipboard_text():
    if os.name != "nt":
        return None
    CF_UNICODETEXT = 13
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    user32.OpenClipboard.argtypes = [ctypes.c_void_p]
    user32.OpenClipboard.restype = ctypes.c_bool
    user32.GetClipboardData.argtypes = [ctypes.c_uint]
    user32.GetClipboardData.restype = ctypes.c_void_p
    kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
    kernel32.GlobalLock.restype = ctypes.c_void_p
    kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
    kernel32.GlobalUnlock.restype = ctypes.c_bool
    if not user32.OpenClipboard(None):
        return None
    try:
        handle = user32.GetClipboardData(CF_UNICODETEXT)
        if not handle:
            return None
        ptr = kernel32.GlobalLock(handle)
        if not ptr:
            return None
        try:
            return ctypes.wstring_at(ptr)
        finally:
            kernel32.GlobalUnlock(handle)
    finally:
        user32.CloseClipboard()

LAST_SYSTEM_CLIP = ""
def clipboard_watch_loop():
    global LAST_SYSTEM_CLIP
    time.sleep(1.5)
    while True:
        try:
            text = read_windows_clipboard_text()
            if text:
                text = text.strip("\x00")
                if text and text != LAST_SYSTEM_CLIP and len(text) <= 250000:
                    LAST_SYSTEM_CLIP = text
                    save_clip_record({
                        "content": text,
                        "category": "clipboard",
                        "tags": ["history", "system"],
                        "ts": datetime.utcnow().isoformat() + "Z",
                    })
        except Exception:
            pass
        time.sleep(0.5)

def slugify(text):
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text.lower()).strip("-")
    return text[:60] or "clipboard-item"

def classify_clip_text(content):
    text = content or ""
    low = text.lower()
    secret_patterns = [
        r"api[_-]?key\s*[:=]",
        r"api[_-]?token\s*[:=]",
        r"secret\s*[:=]",
        r"bearer\s+[a-z0-9_\-\.]{20,}",
        r"-----begin [a-z ]*private key-----",
        r"sk-[a-z0-9_\-]{20,}",
        r"[a-f0-9]{32,}",
    ]
    is_secret = any(re.search(p, low, re.I) for p in secret_patterns)
    tags = []
    category = "notes"
    title = "Clipboard Note"
    action = "file_to_notes"

    if "cloudflare" in low or "cf_api" in low or "cf-" in low:
        title = "Cloudflare API Keys"
        category = "secrets"
        action = "confirm_file_to_secrets"
        tags.extend(["cloudflare", "api-key"])
        is_secret = True
    elif is_secret:
        title = "API Keys or Secret"
        category = "secrets"
        action = "confirm_file_to_secrets"
        tags.extend(["secret", "api-key"])
    elif re.search(r"https?://", text):
        title = "Web Link"
        category = "links"
        action = "file_to_links"
        tags.append("link")
    elif re.search(r"\b(function|const|let|class|import|def|SELECT|CREATE TABLE)\b", text):
        title = "Code Snippet"
        category = "code"
        action = "file_to_code"
        tags.append("code")
    elif re.search(r"[\w\.-]+@[\w\.-]+\.\w+", text):
        title = "Email or Contact"
        category = "contacts"
        action = "file_to_contacts"
        tags.append("contact")

    if is_secret and "secret" not in tags:
        tags.insert(0, "secret")

    return {
        "title": title,
        "category": category,
        "tags": tags[:5],
        "action": action,
        "sensitive": bool(is_secret),
        "needs_confirmation": bool(is_secret),
        "confidence": "high" if is_secret or tags else "medium",
        "note": "Sensitive-looking text was classified locally and was not sent to an outside AI."
                if is_secret else "Classified locally by AI-HUB rules."
    }

def file_clip_text(content, classification, confirmed=False):
    classification = classification or classify_clip_text(content)
    if classification.get("sensitive") and not confirmed:
        return {"ok": False, "needs_confirmation": True, "classification": classification}

    category = classification.get("category") or "notes"
    title = classification.get("title") or "Clipboard Item"
    folder = FILED_CLIPS_DIR / category
    folder.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = folder / f"{stamp}-{slugify(title)}.txt"
    path.write_text(content or "", encoding="utf-8")

    cid = new_id()
    now = datetime.utcnow().isoformat() + "Z"
    with LOCK:
        DB.execute("""INSERT OR REPLACE INTO clips
            (id,content,title,category,pinned,starred,deleted,slot,tags,fields,categories,ts,created_at,updated_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (cid, content or "", title, category, 1 if classification.get("sensitive") else 0, 0, 0, None,
             json.dumps(classification.get("tags", [])), json.dumps([{"file": str(path)}]),
             json.dumps([category]), now, now, now))
        DB.commit()

    return {"ok": True, "id": cid, "file": str(path), "classification": classification}

def load_prompts():
    try:
        data = json.loads(PROMPTS_PATH.read_text(encoding="utf-8-sig"))
        return data if isinstance(data, list) else []
    except Exception:
        return []

def save_prompts(items):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    PROMPTS_PATH.write_text(json.dumps(items, indent=2, ensure_ascii=False), encoding="utf-8")

def _folder_stats(path):
    stats = {"exists": path.exists(), "files": 0, "bytes": 0, "modified": None, "limited": False}
    if not path.exists():
        return stats
    newest = 0
    deadline = time.monotonic() + 0.75
    pending = [path]
    try:
        while pending and stats["files"] < 2500 and time.monotonic() < deadline:
            current = pending.pop()
            try:
                for entry in current.iterdir():
                    if entry.name.startswith("."):
                        continue
                    if entry.is_dir():
                        pending.append(entry)
                        continue
                    if not entry.is_file():
                        continue
                    try:
                        st = entry.stat()
                    except OSError:
                        continue
                    stats["files"] += 1
                    stats["bytes"] += st.st_size
                    newest = max(newest, st.st_mtime)
                    if stats["files"] >= 2500 or time.monotonic() >= deadline:
                        break
            except OSError:
                continue
    except OSError:
        pass
    stats["limited"] = bool(pending or stats["files"] >= 2500)
    if newest:
        stats["modified"] = datetime.fromtimestamp(newest).isoformat()
    return stats

def load_sync_manifest():
    default = {
        "name": "AI-HUB File Sync",
        "engine": "Syncthing",
        "folders": [
            {
                "id": key,
                "label": SYNC_FOLDER_LABELS[key],
                "path": str(path),
                "syncthing_folder_id": f"aihub-{key}",
                "mode": "sendreceive",
            }
            for key, path in FILE_FOLDERS.items()
        ],
        "notes": "Use these same Syncthing folder ids on each computer so AI-HUB can display shared status.",
    }
    if not SYNC_MANIFEST_PATH.exists():
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        SYNC_MANIFEST_PATH.write_text(json.dumps(default, indent=2), encoding="utf-8")
        return default
    try:
        saved = json.loads(SYNC_MANIFEST_PATH.read_text(encoding="utf-8-sig"))
        if isinstance(saved, dict) and saved.get("folders"):
            return saved
    except Exception:
        pass
    return default

def find_syncthing_config():
    candidates = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "Syncthing" / "config.xml",
        Path(os.environ.get("APPDATA", "")) / "Syncthing" / "config.xml",
        Path(os.environ.get("LOCALAPPDATA", "")) / "SyncTrayzor" / "syncthing" / "config.xml",
    ]
    for path in candidates:
        if path.exists():
            return path
    return None

def read_syncthing_api_key():
    config = find_syncthing_config()
    if not config:
        return None
    try:
        root = ET.fromstring(config.read_text(encoding="utf-8", errors="ignore"))
        gui = root.find("gui")
        if gui is not None:
            key = gui.findtext("apikey")
            if key:
                return key.strip()
    except Exception:
        return None
    return None

def syncthing_get(path):
    key = read_syncthing_api_key()
    if not key:
        return None
    try:
        req = Request(f"http://127.0.0.1:8384/rest{path}", headers={"X-API-Key": key})
        with urlopen(req, timeout=1.5) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None

def sync_status():
    manifest = load_sync_manifest()
    system = syncthing_get("/system/status")
    folders_api = syncthing_get("/config/folders") or []
    folder_errors = syncthing_get("/folder/errors") or []
    api_by_id = {item.get("id"): item for item in folders_api if isinstance(item, dict)}
    errors_by_id = {item.get("folder"): item for item in folder_errors if isinstance(item, dict)}
    folders = []
    for item in manifest.get("folders", []):
        key = item.get("id")
        local_path = Path(item.get("path") or FILE_FOLDERS.get(key, ""))
        syncthing_id = item.get("syncthing_folder_id") or f"aihub-{key}"
        configured = syncthing_id in api_by_id
        folders.append({
            **item,
            "path": str(local_path),
            "stats": _folder_stats(local_path),
            "syncthing": {
                "folder_id": syncthing_id,
                "configured": configured,
                "path_match": configured and str(api_by_id[syncthing_id].get("path", "")).lower() == str(local_path).lower(),
                "errors": errors_by_id.get(syncthing_id, {}).get("errors", []),
            },
        })
    return {
        "manifest": manifest,
        "syncthing": {
            "detected": find_syncthing_config() is not None,
            "api_online": system is not None,
            "device_id": system.get("myID") if isinstance(system, dict) else None,
        },
        "folders": folders,
        "updated_at": datetime.utcnow().isoformat() + "Z",
    }

def normalize_prompt(body):
    item = dict(body)
    name = item.get("name") or item.get("title") or ""
    content = item.get("template") or item.get("content") or ""
    item["name"] = name
    item["template"] = content
    item["content"] = content
    item.setdefault("category", "General")
    item.setdefault("tags", [])
    meta = item.get("meta") if isinstance(item.get("meta"), dict) else {}
    if not item.get("shortcut") and (meta.get("slash") or str(name).startswith("/")):
        item["shortcut"] = str(name).lstrip("/").strip()
    item.setdefault("shortcut", "")
    item.setdefault("replace", True)
    item.setdefault("popup", False)
    return item

# ── HTTP Handler ──────────────────────────────
class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): pass  # quiet

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self._cors()
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def _no_content(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length == 0: return {}
        return json.loads(self.rfile.read(length))

    def _text(self, status, content, content_type="text/plain; charset=utf-8"):
        data = content.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self._cors()
        self.end_headers()
        self.wfile.write(data)

    def _serve_html_file(self, path, app_key):
        if not path.exists():
            self._json(404, {"error": "app page not found"})
            return
        html = path.read_text(encoding="utf-8", errors="replace")
        sync_widget = r'''<script>
(function(){
  if(window.__aiHubSyncWidget) return;
  window.__aiHubSyncWidget = true;
  function fmt(bytes){ if(!bytes) return "0 B"; var units=["B","KB","MB","GB","TB"], i=0; while(bytes>=1024&&i<units.length-1){bytes/=1024;i++;} return bytes.toFixed(i?1:0)+" "+units[i]; }
  function css(){
    var s=document.createElement("style");
    s.textContent="#aihub-sync-btn{position:fixed;right:10px;bottom:10px;z-index:2147483646;border:1px solid rgba(232,169,18,.35);background:#101014;color:#e8a912;border-radius:7px;padding:7px 9px;font:11px Segoe UI,Arial,sans-serif;letter-spacing:.4px;box-shadow:0 8px 26px rgba(0,0,0,.35);cursor:pointer}#aihub-sync-panel{position:fixed;right:10px;bottom:48px;width:300px;max-height:430px;overflow:auto;z-index:2147483646;background:#101014;color:#ddd;border:1px solid rgba(232,169,18,.28);box-shadow:0 14px 45px rgba(0,0,0,.55);border-radius:8px;font:11px Segoe UI,Arial,sans-serif;display:none}#aihub-sync-panel.open{display:block}.ash{padding:10px 12px;border-bottom:1px solid rgba(255,255,255,.08);display:flex;justify-content:space-between;gap:8px}.ast{color:#e8a912;font-weight:600}.ass{color:#8b8d98}.asb{padding:8px 10px;border-bottom:1px solid rgba(255,255,255,.06)}.asr{display:flex;justify-content:space-between;gap:8px;margin-bottom:4px}.asnm{font-weight:600;color:#fff}.asok{color:#2ecc8e}.aswarn{color:#f2c94c}.asbad{color:#ff6b6b}.asp{color:#888;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.asm{color:#aaa;font-size:10px}";
    document.head.appendChild(s);
  }
  function row(f){
    var st=f.stats||{}, syn=f.syncthing||{}, cls=syn.configured?"asok":"aswarn", label=syn.configured?"Syncthing":"Manifest";
    return '<div class="asb"><div class="asr"><span class="asnm">'+f.label+'</span><span class="'+cls+'">'+label+'</span></div><div class="asp" title="'+f.path+'">'+f.path+'</div><div class="asm">'+(st.files||0)+' files · '+fmt(st.bytes||0)+' · '+syn.folder_id+'</div></div>';
  }
  async function load(){
    try{
      var r=await fetch("/api/sync/status"), d=await r.json();
      var syn=d.syncthing||{};
      document.getElementById("aihub-sync-panel").innerHTML='<div class="ash"><div><div class="ast">AI-HUB File Sync</div><div class="ass">'+(syn.api_online?"Syncthing online":syn.detected?"Syncthing detected, API offline":"Ready for Syncthing")+'</div></div><div class="'+(syn.api_online?"asok":"aswarn")+'">SYNC</div></div>'+d.folders.map(row).join("");
    }catch(e){document.getElementById("aihub-sync-panel").innerHTML='<div class="ash"><div class="ast">AI-HUB File Sync</div><div class="asbad">Status unavailable</div></div>';}
  }
  window.addEventListener("DOMContentLoaded",function(){
    css();
    var b=document.createElement("button"); b.id="aihub-sync-btn"; b.textContent="Sync";
    var p=document.createElement("div"); p.id="aihub-sync-panel";
    b.onclick=function(){ p.classList.toggle("open"); if(p.classList.contains("open")) load(); };
    document.body.appendChild(b); document.body.appendChild(p);
  });
})();
</script>
'''
        install_head = (
            f'<link rel="manifest" href="/manifest/{app_key}.json">\n'
            '<meta name="theme-color" content="#101014">\n'
            '<script>if("serviceWorker" in navigator){navigator.serviceWorker.register("/sw.js").catch(()=>{})}</script>\n'
        )
        if "</head>" in html:
            html = html.replace("</head>", install_head + "</head>", 1)
        if "</body>" in html:
            html = html.replace("</body>", sync_widget + "</body>", 1)
        self._text(200, html, "text/html; charset=utf-8")

    def _serve_app_page(self, filename, app_key):
        self._serve_html_file(MODULES_DIR / filename, app_key)

    def _serve_manifest(self, app_key):
        name, start_url, theme = APP_MANIFESTS.get(app_key, APP_MANIFESTS["hub"])
        manifest = {
            "name": name,
            "short_name": name.replace("POF ", ""),
            "start_url": start_url,
            "scope": "/",
            "display": "standalone",
            "background_color": "#101014",
            "theme_color": theme,
            "icons": [
                {"src": f"/icons/{app_key}.svg", "sizes": "192x192", "type": "image/svg+xml"},
                {"src": f"/icons/{app_key}.svg", "sizes": "512x512", "type": "image/svg+xml"}
            ]
        }
        self._json(200, manifest)

    def _serve_icon(self, app_key):
        label, _, color = APP_MANIFESTS.get(app_key, APP_MANIFESTS["hub"])
        initials = "".join([part[0] for part in label.replace("POF ", "").split()])[:2].upper()
        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
<rect width="512" height="512" rx="96" fill="#101014"/>
<rect x="44" y="44" width="424" height="424" rx="72" fill="{color}" opacity=".18" stroke="{color}" stroke-width="18"/>
<text x="256" y="304" text-anchor="middle" font-family="Segoe UI, Arial, sans-serif" font-size="148" font-weight="700" fill="{color}">{initials}</text>
</svg>'''
        self._text(200, svg, "image/svg+xml")

    def _serve_service_worker(self):
        sw = """self.addEventListener('install', event => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('fetch', event => event.respondWith(fetch(event.request).catch(() => new Response('', {status: 503}))));"""
        self._text(200, sw, "text/javascript; charset=utf-8")

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors()
        self.end_headers()

    def do_GET(self):
        global TTS_COMMAND
        p = unquote(self.path.split("?")[0])

        if p in APP_PAGES:
            filename, app_key = APP_PAGES[p]
            self._serve_app_page(filename, app_key)
            return

        if p in EXTERNAL_APP_PAGES:
            html_path, app_key = EXTERNAL_APP_PAGES[p]
            self._serve_html_file(html_path, app_key)
            return

        if p.startswith("/modules/"):
            module_file = (MODULES_DIR / p.removeprefix("/modules/")).resolve()
            if MODULES_DIR.resolve() not in module_file.parents or not module_file.exists():
                self._json(404, {"error": "not found"})
                return
            content_type = "text/html; charset=utf-8" if module_file.suffix.lower() == ".html" else "application/octet-stream"
            self._text(200, module_file.read_text(encoding="utf-8", errors="replace"), content_type)
            return

        if p.startswith("/manifest/") and p.endswith(".json"):
            self._serve_manifest(p.removeprefix("/manifest/").removesuffix(".json"))
            return

        if p.startswith("/icons/") and p.endswith(".svg"):
            self._serve_icon(p.removeprefix("/icons/").removesuffix(".svg"))
            return

        if p == "/sw.js":
            self._serve_service_worker()
            return

        # GET /api/clips
        if p == "/api/clips":
            with LOCK:
                rows = DB.execute("SELECT * FROM clips ORDER BY created_at DESC LIMIT 500").fetchall()
            self._json(200, [row_to_dict(r) for r in rows])

        # GET /api/clips/:id
        elif p.startswith("/api/clips/"):
            cid = p.split("/")[-1]
            with LOCK:
                row = DB.execute("SELECT * FROM clips WHERE id=?", (cid,)).fetchone()
            if row: self._json(200, row_to_dict(row))
            else: self._json(404, {"error": "not found"})

        # GET /api/bookmarks
        elif p == "/api/bookmarks":
            with LOCK:
                rows = DB.execute("SELECT * FROM bookmarks ORDER BY created_at DESC").fetchall()
            self._json(200, [dict(r) for r in rows])

        # GET /api/tags
        elif p == "/api/tags":
            with LOCK:
                rows = DB.execute("SELECT * FROM tags").fetchall()
            self._json(200, [dict(r) for r in rows])

        # GET /api/prompts
        elif p == "/api/prompts":
            self._json(200, load_prompts())

        # GET /api/window-state
        elif p == "/api/window-state":
            self._json(200, WIN_STATE)

        # GET /api/backup/status
        elif p == "/api/backup/status":
            enabled, folder, keep_days = read_backup_config()
            state = {}
            if BACKUP_STATE.exists():
                try:
                    state = json.loads(BACKUP_STATE.read_text(encoding="utf-8"))
                except Exception:
                    state = {}
            self._json(200, {"enabled": enabled, "folder": str(folder), "keep_days": keep_days, **state})

        # GET /api/tts-command
        elif p == "/api/tts-command":
            cmd = TTS_COMMAND
            TTS_COMMAND = None
            self._json(200, cmd or {})

        # GET /api/sync/manifest
        elif p == "/api/sync/manifest":
            self._json(200, load_sync_manifest())

        # GET /api/sync/status
        elif p == "/api/sync/status":
            self._json(200, sync_status())

        # GET /api/files/:folder
        elif p.startswith("/api/files/"):
            folder_key = p.split("/")[-1]
            folder_path = FILE_FOLDERS.get(folder_key)
            if not folder_path or not folder_path.exists():
                self._json(404, {"error": f"folder '{folder_key}' not found"})
                return
            try:
                files = []
                for entry in sorted(folder_path.iterdir(), key=lambda e: e.stat().st_mtime, reverse=True):
                    if entry.is_file() and not entry.name.startswith('.'):
                        st = entry.stat()
                        files.append({
                            "name": entry.name,
                            "path": str(entry),
                            "size": st.st_size,
                            "modified": datetime.fromtimestamp(st.st_mtime).isoformat(),
                        })
                    if len(files) >= 100:
                        break
                self._json(200, files)
            except Exception as e:
                self._json(500, {"error": str(e)})

        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        global TTS_COMMAND
        p = self.path.split("?")[0]
        body = self._read_body()

        # POST /api/clips
        if p == "/api/clips":
            cid = save_clip_record(body)
            self._json(201, {"id": cid})

        # POST /api/bookmarks
        elif p == "/api/bookmarks":
            bid = body.get("id") or new_id()
            now = datetime.utcnow().isoformat() + "Z"
            with LOCK:
                DB.execute("INSERT OR REPLACE INTO bookmarks (id,title,url,description,category,created_at) VALUES (?,?,?,?,?,?)",
                    (bid, body.get("title",""), body.get("url",""),
                     body.get("description",""), body.get("category","other"), now))
                DB.commit()
            self._json(201, {"id": bid})

        # POST /api/tags
        elif p == "/api/tags":
            tid = body.get("id") or new_id()
            with LOCK:
                DB.execute("INSERT OR IGNORE INTO tags (id,name,color) VALUES (?,?,?)",
                    (tid, body.get("name",""), body.get("color","#888")))
                DB.commit()
            self._json(201, {"id": tid})

        # POST /api/prompts
        elif p == "/api/prompts":
            prompts = load_prompts()
            pid = body.get("id") or f"prompt_{int(datetime.now().timestamp()*1000)}_{uuid.uuid4().hex[:6]}"
            item = normalize_prompt(body)
            item["id"] = pid
            item.setdefault("created_at", datetime.utcnow().isoformat() + "Z")
            item["updated_at"] = datetime.utcnow().isoformat() + "Z"
            prompts.append(item)
            save_prompts(prompts)
            self._json(201, {"id": pid})

        # POST /api/ai/classify-clip
        elif p == "/api/ai/classify-clip":
            content = body.get("content", "")
            if not content:
                self._json(400, {"error": "content required"})
                return
            self._json(200, classify_clip_text(content))

        # POST /api/ai/file-clip
        elif p == "/api/ai/file-clip":
            content = body.get("content", "")
            if not content:
                self._json(400, {"error": "content required"})
                return
            classification = body.get("classification") or classify_clip_text(content)
            confirmed = bool(body.get("confirmed", False))
            result = file_clip_text(content, classification, confirmed)
            self._json(200 if result.get("ok") else 409, result)

        # POST /api/files/open
        elif p == "/api/files/open":
            file_path = body.get("path", "")
            if not file_path or not Path(file_path).exists():
                self._json(404, {"error": "file not found"})
                return
            # Security: only allow opening files within known folders
            resolved = Path(file_path).resolve()
            allowed = any(str(resolved).startswith(str(fp.resolve())) for fp in FILE_FOLDERS.values())
            if not allowed:
                self._json(403, {"error": "path not in allowed folders"})
                return
            try:
                os.startfile(str(resolved))  # Windows-specific
                self._json(200, {"ok": True, "opened": str(resolved)})
            except Exception as e:
                self._json(500, {"error": str(e)})

        # POST /window/pin
        elif p == "/window/pin":
            WIN_STATE["pin"] = body
            save_win_state(WIN_STATE)
            self._json(200, {"ok": True})

        # POST /api/pin/start
        elif p == "/api/pin/start":
            pin_num = str(body.get("pin", "1"))
            helper = MODULES_DIR / "window_pin_overlay.ahk"
            ahk = Path(r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe")
            if not helper.exists():
                self._json(404, {"error": "pin helper not found"})
                return
            if not ahk.exists():
                self._json(404, {"error": "AutoHotkey v2 not found"})
                return
            try:
                subprocess.Popen([str(ahk), str(helper), pin_num], close_fds=True)
                self._json(200, {"ok": True, "pin": pin_num})
            except Exception as e:
                self._json(500, {"error": str(e)})

        # POST /api/backup/run
        elif p == "/api/backup/run":
            try:
                result = backup_clipboard_db("manual")
                self._json(200, {"ok": True, **(result or {})})
            except Exception as e:
                self._json(500, {"error": str(e)})

        # POST /window/position
        elif p == "/window/position":
            WIN_STATE["position"] = body
            save_win_state(WIN_STATE)
            self._json(200, {"ok": True})

        # POST /api/tts-command
        elif p == "/api/tts-command":
            body["id"] = body.get("id") or f"tts_{int(datetime.now().timestamp()*1000)}"
            body["created_at"] = datetime.utcnow().isoformat() + "Z"
            TTS_COMMAND = body
            self._json(200, {"ok": True, "id": body["id"]})

        else:
            self._json(404, {"error": "not found"})

    def do_PUT(self):
        p = self.path.split("?")[0]
        body = self._read_body()

        # PUT /api/clips/:id
        if p.startswith("/api/clips/"):
            cid = p.split("/")[-1]
            now = datetime.utcnow().isoformat() + "Z"
            sets, vals = [], []
            for k in ("content","title","category"):
                if k in body: sets.append(f"{k}=?"); vals.append(body[k])
            for k in ("pinned","starred","deleted"):
                if k in body: sets.append(f"{k}=?"); vals.append(int(body[k]))
            if "slot" in body: sets.append("slot=?"); vals.append(body["slot"])
            for k in ("tags","fields","categories"):
                if k in body: sets.append(f"{k}=?"); vals.append(json.dumps(body[k]) if isinstance(body[k], list) else body[k])
            sets.append("updated_at=?"); vals.append(now)
            vals.append(cid)
            if sets:
                with LOCK:
                    DB.execute(f"UPDATE clips SET {','.join(sets)} WHERE id=?", vals)
                    DB.commit()
            self._json(200, {"id": cid})
        else:
            self._json(404, {"error": "not found"})

    def do_PATCH(self):
        self.do_PUT()

    def do_DELETE(self):
        p = self.path.split("?")[0]

        if p.startswith("/api/clips/"):
            cid = p.split("/")[-1]
            with LOCK:
                DB.execute("DELETE FROM clips WHERE id=?", (cid,))
                DB.commit()
            self._no_content()

        elif p.startswith("/api/bookmarks/"):
            bid = p.split("/")[-1]
            with LOCK:
                DB.execute("DELETE FROM bookmarks WHERE id=?", (bid,))
                DB.commit()
            self._no_content()

        elif p.startswith("/api/tags/"):
            tid = p.split("/")[-1]
            with LOCK:
                DB.execute("DELETE FROM tags WHERE id=?", (tid,))
                DB.commit()
            self._no_content()

        else:
            self._json(404, {"error": "not found"})

# ── Main ──────────────────────────────────────
if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    threading.Thread(target=clipboard_watch_loop, daemon=True).start()
    threading.Thread(target=backup_daily_loop, daemon=True).start()
    print(f"POF 2828 Sync Server running on port {PORT}")
    print(f"DB: {DB_PATH}")
    print(f"Serving clipboard3.html PWA backend")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutdown.")
        server.server_close()
