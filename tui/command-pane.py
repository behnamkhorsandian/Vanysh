#!/usr/bin/env python3
"""Run an interactive command in a bounded terminal pane.

The child has its own controlling terminal, including /dev/tty. No output or
input is saved to disk. Ctrl-] interrupts the command and returns to Vany.
"""
import codecs
import datetime
import fcntl
import os
import pty
import select
import signal
import struct
import sys
import termios
import time
import tty
import unicodedata


class Screen:
    def __init__(self, rows, cols):
        self.rows, self.cols = rows, cols
        self.lines = [[]]
        self.row = self.col = 0
        self.state = "text"
        self.seq = ""
        self.saved = (0, 0)
        self.scroll = 0

    def resize(self, rows, cols):
        self.rows, self.cols = rows, cols
        self.scroll = 0

    def line(self, row):
        while len(self.lines) <= row:
            self.lines.append([])
        return self.lines[row]

    def newline(self):
        self.row += 1
        self.line(self.row)
        if len(self.lines) > 4000:
            del self.lines[:1000]
            self.row -= 1000

    def csi(self, sequence):
        cmd, arg = sequence[-1], sequence[:-1]
        if arg.startswith("?"):
            return
        try:
            params = [int(x) if x else 0 for x in arg.split(";")]
        except ValueError:
            return
        first = params[0] or 1
        top = max(0, self.row - self.rows + 1)
        if cmd in "Hf":
            self.row = top + (params[0] or 1) - 1
            self.col = (params[1] or 1) - 1 if len(params) > 1 else 0
            self.line(self.row)
        elif cmd == "A": self.row = max(top, self.row - first)
        elif cmd == "B": self.row = min(top + self.rows - 1, self.row + first); self.line(self.row)
        elif cmd == "C": self.col = min(self.cols - 1, self.col + first)
        elif cmd == "D": self.col = max(0, self.col - first)
        elif cmd == "G": self.col = min(self.cols - 1, first - 1)
        elif cmd == "J" and params[0] in (2, 3):
            self.lines = [[]]; self.row = self.col = 0
        elif cmd == "K":
            line = self.line(self.row)
            if params[0] == 2: self.lines[self.row] = []
            elif params[0] == 1: line[:self.col + 1] = [' '] * min(len(line), self.col + 1)
            else: del line[self.col:]
        elif cmd == "s": self.saved = (self.row, self.col)
        elif cmd == "u": self.row, self.col = self.saved

    def feed(self, data):
        for char in data:
            if self.state == "osc":
                if char == '\a': self.state = "text"
                elif char == '\x1b': self.state = "osc_escape"
            elif self.state == "osc_escape":
                self.state = "text" if char == '\\' else "osc"
            elif self.state == "escape":
                if char == '[': self.seq = ''; self.state = "csi"
                elif char == ']': self.state = "osc"
                else: self.state = "text"
            elif self.state == "csi":
                self.seq += char
                if '@' <= char <= '~':
                    self.csi(self.seq); self.state = "text"
                elif len(self.seq) > 80: self.state = "text"
            elif char == '\x1b': self.state = "escape"
            elif char == '\r': self.col = 0
            elif char == '\n': self.newline()
            elif char == '\b': self.col = max(0, self.col - 1)
            elif char == '\t': self.col = min(self.cols - 1, (self.col // 8 + 1) * 8)
            elif char >= ' ' and char != '\x7f':
                if unicodedata.combining(char):
                    line = self.line(self.row)
                    if self.col and len(line) >= self.col: line[self.col - 1] += char
                    continue
                width = 2 if unicodedata.east_asian_width(char) in 'WF' else 1
                if self.col + width > self.cols: self.newline(); self.col = 0
                line = self.line(self.row)
                while len(line) < self.col + width: line.append(' ')
                line[self.col] = char
                if width == 2: line[self.col + 1] = ''
                self.col += width
        self.scroll = 0


def terminal_size(fd):
    try:
        rows, cols, _, _ = struct.unpack('HHHH', fcntl.ioctl(fd, termios.TIOCGWINSZ, b'\0' * 8))
        return max(rows, 1), max(cols, 1)
    except OSError:
        return 24, 80


def fit(text, width):
    result, used = '', 0
    for char in text:
        size = 0 if unicodedata.combining(char) else 2 if unicodedata.east_asian_width(char) in 'WF' else 1
        if used + size > width: break
        result += char; used += size
    return result + ' ' * (width - used)


def status_rows(cols, rows):
    now = datetime.datetime.now().astimezone()
    segments = [
        'VANY', 'CPU ' + os.environ.get('VANY_CPU', '?'),
        'RAM ' + os.environ.get('VANY_RAM', '?'),
        'Net down/up ' + os.environ.get('VANY_NET', '?'),
        'IP ' + os.environ.get('VANY_PUBLIC_IP', '?'),
        'Location ~' + os.environ.get('VANY_LOCATION', 'unknown'),
        'UTC ' + datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S'),
        'Local ' + now.strftime('%Y-%m-%d %H:%M:%S %Z'),
    ]
    limit = max(1, cols - 4)
    result = []
    current = ''
    for segment in segments:
        if current and len(current) + len(segment) + 3 > limit:
            result.append(current)
            current = ''
        current = (current + ' | ' if current else '') + segment[:limit]
    if current: result.append(current)
    count = max(1, rows - 7)
    if len(result) > count:
        result = result[:count - 1] + ['S: system details']
    return result


def sample_metrics(previous):
    """Refresh local counters without network requests or extra processes."""
    now = time.monotonic()
    try:
        with open('/proc/stat', encoding='ascii') as source:
            fields = list(map(int, source.readline().split()[1:]))
        total, idle = sum(fields[:8]), fields[3] + fields[4]
        if previous.get('cpu'):
            delta = total - previous['cpu'][0]
            if delta > 0:
                os.environ['VANY_CPU'] = '{}%'.format(100 * (delta - idle + previous['cpu'][1]) // delta)
        previous['cpu'] = (total, idle)
        with open('/proc/meminfo', encoding='ascii') as source:
            memory = {line.split(':', 1)[0]: int(line.split()[1]) for line in source if line.startswith(('MemTotal:', 'MemAvailable:'))}
        if 'MemTotal' in memory and 'MemAvailable' in memory:
            os.environ['VANY_RAM'] = '{}/{} MiB'.format((memory['MemTotal'] - memory['MemAvailable']) // 1024, memory['MemTotal'] // 1024)
        rx = tx = 0
        with open('/proc/net/dev', encoding='ascii') as source:
            for line in source:
                if ':' not in line: continue
                name, counters = line.split(':', 1)
                if name.strip() == 'lo': continue
                values = counters.split()
                rx += int(values[0]); tx += int(values[8])
        if previous.get('net'):
            old_rx, old_tx, old_time = previous['net']
            elapsed = max(now - old_time, 0.001)
            if rx >= old_rx and tx >= old_tx:
                os.environ['VANY_NET'] = '{}/{} KiB/s'.format(int((rx - old_rx) / elapsed / 1024), int((tx - old_tx) / elapsed / 1024))
        previous['net'] = (rx, tx, now)
    except (OSError, ValueError, IndexError):
        pass


def main():
    if len(sys.argv) < 3:
        return 2
    title, command = sys.argv[1], sys.argv[2:]
    terminal = os.open('/dev/tty', os.O_RDWR)
    old = termios.tcgetattr(terminal)
    rows, cols = terminal_size(terminal)
    child, master = pty.fork()
    if child == 0:
        os.closerange(3, 256)
        os.environ['TERM'] = 'xterm-256color'
        os.environ['VANY_IN_PANE'] = '1'
        try: os.execvp(command[0], command)
        except OSError as error:
            print('Could not start command: {}'.format(error), flush=True)
            os._exit(127)
    headers = status_rows(cols, rows)
    screen = Screen(max(1, rows - 5 - len(headers)), max(1, cols - 2))
    decoder = codecs.getincrementaldecoder('utf-8')('replace')
    resize_pending = True
    done = False
    status = 1
    cancelled = False
    cancel_at = None
    changed = True
    last_draw = 0.0
    last_header = 0.0
    previous_metrics = {}

    def on_resize(_signal, _frame):
        nonlocal resize_pending
        resize_pending = True

    def terminate(_signal, _frame):
        nonlocal cancelled, cancel_at
        cancelled = True
        cancel_at = time.monotonic()
        try: os.killpg(child, signal.SIGINT)
        except ProcessLookupError: pass

    previous_winch = signal.signal(signal.SIGWINCH, on_resize)
    previous_int = signal.signal(signal.SIGINT, terminate)
    previous_term = signal.signal(signal.SIGTERM, terminate)
    try:
        tty.setraw(terminal)
        while True:
            if resize_pending:
                rows, cols = terminal_size(terminal)
                headers = status_rows(cols, rows)
                screen.resize(max(1, rows - 5 - len(headers)), max(1, cols - 2))
                fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', screen.rows, screen.cols, 0, 0))
                try: os.killpg(child, signal.SIGWINCH)
                except ProcessLookupError: pass
                resize_pending = False; changed = True
            now = time.monotonic()
            if now - last_header >= 5:
                sample_metrics(previous_metrics)
                new_headers = status_rows(cols, rows)
                if len(new_headers) != len(headers):
                    resize_pending = True
                elif not changed and rows >= 8 and cols >= 24:
                    parts = ['\x1b7']
                    for index, line in enumerate(new_headers):
                        parts.extend(['\x1b[{};1H|'.format(index + 2), fit(' ' + line, cols - 2), '|'])
                    parts.append('\x1b8')
                    os.write(terminal, ''.join(parts).encode('utf-8', 'replace'))
                headers = new_headers
                last_header = now
            if changed and now - last_draw >= 0.05:
                if rows < 8 or cols < 24:
                    output = '\x1b[H\x1b[2J' + fit('Resize to 24 columns and 8 rows', cols)
                else:
                    inner = cols - 2
                    top = max(0, len(screen.lines) - screen.rows - screen.scroll)
                    visible = screen.lines[top:top + screen.rows]
                    border = '+' + '-' * inner + '+'
                    footer = 'Finished. Up/Down: scroll  Enter: return' if done else 'Type to answer  Ctrl-]: cancel'
                    parts = ['\x1b[H\x1b[2J', border]
                    for line in headers:
                        parts.extend(['\r\n|', fit(' ' + line, inner), '|'])
                    parts.extend(['\r\n|', fit(title, inner), '|\r\n', border])
                    for i in range(screen.rows):
                        line = ''.join(visible[i]) if i < len(visible) else ''
                        parts.extend(['\r\n|', fit(line, inner), '|'])
                    parts.extend(['\r\n|', fit(footer, inner), '|\r\n', border])
                    if not done and not screen.scroll:
                        cursor_row = 4 + len(headers) + screen.row - top
                        cursor_col = min(cols - 1, screen.col + 2)
                        if 4 + len(headers) <= cursor_row < rows - 1:
                            parts.append('\x1b[{};{}H\x1b[?25h'.format(cursor_row, cursor_col))
                    output = ''.join(parts)
                os.write(terminal, output.encode('utf-8', 'replace'))
                last_draw = now; changed = False
            if done and not changed:
                readable, _, _ = select.select([terminal], [], [], 0.1)
            else:
                readable, _, _ = select.select([terminal, master] if not done else [terminal], [], [], 0.05)
            if master in readable:
                try: data = os.read(master, 65536)
                except OSError: data = b''
                if data:
                    screen.feed(decoder.decode(data)); changed = True
                else:
                    _, wait_status = os.waitpid(child, 0)
                    status = os.WEXITSTATUS(wait_status) if os.WIFEXITED(wait_status) else 128 + os.WTERMSIG(wait_status)
                    done = True; changed = True
            if terminal in readable:
                data = os.read(terminal, 4096)
                if not data: terminate(None, None)
                elif done:
                    if data in (b'\x1b[A', b'\x1b[5~'):
                        screen.scroll = min(max(0, len(screen.lines) - screen.rows), screen.scroll + max(1, screen.rows // 2)); changed = True
                    elif data in (b'\x1b[B', b'\x1b[6~'):
                        screen.scroll = max(0, screen.scroll - max(1, screen.rows // 2)); changed = True
                    else: break
                elif b'\x1d' in data:
                    terminate(None, None)
                else:
                    os.write(master, data)
            if cancel_at and not done and time.monotonic() - cancel_at > 2:
                try: os.killpg(child, signal.SIGKILL)
                except ProcessLookupError: pass
                cancel_at = None
        return 130 if cancelled else status
    finally:
        if not done:
            try: os.killpg(child, signal.SIGKILL)
            except ProcessLookupError: pass
            try: os.waitpid(child, 0)
            except ChildProcessError: pass
        os.close(master)
        termios.tcsetattr(terminal, termios.TCSADRAIN, old)
        os.write(terminal, b'\x1b[?25l\x1b[H\x1b[2J')
        os.close(terminal)
        signal.signal(signal.SIGWINCH, previous_winch)
        signal.signal(signal.SIGINT, previous_int)
        signal.signal(signal.SIGTERM, previous_term)


if __name__ == '__main__':
    sys.exit(main())
