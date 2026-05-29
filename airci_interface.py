import json
import mimetypes
import os
import sys
import contextlib
import io
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

import cohere

import llm_agent
import mcp_server


BASE_DIR = Path(__file__).resolve().parent
UI_DIR = BASE_DIR / "ui"
IMAGE_DIR = BASE_DIR / "static" / "image"
HOST = os.getenv("AIRCI_UI_HOST", "127.0.0.1")
PORT = int(os.getenv("AIRCI_UI_PORT", "8051"))


def json_response(handler, payload, status=200):
    data = json.dumps(payload, ensure_ascii=False, default=str).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


def read_json(handler):
    length = int(handler.headers.get("Content-Length", "0"))
    if length == 0:
        return {}
    return json.loads(handler.rfile.read(length).decode("utf-8"))


def file_response(handler, path):
    if not path.exists() or not path.is_file():
        handler.send_error(404, "File not found")
        return
    data = path.read_bytes()
    content_type = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
    handler.send_response(200)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


def parse_tool_result(raw):
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"raw": raw}


def call_tool(name, params):
    if name == "route_performance":
        return parse_tool_result(mcp_server.tool_get_route_performance(params.get("route_id")))
    if name == "at_risk_customers":
        return parse_tool_result(
            mcp_server.tool_get_at_risk_customers(
                days_inactive=int(params.get("days_inactive", 90)),
                min_ltv_usd=float(params.get("min_ltv_usd", 500)),
                loyalty_tier=params.get("loyalty_tier") or None,
                limit=int(params.get("limit", 10)),
            )
        )
    if name == "budget":
        return parse_tool_result(mcp_server.tool_get_budget_recommendation())
    if name == "compare_routes":
        return parse_tool_result(
            mcp_server.tool_compare_routes(
                route_a=params.get("route_a", "R001"),
                route_b=params.get("route_b", "R002"),
            )
        )
    if name == "route_sentiment":
        return parse_tool_result(mcp_server.tool_analyze_route_sentiment(params.get("route_id", "R001")))
    raise ValueError(f"Unknown tool: {name}")


def ask_agent(question):
    api_key = os.getenv("COHERE_API_KEY")
    if not api_key:
        return {"answer": "COHERE_API_KEY est absent du .env.", "tool_outputs": []}

    client = cohere.Client(api_key=api_key)
    mcp_server._cohere = client
    # Capture les logs internes pour eviter les erreurs d'encodage console Windows.
    with contextlib.redirect_stdout(io.StringIO()):
        answer = llm_agent.run_agent(client, question, verbose=False)
    return {"answer": answer}


class AirCIHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(UI_DIR), **kwargs)

    def log_message(self, fmt, *args):
        sys.stderr.write("[airci-ui] " + fmt % args + "\n")

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/health":
            json_response(self, {"ok": True, "db_path": mcp_server.DB_PATH})
            return

        if parsed.path == "/api/summary":
            json_response(self, call_tool("budget", {}))
            return

        if parsed.path == "/":
            self.path = "/index.html"

        if parsed.path.startswith("/image/"):
            image_name = Path(parsed.path).name
            file_response(self, IMAGE_DIR / image_name)
            return

        return super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        try:
            body = read_json(self)
            if parsed.path == "/api/tool":
                json_response(self, call_tool(body.get("tool"), body.get("params", {})))
                return
            if parsed.path == "/api/ask":
                json_response(self, ask_agent(body.get("question", "")))
                return
            json_response(self, {"error": "Endpoint not found"}, status=404)
        except Exception as exc:
            json_response(self, {"error": str(exc)}, status=500)


def main():
    server = ThreadingHTTPServer((HOST, PORT), AirCIHandler)
    url = f"http://{HOST}:{PORT}"
    print(f"Air CI Analytics Interface running at {url}")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Air CI Analytics Interface.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
