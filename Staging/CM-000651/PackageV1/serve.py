from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import os
os.chdir(r"C:\Dynomax\Staging\CM-000651\PackageV1")
class H(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "https://localhost:7155")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
ThreadingHTTPServer(("127.0.0.1",8886),H).serve_forever()
