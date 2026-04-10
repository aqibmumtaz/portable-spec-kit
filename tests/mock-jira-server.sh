#!/bin/bash
# =============================================================
# mock-jira-server.sh — Lightweight Jira API Mock for Testing
#
# Uses Python's built-in HTTP server to serve fixture JSON
# responses based on request path.
#
# Usage:
#   bash tests/mock-jira-server.sh start [port]  # default 18080
#   bash tests/mock-jira-server.sh stop
#   bash tests/mock-jira-server.sh status
#
# Set JIRA_BASE_URL_OVERRIDE=http://localhost:18080 in tests
# to point psk-jira-sync.sh at this mock.
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/jira"
PID_FILE="/tmp/psk-mock-jira.pid"
DEFAULT_PORT=18080

# --- Mock HTTP handler (Python) ---
start_server() {
  local port="${1:-$DEFAULT_PORT}"

  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Mock server already running (PID $(cat "$PID_FILE"))"
    return 0
  fi

  python3 -c "
import http.server
import json
import os
import sys

PORT = int(sys.argv[1])
FIXTURES = sys.argv[2]

class MockJiraHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Suppress default logging

    def send_fixture(self, filename, status=200):
        filepath = os.path.join(FIXTURES, filename)
        if os.path.exists(filepath):
            with open(filepath) as f:
                data = f.read()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(data.encode())
        else:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b'{\"error\": \"fixture not found\"}')

    def do_GET(self):
        path = self.path.split('?')[0]  # strip query params

        if path == '/rest/api/3/myself':
            # Check auth header
            auth = self.headers.get('Authorization', '')
            if not auth:
                self.send_fixture('error-401.json', 401)
            else:
                self.send_fixture('user.json')

        elif path.startswith('/rest/api/3/project/') and path.count('/') == 5:
            key = path.split('/')[-1]
            if key == 'TESTPROJ':
                self.send_fixture('project.json')
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b'{\"errorMessages\":[\"No project could be found\"]}')

        elif '/statuses' in path or '/issuetypes' in path:
            self.send_fixture('issuetypes.json')

        elif '/transitions' in path:
            self.send_fixture('transitions.json')

        elif '/issue/' in path:
            # GET /issue/PROJ-NNN — return basic issue with status
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                'key': path.split('/')[-1].split('?')[0],
                'fields': {'status': {'name': 'In Progress'}}
            }).encode())

        elif path == '/mock/rate-limit':
            self.send_response(429)
            self.send_header('Retry-After', '2')
            self.end_headers()
            self.wfile.write(b'{\"message\":\"Rate limit exceeded\"}')

        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'{\"error\": \"unknown endpoint\"}')

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else b''
        path = self.path.split('?')[0]

        if path == '/rest/api/3/issue':
            self.send_fixture('created-issue.json', 201)

        elif '/worklog' in path:
            self.send_fixture('worklog.json', 201)

        elif '/transitions' in path:
            self.send_response(204)
            self.end_headers()

        elif path == '/rest/api/3/version':
            self.send_response(201)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{\"id\":\"10100\",\"name\":\"v0.5\"}')

        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'{\"error\": \"unknown POST endpoint\"}')

server = http.server.HTTPServer(('localhost', PORT), MockJiraHandler)
print(f'Mock Jira server running on http://localhost:{PORT}')
server.serve_forever()
" "$port" "$FIXTURES_DIR" &

  local pid=$!
  echo "$pid" > "$PID_FILE"

  # Wait for server to be ready
  local attempts=0
  while ! curl -s "http://localhost:$port/rest/api/3/myself" -H "Authorization: Basic dGVzdA==" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ $attempts -gt 20 ]; then
      echo "Mock server failed to start"
      kill "$pid" 2>/dev/null
      rm -f "$PID_FILE"
      return 1
    fi
    sleep 0.2
  done

  echo "Mock Jira server started (PID $pid, port $port)"
  echo "Set: export JIRA_BASE_URL_OVERRIDE=http://localhost:$port"
}

stop_server() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      echo "Mock server stopped (PID $pid)"
    fi
    rm -f "$PID_FILE"
  else
    echo "No mock server running"
  fi
}

show_status() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Mock Jira server running (PID $(cat "$PID_FILE"))"
  else
    echo "Mock Jira server not running"
    rm -f "$PID_FILE" 2>/dev/null
  fi
}

case "${1:-}" in
  start)   start_server "${2:-$DEFAULT_PORT}" ;;
  stop)    stop_server ;;
  status)  show_status ;;
  *)
    echo "Usage: bash tests/mock-jira-server.sh [start|stop|status] [port]"
    exit 1
    ;;
esac
