#!/usr/bin/env python3
"""
serve.py — سيرفر تحميل صغير للباك (باش تحمّل .mcpack مباشرة من الهاتف)

الاستعمال:
    python3 serve.py [--port 8000]

من بعد حل: http://<IP ديال الجهاز>:8000
(ولا دير رابط الـ Live Preview إلا كنت فـ Arena)
"""
from __future__ import annotations

import argparse
import html
import http.server
import pathlib
import socket
import socketserver

DIST = pathlib.Path(__file__).resolve().parent / "dist"
LOWEND = DIST.parent.parent / "dist" / "LowEnd-Vibes.mcpack"

FILES = {
    "Cinematic-Realism.mcpack": DIST / "Cinematic-Realism.mcpack",
    "Cinematic-Realism-Lite.mcpack": DIST / "Cinematic-Realism-Lite.mcpack",
    "LowEnd-Vibes.mcpack": LOWEND,
}

DESCR = {
    "Cinematic-Realism.mcpack": ("🎬 نسخة كاملة", "1.9 MB — 334 خامة PBR + normal maps + ACES (لجهاز متوسط/قوي)"),
    "Cinematic-Realism-Lite.mcpack": ("⚡ نسخة خفيفة", "1.6 MB — للأجهزة الضعيفة بحال vivo Y04"),
    "LowEnd-Vibes.mcpack": ("🌫️ ضباب خفيف", "103 KB — كيخدم بلا Vibrant Visuals"),
}

INDEX = """<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>تحميل Cinematic Realism</title>
<style>
  :root {{ color-scheme: dark; }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; padding: 24px 16px 60px; background: #0b1020; color: #e8eefc;
         font-family: -apple-system, "Segoe UI", Roboto, "Noto Naskh Arabic", sans-serif; }}
  .wrap {{ max-width: 640px; margin: 0 auto; }}
  h1 {{ font-size: 1.6rem; margin: 0 0 6px; }}
  p.sub {{ color: #93a4c8; margin: 0 0 26px; line-height: 1.7; }}
  a.card {{ display: block; text-decoration: none; color: inherit;
      background: linear-gradient(160deg, #16203a, #101830); border: 1px solid #26324f;
      border-radius: 16px; padding: 18px 20px; margin-bottom: 14px; }}
  a.card:active {{ transform: scale(.985); }}
  .title {{ font-size: 1.15rem; font-weight: 700; margin-bottom: 6px; }}
  .desc {{ color: #9fb1d6; font-size: .92rem; line-height: 1.6; }}
  .dl {{ float: left; background: #2f6df6; color: #fff; border-radius: 10px;
        padding: 8px 16px; font-weight: 700; font-size: .9rem; }}
  .steps {{ margin-top: 28px; background: #101830; border: 1px solid #26324f;
           border-radius: 16px; padding: 18px 20px; }}
  .steps h2 {{ font-size: 1.05rem; margin: 0 0 12px; }}
  .steps ol {{ margin: 0; padding-inline-start: 22px; line-height: 2; color: #c3d1ee; }}
  code {{ background: #1c2742; padding: 2px 6px; border-radius: 6px; font-size: .85rem; }}
</style>
</head>
<body>
<div class="wrap">
  <h1>🎬 تحميل الباك</h1>
  <p class="sub">دير ضغطة على الملف → كيتحمّل → دير عليه ضغطة مرة أخرى → <b>Open with Minecraft</b>.</p>
  {cards}
  <div class="steps">
    <h2>📲 خطوات التنصيب</h2>
    <ol>
      <li>حمّل الملف وافتحو بـ Minecraft</li>
      <li><code>Settings → Global Resources</code> وفعّل الباك</li>
      <li><code>Settings → Video → Graphics Mode</code> وختار <b>Vibrant Visuals</b></li>
      <li>دخل للعالم وسير لوقت الغروب 🌅</li>
    </ol>
  </div>
</div>
</body>
</html>
"""


def build_index() -> bytes:
    cards = []
    for name, path in FILES.items():
        if not path.exists():
            continue
        title, desc = DESCR.get(name, (name, ""))
        cards.append(
            f'<a class="card" href="/dl/{html.escape(name)}">'
            f'<span class="dl">تحميل</span>'
            f'<div class="title">{title}</div>'
            f'<div class="desc">{html.escape(name)}<br>{desc}</div></a>'
        )
    return INDEX.format(cards="\n".join(cards)).encode("utf-8")


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "CinematicRealism/1.0"

    def do_GET(self) -> None:  # noqa: N802
        if self.path in ("/", "/index.html"):
            body = build_index()
            self._send(200, "text/html; charset=utf-8", body)
            return
        if self.path.startswith("/dl/"):
            name = self.path[4:]
            path = FILES.get(name)
            if path is None or not path.exists():
                self._send(404, "text/plain; charset=utf-8", b"not found")
                return
            data = path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Content-Disposition", f'attachment; filename="{name}"')
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)
            print(f"⬇️  تحميل: {name} ({len(data) / 1048576:.2f} MB) ← {self.client_address[0]}", flush=True)
            return
        self._send(404, "text/plain; charset=utf-8", b"not found")

    def _send(self, code: int, ctype: str, body: bytes) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):  # هادي كتخلي الكونسول نقي
        pass


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--host", default="0.0.0.0")
    a = ap.parse_args()

    present = [n for n, p in FILES.items() if p.exists()]
    Server((a.host, a.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
