#!/usr/bin/env python3
"""Local health daemon simulating microservice startup warm-up."""
import argparse
import http.server
import json
import sys
from pathlib import Path


class HealthHandler(http.server.BaseHTTPRequestHandler):
    count = 0
    ready_after = 3

    def do_GET(self):
        HealthHandler.count += 1
        if HealthHandler.count < HealthHandler.ready_after:
            self.send_response(503)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            payload = json.dumps({"status": "WARMING_UP", "attempt": HealthHandler.count})
            self.wfile.write(payload.encode("utf-8"))
        else:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            payload = json.dumps({"status": "READY", "attempt": HealthHandler.count})
            self.wfile.write(payload.encode("utf-8"))

    def log_message(self, format, *args):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--ready-after", type=int, default=3)
    parser.add_argument("--port-file", type=str, default="daemon_port.txt")
    args = parser.parse_args()

    HealthHandler.ready_after = args.ready_after
    HealthHandler.count = 0
    server = http.server.HTTPServer(("127.0.0.1", args.port), HealthHandler)
    actual_port = server.server_address[1]

    if args.port_file:
        Path(args.port_file).write_text(f"{actual_port}\n", encoding="utf-8")

    server.serve_forever()


if __name__ == "__main__":
    main()
