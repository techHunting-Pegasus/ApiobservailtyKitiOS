"""Local echo server for the networking regression executable. No external API calls."""
import json
import re
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    uploads = []

    def do_GET(self):
        self.reply()

    def do_POST(self):
        self.reply()

    def reply(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0"))).decode()
        if self.path == "/monitor":
            Handler.uploads.extend(json.loads(body)["logs"])
        payload = json.dumps({
            "method": self.command,
            "path": self.path,
            "headers": {k.lower(): v for k, v in self.headers.items()},
            "body": body,
            "password": "test-secret",
        }).encode()
        self.send_response(503 if self.path == "/http-error" else 200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Set-Cookie", "session=test-session")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_):
        pass


with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
    threading.Thread(target=server.serve_forever, daemon=True).start()
    result = subprocess.run([sys.argv[1], f"http://127.0.0.1:{server.server_port}"],
                            capture_output=True, text=True)
    print(result.stdout, end="")
    print(result.stderr, end="", file=sys.stderr)
    server.shutdown()
    if result.returncode:
        raise SystemExit(result.returncode)
    uploads = {log["requestId"]: log for log in Handler.uploads}
    console = {}
    for label, content in re.findall(r"(API REQUEST|API RESPONSE)\n━+\n(.*?)\n━+",
                                     result.stdout, re.S):
        request_id = re.search(r"Request ID:\n([^\n]+)", content)[1]
        console[label, request_id] = content
    assert len(Handler.uploads) == 17, "Missing, duplicate, or unexpected monitoring uploads"
    for mask in range(16):
        log = uploads[f"upload-mask-{mask}"]
        for bit, field in [(1, "requestHeaders"), (2, "requestBody"),
                           (4, "responseHeaders"), (8, "responseBody")]:
            assert (field in log) == bool(mask & bit), (mask, field, log)
        assert log["method"] == "POST" and log["responseStatus"] == 200
        # API prints are independent of what the monitoring POST contains.
        for label, flag_bits in [("API REQUEST", (1, 2)), ("API RESPONSE", (4, 8))]:
            content = console[label, f"upload-mask-{mask}"]
            headers = re.search(r"Headers:\n([^\n]+)", content)[1]
            body = re.search((r"Body:" if label == "API REQUEST" else r"Response:")
                             + r"\n(.*?)(?=\n\nError:|\Z)", content, re.S)[1].strip()
            assert (headers == "[:]") == bool(mask & flag_bits[0]), (mask, label, "headers")
            assert (body == "nil") == bool(mask & flag_bits[1]), (mask, label, "body")
    default_log = uploads["upload-defaults"]
    assert all(field in default_log for field in
               ["requestHeaders", "requestBody", "responseHeaders", "responseBody"])
    assert default_log["responseStatus"] == 503, "Failed API response was not uploaded"
    print("PASS: 16 upload/console combinations, actual monitoring JSON, default uploads, HTTP 503")
