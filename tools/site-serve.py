# Serve build/site on http://127.0.0.1:8001 to look at the site before a release (make site-serve).
# It sends "Access-Control-Allow-Origin: *" like GitHub Pages does, so the Play button can load the game
# from this server into the online vc64web emulator.
import http.server, functools, sys

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")   # like GitHub Pages
        self.send_header("Cache-Control", "no-store")           # always the newest local build
        super().end_headers()

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8001
http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(Handler, directory="build/site")).serve_forever()
