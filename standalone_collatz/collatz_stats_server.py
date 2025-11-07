#!/usr/bin/env python3
"""Lightweight HTTP endpoint for exposing Collatz stats.

Run on the same server as the Collatz tracker:

    python collatz_stats_server.py --port 8080 --state ./collatz_state.json

Requests to `/stats` return the JSON payload; all other paths fall back to
serving the raw state file (so `/collatz_state.json` works for static clients).
"""

from __future__ import annotations

import argparse
import http.server
import json
import os
import socketserver
from typing import Tuple


class CollatzStatsHandler(http.server.SimpleHTTPRequestHandler):
    state_path: str = "collatz_state.json"

    def do_GET(self) -> None:  # noqa: N802 (handler signature)
        if self.path.rstrip('/') in {"/stats", "/stats.json"}:
            self._write_stats()
        elif self.path.rstrip('/') in {"/collatz_state.json", "/state.json"}:
            self._serve_state_file()
        else:
            super().do_GET()

    def _write_stats(self) -> None:
        payload, status = self._load_state()
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_state_file(self) -> None:
        if os.path.exists(self.state_path):
            super().do_GET()
        else:
            self.send_error(404, "State file not found")

    def _load_state(self) -> Tuple[dict, int]:
        if not os.path.exists(self.state_path):
            return {"error": "state file not found"}, 404

        try:
            with open(self.state_path, "r", encoding="utf-8") as fh:
                return json.load(fh), 200
        except json.JSONDecodeError as exc:
            return {"error": f"invalid JSON: {exc}"}, 500


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve Collatz tracker stats")
    parser.add_argument("--host", default="0.0.0.0", help="Bind address (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on")
    parser.add_argument("--state", default="collatz_state.json", help="Path to state JSON file")
    args = parser.parse_args()

    CollatzStatsHandler.state_path = os.path.abspath(args.state)

    directory = os.path.dirname(CollatzStatsHandler.state_path)
    if directory:
        os.chdir(directory)

    with socketserver.ThreadingTCPServer((args.host, args.port), CollatzStatsHandler) as httpd:
        print(f"Serving Collatz stats on {args.host}:{args.port} (state: {CollatzStatsHandler.state_path})")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down")


if __name__ == "__main__":
    main()
