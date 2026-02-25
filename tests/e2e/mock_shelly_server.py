import json
from http.server import BaseHTTPRequestHandler, HTTPServer

PAYLOAD = {
    "id": 0,
    "source": "init",
    "output": True,
    "apower": 0.0,
    "voltage": 227.2,
    "freq": 49.9,
    "current": 0.000,
    "aenergy": {
        "total": 8037.000,
        "by_minute": [0.000, 0.000, 0.000],
        "minute_ts": 1772013000,
    },
    "ret_aenergy": {
        "total": 0.000,
        "by_minute": [0.000, 0.000, 0.000],
        "minute_ts": 1772013000,
    },
    "temperature": {"tC": 22.7, "tF": 72.9},
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/rpc/Switch.GetStatus"):
            body = json.dumps(PAYLOAD).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 18080), Handler).serve_forever()
