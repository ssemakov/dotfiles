#!/usr/bin/env python3
"""Exercise the real macOS sandbox with disposable files and local servers.

Run outside another sandbox: python3 tests/safehouse.py
No agents, GUI applications, or existing service sockets are invoked.
"""

import http.server
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading


ROOT = Path(__file__).resolve().parents[1]
SAFE = ROOT / "bin/safe"
SAFEHOUSE = shutil.which("safehouse")
assert SAFEHOUSE, "Install Safehouse before running these checks"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"sandbox-http-ok")

    def log_message(self, *args):
        pass


PROBE = r'''
import ctypes, errno, os, socket, subprocess, sys, urllib.request
from pathlib import Path

home = Path(os.environ["HOME"])
for path in [
    home / ".asdf/installs/test-tool",
    home / ".local/bin/test-tool",
    home / ".cargo/bin/test-tool",
    home / ".rustup/test-tool",
    home / ".config/agent-safehouse/local-overrides.sb",
    Path(sys.argv[3]).resolve(),
]:
    assert path.read_bytes(), f"Installed tools/policy must remain readable: {path}"
    try:
        fd = os.open(path, os.O_WRONLY)  # No truncation or writes, even on failure.
    except OSError as exc:
        assert exc.errno in (errno.EPERM, errno.EACCES), (path, exc)
    else:
        os.close(fd)
        raise AssertionError(f"Unexpected write access: {path}")

Path("allowed.txt").write_text("workspace writes still work")
with urllib.request.urlopen(sys.argv[1], timeout=5) as response:
    assert response.read() == b"sandbox-http-ok"
assert socket.getaddrinfo("example.com", 443), "DNS must still work"

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    sock.connect(sys.argv[2])
except OSError as exc:
    assert exc.errno in (errno.EPERM, errno.EACCES), exc
else:
    raise AssertionError("Connected to a host UNIX socket")
finally:
    sock.close()

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    sock.bind(str(home / "child.sock"))
except OSError as exc:
    assert exc.errno in (errno.EPERM, errno.EACCES), exc
else:
    raise AssertionError("Created a UNIX listener")
finally:
    sock.close()

lib = ctypes.CDLL("/usr/lib/libsandbox.dylib")
lib.sandbox_check.restype = ctypes.c_int
assert lib.sandbox_check(os.getpid(), b"lsopen", 0) > 0, "Launch Services is allowed"

if len(sys.argv) == 4:
    result = subprocess.run([sys.executable, "-c", PROBE_SOURCE, *sys.argv[1:], "child"])
    assert result.returncode == 0, "Child process did not retain sandbox restrictions"
print("PASS: reads/workspace/HTTP/DNS allowed; tool writes/UNIX sockets/lsopen denied")
'''
PROBE = "PROBE_SOURCE = " + repr(PROBE) + "\n" + PROBE


with tempfile.TemporaryDirectory(prefix="safehouse-check-") as temporary:
    home = Path(temporary)
    (home / "workspace").mkdir()
    profile = home / ".config/agent-safehouse/local-overrides.sb"
    profile.parent.mkdir(parents=True)
    shutil.copyfile(ROOT / "agent-safehouse/local-overrides.sb", profile)
    for relative in (".asdf/installs/test-tool", ".local/bin/test-tool", ".cargo/bin/test-tool", ".rustup/test-tool"):
        path = home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("unchanged")

    env = dict(os.environ, HOME=str(home))
    sentinel = home / "must-not-execute"
    missing = subprocess.run(
        ["/bin/bash", str(SAFE), "--", "/usr/bin/touch", str(sentinel)],
        env=dict(env, PATH="/usr/bin:/bin"), capture_output=True, text=True,
    )
    assert missing.returncode == 127 and not sentinel.exists(), missing.stderr
    print("PASS: missing Safehouse fails closed")

    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    # Exercise a socket explicitly allowed by an optional upstream integration.
    (home / ".docker/run").mkdir(parents=True)
    unix_path = str(home / ".docker/run/docker.sock")
    listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    listener.bind(unix_path)
    listener.listen(1)
    try:
        subprocess.run(
            ["/bin/bash", str(SAFE), "--enable=docker,ssh,launch-services", "--", "/usr/bin/python3", "-c", PROBE,
             f"http://127.0.0.1:{server.server_port}", unix_path, SAFEHOUSE],
            cwd=home / "workspace", env=env, check=True, timeout=45,
        )
    finally:
        listener.close()
        server.shutdown()
        server.server_close()

    profile.unlink()
    missing = subprocess.run(
        ["/bin/bash", str(SAFE), "--", "/usr/bin/touch", str(sentinel)],
        env=env, capture_output=True, text=True,
    )
    assert missing.returncode != 0 and not sentinel.exists(), missing.stderr
    print("PASS: missing override policy fails closed")
