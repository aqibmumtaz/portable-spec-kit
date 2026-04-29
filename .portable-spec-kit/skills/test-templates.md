# Skill: Test Templates

> **Purpose:** Reusable test-fixture patterns promoted from real AVACR evaluations. Drop-in building blocks for integration / end-to-end tests that unit tests can't catch.
>
> **Loaded when:** user mentions integration tests / end-to-end tests / FastAPI tests / subprocess fixtures / live-server testing / "unit tests pass but the real thing is broken".

---

## When to use

Unit tests answer "does this function return the right value?" Integration tests answer "does the running system deliver the contract?" For features that only break when wired together — middleware interactions, trusted-proxy header handling, client↔server roundtrips, database-connected queries — unit-level mocks can't reproduce the failure. The patterns below are promoted from an AVACR pass-2 regression (`searchsocialtruth` eval) where a trusted-proxy `X-Forwarded-For` bug passed 47 unit tests but was caught the moment a real `uvicorn` process was started and queried over HTTP.

Two patterns ship in this skill:

1. **Live-uvicorn subprocess fixture** — for Python / FastAPI (or any ASGI app). Spawns the real server, waits for `/healthz`, returns a client, tears down on exit.
2. **Random free-port allocator** — utility used by the live-server pattern; generalizes to Node / Go / Rust / Ruby servers too.

Both patterns are session-scoped when possible (one server process reused across tests) with a module-level teardown guaranteed via `atexit` / `finally` semantics.

---

## Pattern 1 — Live-uvicorn subprocess fixture (Python / FastAPI)

```python
# tests/conftest.py
import atexit
import socket
import subprocess
import sys
import time
from contextlib import closing
from pathlib import Path

import httpx
import pytest


def _find_free_port() -> int:
    """Ask the OS for an unused port. Race-free for single-process test runs."""
    with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _wait_for_healthz(base_url: str, timeout_s: float = 10.0) -> None:
    """Poll /healthz until the server accepts traffic or timeout fires."""
    deadline = time.monotonic() + timeout_s
    last_exc: Exception | None = None
    while time.monotonic() < deadline:
        try:
            r = httpx.get(f"{base_url}/healthz", timeout=1.0)
            if r.status_code == 200:
                return
        except Exception as e:  # ConnectionError, ReadTimeout, etc.
            last_exc = e
        time.sleep(0.1)
    raise RuntimeError(
        f"server at {base_url} did not become healthy within {timeout_s}s "
        f"(last error: {last_exc})"
    )


@pytest.fixture(scope="session")
def live_server(tmp_path_factory):
    """
    Start uvicorn serving the real app on a random free port, wait for /healthz,
    yield the base URL, then terminate on session teardown.

    Tests that need an actually-running process (middleware, TrustedHost, CORS,
    XFF header handling, streaming responses) should depend on this fixture.
    """
    port = _find_free_port()
    base_url = f"http://127.0.0.1:{port}"

    # Isolated SQLite for the test session — no cross-test state leakage.
    db_path = tmp_path_factory.mktemp("live-db") / "app.sqlite"

    env = {
        "APP_DATABASE_URL": f"sqlite:///{db_path}",
        "APP_LOG_LEVEL": "warning",
        "APP_TRUSTED_PROXIES": "127.0.0.1",  # override for XFF-dependent tests
        # Inherit PATH + HOME so uvicorn + python can be located
        "PATH": __import__("os").environ.get("PATH", ""),
        "HOME": __import__("os").environ.get("HOME", ""),
    }

    proc = subprocess.Popen(
        [
            sys.executable, "-m", "uvicorn",
            "app.main:app",
            "--host", "127.0.0.1",
            "--port", str(port),
            "--log-level", "warning",
            "--no-access-log",
        ],
        cwd=Path(__file__).parent.parent,  # repo root
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    # Guarantee teardown even on hard pytest crashes
    atexit.register(lambda: proc.terminate() if proc.poll() is None else None)

    try:
        _wait_for_healthz(base_url)
    except Exception:
        proc.terminate()
        stdout, _ = proc.communicate(timeout=2)
        raise RuntimeError(
            f"live_server failed to start. captured output:\n{stdout.decode()[:2000]}"
        )

    yield base_url

    proc.terminate()
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
```

### Using it in a test

```python
# tests/test_xff_trust.py
import httpx


def test_xff_trusted_proxy_sees_forwarded_ip(live_server):
    """Proxy at 127.0.0.1 is trusted — X-Forwarded-For client IP propagates."""
    r = httpx.get(
        f"{live_server}/whoami",
        headers={"X-Forwarded-For": "203.0.113.42"},
    )
    assert r.status_code == 200
    assert r.json()["client_ip"] == "203.0.113.42"


def test_xff_untrusted_proxy_sees_socket_ip(live_server):
    """Without trusted-proxy config, XFF is ignored — socket IP wins."""
    r = httpx.get(
        f"{live_server}/whoami",
        headers={"X-Forwarded-For": "203.0.113.42"},
    )
    # If trust is correctly enforced, even with the header present, we see
    # the socket IP (127.0.0.1) because the spoofing header is rejected.
    assert r.json()["client_ip"] in {"127.0.0.1", "::1"}
```

---

## Pattern 2 — Random free-port allocator (language-agnostic idiom)

The `_find_free_port()` helper above uses the "bind to port 0, read assigned port, close" trick. This works on every major OS and is race-free within a single process. Equivalents in other languages:

### Node.js
```javascript
function findFreePort() {
  return new Promise((resolve, reject) => {
    const srv = require("net").createServer();
    srv.listen(0, "127.0.0.1", () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    });
    srv.on("error", reject);
  });
}
```

### Go
```go
func FindFreePort() (int, error) {
    l, err := net.Listen("tcp", "127.0.0.1:0")
    if err != nil {
        return 0, err
    }
    defer l.Close()
    return l.Addr().(*net.TCPAddr).Port, nil
}
```

### Rust
```rust
use std::net::TcpListener;

pub fn find_free_port() -> std::io::Result<u16> {
    let l = TcpListener::bind("127.0.0.1:0")?;
    Ok(l.local_addr()?.port())
}
```

### Bash (Linux, using `ss`)
```bash
find_free_port() {
  python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'
}
```

---

## When NOT to use these patterns

- **Pure function tests** — if a function has no I/O, no side effects, and no framework coupling, plain unit tests are faster and simpler. Don't spin up a server.
- **Mock-first unit-test suites** — if the test already verifies behavior via mocked dependencies AND you trust the mock matches reality, integration tests add wall-clock cost without new signal.
- **CI budgets under 5 minutes** — live-server fixtures add 1-3 seconds of startup per test session. On tight CI pipelines, gate them behind a `@pytest.mark.integration` marker and run separately.

## Why this is promoted to a skill

The `searchsocialtruth` AVACR pass-2 surfaced a security regression (`X-Forwarded-For` client IP was wrongly trusted from untrusted proxies) that passed every single unit test in the codebase. The Dev-Agent's fix — adding `trusted_proxies` config enforcement — was caught only after QA wrote a live-server integration test using exactly the `_find_free_port + _wait_for_healthz + subprocess.Popen` trio above. Promoting the pattern to a kit skill means every Python / FastAPI user inherits the fixture by default, not just those who happen to have run AVACR.

**Provenance:** surfaced by AVACR SearchSocialTruth eval (2026-04-20), closed as G7 in v0.6 AVACR Framework Gaps.
