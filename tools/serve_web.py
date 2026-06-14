#!/usr/bin/env python3
from __future__ import annotations

import argparse
import functools
import json
import mimetypes
import ssl
import subprocess
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DIR = ROOT / "build" / "web"
LAYOUT_PATH = ROOT / "assets" / "ui" / "hud_layout.json"
HISTORY_PATH = ROOT / "assets" / "ui" / "hud_layout_history.json"
HISTORY_CAP = 100
EXPORT_SCRIPT = ROOT / "tools" / "export_web.sh"
SHELL_PAGE = ROOT / "tools" / "web_chat.html"
CHAT_LOG = ROOT / "build" / "chat_log.jsonl"
CHAT_UPLOADS = ROOT / "build" / "chat_uploads"
CHAT_UPLOAD_MAX = 8 * 1024 * 1024
CHAT_IMAGE_TYPES = {"image/png": ".png", "image/jpeg": ".jpg", "image/webp": ".webp", "image/gif": ".gif"}

_export_lock = threading.Lock()
_history_lock = threading.Lock()
_chat_lock = threading.Lock()


def _chat_messages() -> list[dict]:
    try:
        lines = CHAT_LOG.read_text().splitlines()
    except OSError:
        return []
    out = []
    for i, line in enumerate(lines):
        try:
            msg = json.loads(line)
            if isinstance(msg, dict):
                images = [p for p in msg.get("images", []) if isinstance(p, str)] if isinstance(msg.get("images"), list) else []
                out.append({"id": i, "role": msg.get("role", "?"), "text": msg.get("text", ""), "ts": msg.get("ts", ""), "images": images})
        except json.JSONDecodeError:
            continue
    return out


def _chat_append(role: str, text: str, images: list[str] | None = None) -> None:
    from datetime import datetime

    entry = {"role": role, "text": text, "ts": datetime.now().strftime("%H:%M:%S")}
    if images:
        entry["images"] = images
    with _chat_lock:
        CHAT_LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(CHAT_LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def _load_history() -> dict:
    try:
        data = json.loads(HISTORY_PATH.read_text())
        if isinstance(data, dict) and isinstance(data.get("versions"), list):
            return data
    except (OSError, json.JSONDecodeError):
        pass
    return {"versions": []}


def _append_history(layout: dict, restored_from: int | None = None) -> None:
    """Record one version per operation, Figma-style: bakes append, restores
    append a copy of the restored version (history is never rewritten)."""
    from datetime import datetime

    with _history_lock:
        data = _load_history()
        versions = data["versions"]
        if versions and versions[-1]["layout"] == layout and restored_from is None:
            return  # no-op bake, don't spam history
        entry = {"ts": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "layout": layout}
        if restored_from is not None:
            entry["restored_from"] = restored_from
        versions.append(entry)
        data["versions"] = versions[-HISTORY_CAP:]
        HISTORY_PATH.write_text(json.dumps(data, indent=1) + "\n")


def _export_async() -> bool:
    """Re-export the web build in the background; one export at a time."""
    if not _export_lock.acquire(blocking=False):
        return False

    def run() -> None:
        try:
            log_path = ROOT / "build" / "bake_export.log"
            with open(log_path, "wb") as log:
                subprocess.run(["bash", str(EXPORT_SCRIPT)], stdout=log, stderr=log, check=False)
            print("bake: web re-export finished", flush=True)
        finally:
            _export_lock.release()

    threading.Thread(target=run, daemon=True).start()
    return True


class GodotWebHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self) -> None:
        if self.path in ("/", "/play"):
            # Shell page: game iframe + chat sidebar, decoupled from the Godot
            # export so re-exports never touch it. The bare game stays at
            # /index.html.
            body = SHELL_PAGE.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/api/layout-history":
            self._send_json(_load_history())
        elif self.path.startswith("/api/chat/log"):
            after = -1
            if "after=" in self.path:
                try:
                    after = int(self.path.split("after=")[1].split("&")[0])
                except ValueError:
                    pass
            self._send_json({"messages": [m for m in _chat_messages() if m["id"] > after]})
        elif self.path.startswith("/chat-uploads/"):
            self._serve_upload(self.path[len("/chat-uploads/"):])
        else:
            super().do_GET()

    def do_POST(self) -> None:
        try:
            if self.path == "/api/chat/upload":
                self._chat_upload()
                return
            data = self._read_json_body()
            if self.path == "/api/bake-layout":
                self._bake(data)
            elif self.path == "/api/restore-layout":
                self._restore(data)
            elif self.path == "/api/chat/send":
                text = str(data.get("text", "")).strip()
                images = data.get("images", [])
                if not (isinstance(images, list) and all(isinstance(n, str) for n in images) and len(images) <= 8):
                    raise ValueError("bad images")
                names = [Path(n).name for n in images]
                for name in names:
                    if not (CHAT_UPLOADS / name).is_file():
                        raise ValueError(f"unknown image: {name!r}")
                if not (text or names) or len(text) > 8192:
                    raise ValueError("bad text length")
                _chat_append("user", text, [f"build/chat_uploads/{n}" for n in names])
                self._send_json({"ok": True})
            else:
                self.send_error(404)
        except (ValueError, json.JSONDecodeError) as e:
            self.send_error(400, str(e))

    def log_message(self, fmt: str, *args) -> None:
        if "/api/chat/log" not in str(args[0] if args else ""):  # polling spam
            super().log_message(fmt, *args)

    def _chat_upload(self) -> None:
        from datetime import datetime
        import secrets

        ctype = (self.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        ext = CHAT_IMAGE_TYPES.get(ctype)
        if not ext:
            raise ValueError(f"unsupported image type: {ctype!r}")
        length = int(self.headers.get("Content-Length", "0"))
        if not 0 < length <= CHAT_UPLOAD_MAX:
            raise ValueError("bad image size")
        body = self.rfile.read(length)
        name = f"paste_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{secrets.token_hex(3)}{ext}"
        CHAT_UPLOADS.mkdir(parents=True, exist_ok=True)
        (CHAT_UPLOADS / name).write_bytes(body)
        self._send_json({"ok": True, "name": name, "file": f"build/chat_uploads/{name}"})

    def _serve_upload(self, raw_name: str) -> None:
        from urllib.parse import unquote

        name = unquote(raw_name.split("?")[0])
        path = CHAT_UPLOADS / name
        if name != Path(name).name or not path.is_file():
            self.send_error(404)
            return
        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(name)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json_body(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if not 0 < length <= 65536:
            raise ValueError("bad content length")
        data = json.loads(self.rfile.read(length))
        if not isinstance(data, dict):
            raise ValueError("payload must be an object")
        return data

    def _bake(self, data: dict) -> None:
        for key, off in data.items():
            if not (
                isinstance(key, str)
                and isinstance(off, list)
                and len(off) == 2
                and all(isinstance(v, (int, float)) for v in off)
            ):
                raise ValueError(f"bad entry: {key!r}")
        LAYOUT_PATH.write_text(json.dumps(data, indent=1) + "\n")
        _append_history(data)
        print(f"bake: wrote {LAYOUT_PATH} ({len(data)} offsets), re-exporting web…", flush=True)
        self._send_json({"ok": True, "exporting": _export_async()})

    def _restore(self, data: dict) -> None:
        index = data.get("index")
        versions = _load_history()["versions"]
        if not (isinstance(index, int) and 0 <= index < len(versions)):
            raise ValueError(f"bad version index: {index!r}")
        layout = versions[index]["layout"]
        LAYOUT_PATH.write_text(json.dumps(layout, indent=1) + "\n")
        _append_history(layout, restored_from=index)
        print(f"restore: layout v{index} -> current, re-exporting web…", flush=True)
        self._send_json({"ok": True, "layout": layout, "exporting": _export_async()})

    def _send_json(self, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Serve the Godot Web export for remote testing.")
    parser.add_argument("--dir", default=str(DEFAULT_DIR), help="Directory containing index.html.")
    parser.add_argument("--host", default="127.0.0.1", help="Bind host. Keep 127.0.0.1 for SSH tunnels.")
    parser.add_argument("--port", default=58244, type=int, help="Bind port.")
    # Godot 4 web exports refuse to boot outside a secure context, so LAN
    # testing (non-localhost) needs HTTPS with a self-signed cert.
    parser.add_argument("--cert", default="", help="TLS certificate path; serve HTTPS when set.")
    parser.add_argument("--key", default="", help="TLS private key path.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    root = Path(args.dir).resolve()
    if not (root / "index.html").exists():
        raise SystemExit(f"Missing {root / 'index.html'}; run tools/export_web.sh first.")

    mimetypes.add_type("application/wasm", ".wasm")
    mimetypes.add_type("application/octet-stream", ".pck")
    mimetypes.add_type("application/javascript", ".js")

    handler = functools.partial(GodotWebHandler, directory=str(root))
    httpd = ThreadingHTTPServer((args.host, args.port), handler)
    scheme = "http"
    if args.cert:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(args.cert, args.key or None)
        httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
        scheme = "https"
    print(f"Serving {root} at {scheme}://{args.host}:{args.port}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
