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
source "$TUI_DIR/pages/actions.sh"
source "$TUI_DIR/pages/manage.sh"
source "$TUI_DIR/pages/journey.sh"
source "$TUI_DIR/pages/chooser.sh"
source "$TUI_DIR/pages/main.sh"
_refresh_machine_metrics() {
  (( METRIC_CALLS++ ))
  _METRIC_CPU="${METRIC_CALLS}%"; _METRIC_RAM="100/200 MiB"; _METRIC_NET="1/2 KiB/s"
  _METRIC_IP="192.0.2.1"; _METRIC_LOCATION="test"
}
METRIC_CALLS=0
_refresh_menu_status() { :; }
page_setup_checks() { return 0; }
FAKE_COUNT=0
_manage_run() {
  (( FAKE_COUNT++ ))
  if (( FAKE_COUNT == 1 )); then
    tui_run_action "Set up WireGuard" "Vany is working on this server." 0 bash -c 'printf "INSTALL_LOG_SECRET\n"; sleep 1'
  else
    tui_run_action "Set up WireGuard" "Vany is working on this server." 0 bash -c 'sleep 60'
  fi
}
tui_init || exit 1
page_main_menu
if [[ "$SELECTED_PROTOCOL" == _choose ]]; then page_chooser; fi
printf '\nTEST_SELECTED=%s\n' "$START_PROTOCOL"
if [[ -n "$START_PROTOCOL" ]]; then page_main_menu; fi
if [[ "$SELECTED_PROTOCOL" == _manage ]]; then page_manage "$PROTOCOL_TO_MANAGE"; fi
tui_cleanup
printf '\nTEST_DONE\n'
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
    first_home = wait_for("Welcome to Vany")
    if b"CPU" in first_home or b"192.0.2.1" in first_home:
        raise AssertionError("Machine information appeared on the home page")
    deadline = time.monotonic() + 7
    while time.monotonic() < deadline:
        read_more(min(0.5, max(0, deadline - time.monotonic())))
    if b"\x1b[2J" in pending or b"Welcome to Vany" in pending:
        raise AssertionError("Idle status refresh redrew or cleared the whole screen")
    if b"\x1b7" in pending:
        raise AssertionError("The TUI refreshed its header while idle")
    pending = b""

    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 18, 60, 0, 0))
    wait_for("Welcome to Vany")
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 28, 120, 0, 0))
    wait_for("Welcome to Vany")

    send("s")
    wait_for("CPU: 1%")
    wait_for("S: refresh")
    pending = b""
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        read_more(min(0.5, max(0, deadline - time.monotonic())))
    if b"\x1b7" in pending or b"CPU: 2%" in pending:
        raise AssertionError("Status refreshed without a key press")
    send("s")
    wait_for("CPU: 2%")
    send("h")
    wait_for("Welcome to Vany")

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
    wait_for("1  Create or manage this service")
    send("2")
    wait_for("Connect with WireGuard")
    send("q")
    wait_for("1  Create or manage this service")
    send("1")
    frame = wait_for("Manage WireGuard")
    if "┬".encode() not in frame:
        raise AssertionError("Management did not use the normal Vany frame")
    send("1")
    wait_for("Vany is working on this server.")
    output = wait_for("Complete.")
    if b"INSTALL_LOG_SECRET" in output:
        raise AssertionError("Command details leaked into the progress view")
    send("d")
    wait_for("INSTALL_LOG_SECRET")
    send("q")
    wait_for("Manage WireGuard")
    send("1")
    wait_for("Vany is working on this server.")
    send("q")
    wait_for("Stopping now can leave partial changes.")
    send("y")
    wait_for("The action did not finish.")
    send("q")
    wait_for("Manage WireGuard")
    send("q")
    wait_for("TEST_DONE")
    if process.wait(timeout=5) != 0:
        raise AssertionError("TUI exited with an error")
    print("Pseudo-terminal refresh and chooser checks passed")
finally:
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=5)
    os.close(master)
