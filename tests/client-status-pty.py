#!/usr/bin/env python3
"""Check that the client collects device information only on request."""
import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time
from pathlib import Path

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory() as temp:
    bindir = Path(temp) / 'bin'
    bindir.mkdir()
    counter = Path(temp) / 'requests'
    curl = bindir / 'curl'
    curl.write_text('#!/bin/sh\necho request >> "$PROBE_COUNTER"\nprintf \'{"ip": "192.0.2.1", "city": "Testville"}\\n\'\n')
    curl.chmod(0o755)
    env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ['PATH'],
               PROBE_COUNTER=str(counter), TERM='xterm-256color')
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 28, 120, 0, 0))

    def terminal_session():
        os.setsid()
        fcntl.ioctl(0, termios.TIOCSCTTY, 0)

    process = subprocess.Popen(['bash', str(root / 'scripts' / 'client.sh')],
                               stdin=slave, stdout=slave, stderr=slave,
                               env=env, preexec_fn=terminal_session)
    os.close(slave)
    pending = b''

    def wait_for(text):
        global pending
        needle = text.encode()
        deadline = time.monotonic() + 15
        while needle not in pending:
            if time.monotonic() > deadline or process.poll() is not None:
                raise AssertionError('Did not see {!r}: {!r}'.format(needle, pending[-3000:]))
            ready, _, _ = select.select([master], [], [], 0.2)
            if ready:
                try: pending += os.read(master, 65536)
                except OSError: pass
        end = pending.index(needle) + len(needle)
        seen, pending = pending[:end], pending[end:]
        return seen

    def requests():
        return len(counter.read_text().splitlines()) if counter.exists() else 0

    try:
        home = wait_for('Welcome to Vany')
        if b'CPU' in home or requests():
            raise AssertionError('The home page collected or showed device information')
        os.write(master, b'2')
        wait_for('Select a protocol')
        if requests():
            raise AssertionError('The protocol page collected device information')
        os.write(master, b'q')
        wait_for('Welcome to Vany')
        os.write(master, b's')
        wait_for('S  Refresh status')
        if requests() != 1:
            raise AssertionError('Opening status did not collect information once')
        pending = b''
        os.write(master, b'x')
        wait_for('S  Refresh status')
        if requests() != 1:
            raise AssertionError('Status refreshed without S')
        pending = b''
        os.write(master, b's')
        wait_for('S  Refresh status')
        if requests() != 2:
            raise AssertionError('S did not refresh status')
        os.write(master, b'q')
        wait_for('Welcome to Vany')
        os.write(master, b'q')
        if process.wait(timeout=10) != 0:
            raise AssertionError('The client exited with an error')
        print('Client manual status checks passed')
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=5)
        os.close(master)
