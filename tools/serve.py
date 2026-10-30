# serve.py - serves the vc64web browser emulator and the game build from one local address
#   http://127.0.0.1:8000/            the emulator (tools/vc64web, fetched by "make emu")
#   http://127.0.0.1:8000/game/       the build folder, so /game/raster-rumble.prg is the newest build
# Emulator and game come from the same address, so the browser needs no cross-site permission.
# Usage: python3 tools/serve.py [port]   (the Makefile runs this: make serve, make test)
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, "tools", "vc64web")
BUILD = os.path.join(ROOT, "build")

class Handler(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        # /game/x becomes build/x, everything else comes from the emulator folder
        path = path.split("?", 1)[0].split("#", 1)[0]
        if path.startswith("/game/"):
            return os.path.join(BUILD, os.path.normpath(path[len("/game/"):]).lstrip("/\\"))
        return os.path.join(EMU, os.path.normpath(path).lstrip("/\\"))

    def do_GET(self):
        # vc64web turns every http:// link into https://, which cannot reach this plain http server.
        # Hand out its loader with that one rewrite limited to csdb.dk, and leave the clone itself untouched.
        if self.path.split("?", 1)[0] == "/js/vc64_browser.js":
            with open(os.path.join(EMU, "js", "vc64_browser.js"), "rb") as f:
                body = f.read().replace(b"link.replace('http://', 'https://')", b"link.replace('http://csdb', 'https://csdb')")
            self.send_response(200)
            self.send_header("Content-Type", "text/javascript")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path.split("?", 1)[0] == "/sw.js":
            # the emulator's offline cache would keep handing out an old loader and an old game: replace it
            # with a worker that empties every cache and takes over, so a plain reload always shows the newest files
            body = (b"self.addEventListener('install',e=>self.skipWaiting());"
                    b"self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(k=>Promise.all(k.map(c=>caches.delete(c)))).then(()=>self.clients.claim())));")
            self.send_response(200)
            self.send_header("Content-Type", "text/javascript")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")  # always hand out the newest build
        super().end_headers()

    def log_message(self, *args):  # keep the terminal quiet
        pass

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
