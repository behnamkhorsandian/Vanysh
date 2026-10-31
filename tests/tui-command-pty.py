#!/usr/bin/env python3
"""Exercise command prompts, resizing, exit status, and cancellation in CI."""
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
pane = root / 'tui' / 'command-pane.py'


def run(command, cancel=False):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 26, 100, 0, 0))

    def terminal_session():
        os.setsid()
        fcntl.ioctl(0, termios.TIOCSCTTY, 0)

    process = subprocess.Popen(
        ['python3', str(pane), 'Command check', 'bash', '-c', command],
        stdin=slave, stdout=slave, stderr=slave, preexec_fn=terminal_session,
        env=dict(os.environ, TERM='xterm-256color'),
    )
    os.close(slave)
    pending = b''

    def wait_for(needle):
        nonlocal pending
        needle = needle.encode()
        deadline = time.monotonic() + 15
        while needle not in pending:
            if time.monotonic() > deadline or process.poll() is not None:
                raise AssertionError('Did not see {!r}: {!r}'.format(needle, pending[-5000:]))
            readable, _, _ = select.select([master], [], [], 0.2)
            if readable:
                try: pending += os.read(master, 65536)
                except OSError: pass
        end = pending.index(needle) + len(needle)
        found, pending = pending[:end], pending[end:]
        return found

    try:
        output = wait_for('PROMPT_READY')
        if b'Command check' not in output:
            raise AssertionError('The command was not displayed in the pane')
        wait_for('Ctrl-]: cancel')
        if cancel:
            os.write(master, b'\x1d')
        else:
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', 20, 72, 0, 0))
            wait_for('Command check')
            os.write(master, b'hello\n')
            wait_for('ANSWER=hello')
            wait_for('SIZE=')
            size = wait_for('70')
            if b'70' not in size:
                raise AssertionError('The command did not receive the resized width')
        wait_for('Finished.')
        os.write(master, b'\n')
        expected = 130 if cancel else 7
        actual = process.wait(timeout=10)
        if actual != expected:
            raise AssertionError('Expected exit {}, got {}'.format(expected, actual))
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=10)
        os.close(master)


run("printf 'PROMPT_READY\\n'; read -r answer </dev/tty; printf 'ANSWER=%s\\n' \"$answer\"; printf 'SIZE='; stty size </dev/tty; exit 7")
run("printf 'PROMPT_READY\\n'; sleep 60", cancel=True)
print('Interactive command pane checks passed')
