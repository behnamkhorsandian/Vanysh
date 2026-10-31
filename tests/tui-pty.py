#!/usr/bin/env python3
"""Exercise the Linux TUI in a pseudo-terminal in GitHub Actions."""
import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import termios
import time
from pathlib import Path

root = Path(__file__).resolve().parent.parent
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 28, 120, 0, 0))
env = os.environ.copy()
env.update({"TUI_DIR": str(root / "tui"), "TERM": "xterm-256color"})

script = r'''
source "$TUI_DIR/theme.sh"
source "$TUI_DIR/engine.sh"
source "$TUI_DIR/pages/journey.sh"
source "$TUI_DIR/pages/chooser.sh"
source "$TUI_DIR/pages/main.sh"
_refresh_machine_metrics() {
  _METRIC_CPU="9%"; _METRIC_RAM="100/200 MiB"; _METRIC_NET="1/2 KiB/s"
  _METRIC_IP="192.0.2.1"; _METRIC_LOCATION="test"
}
_refresh_menu_status() { :; }
tui_init || exit 1
page_main_menu
if [[ "$SELECTED_PROTOCOL" == _choose ]]; then page_chooser; fi
tui_cleanup
printf '\nTEST_SELECTED=%s\n' "$START_PROTOCOL"
'''


def make_terminal():
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)


process = subprocess.Popen(
    ["bash", "-c", script], stdin=slave, stdout=slave, stderr=slave,
    env=env, preexec_fn=make_terminal,
)
os.close(slave)
pending = b""


def read_more(timeout):
    global pending
    ready, _, _ = select.select([master], [], [], timeout)
    if ready:
        try:
            data = os.read(master, 65536)
        except OSError:
            data = b""
        pending += data
        return bool(data)
    return False


def wait_for(text, timeout=10):
    global pending
    needle = text.encode()
    deadline = time.monotonic() + timeout
    while needle not in pending:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise AssertionError(f"Did not see {text!r}. Output: {pending[-3000:]!r}")
        if process.poll() is not None:
            read_more(0)
            if needle not in pending:
                raise AssertionError(f"TUI exited before {text!r}. Output: {pending[-3000:]!r}")
            continue
        read_more(min(remaining, 0.5))
    end = pending.index(needle) + len(needle)
    seen, pending = pending[:end], pending[end:]
    return seen


def send(key):
    os.write(master, key.encode())


try:
    wait_for("Welcome to Vany")
    deadline = time.monotonic() + 7
    while time.monotonic() < deadline:
        read_more(min(0.5, max(0, deadline - time.monotonic())))
    if b"\x1b[2J" in pending or b"Welcome to Vany" in pending:
        raise AssertionError("Idle status refresh redrew or cleared the whole screen")
    if b"\x1b7" not in pending:
        raise AssertionError("Idle status refresh did not update the header")
    pending = b""

    send("c")
    first = wait_for("What do you want to do?")
    if "┌".encode() not in first:
        raise AssertionError("Chooser did not render inside the TUI frame")
    send("2")
    wait_for("What do you want to provide?")
    send("1")
    wait_for("What matters most for your connection?")
    send("2")
    wait_for("A starting point: WireGuard")
    send("1")
    wait_for("TEST_SELECTED=wg")
    if process.wait(timeout=5) != 0:
        raise AssertionError("TUI exited with an error")
    print("Pseudo-terminal refresh and chooser checks passed")
finally:
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=5)
    os.close(master)
