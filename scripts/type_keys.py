#!/usr/bin/env python3
"""Type a string into the VM via QMP send-key (US layout)."""
import json
import os
import socket
import sys
import time

SOCK = os.path.expanduser("~/omarchy-vm/qmp.sock")

QCODE = {c: c for c in "abcdefghijklmnopqrstuvwxyz0123456789"}
QCODE.update({
    " ": "spc", ".": "dot", ",": "comma", "-": "minus", "=": "equal",
    "/": "slash", "\\": "backslash", ";": "semicolon", "'": "apostrophe",
    "[": "bracket_left", "]": "bracket_right", "`": "grave_accent",
    "\n": "ret",
})
SHIFTED = {
    ":": "semicolon", "_": "minus", "+": "equal", "?": "slash",
    "|": "backslash", '"': "apostrophe", "~": "grave_accent",
    "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6",
    "&": "7", "*": "8", "(": "9", ")": "0", "<": "comma", ">": "dot",
}

def main():
    text = sys.argv[1]
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(10)
    s.connect(SOCK)
    f = s.makefile("rw")

    def send(obj):
        f.write(json.dumps(obj) + "\n")
        f.flush()

    def recv():
        while True:
            msg = json.loads(f.readline())
            if "event" not in msg:
                return msg

    recv()
    send({"execute": "qmp_capabilities"})
    recv()

    for ch in text:
        if ch.isupper():
            keys = [{"type": "qcode", "data": "shift"}, {"type": "qcode", "data": ch.lower()}]
        elif ch in SHIFTED:
            keys = [{"type": "qcode", "data": "shift"}, {"type": "qcode", "data": SHIFTED[ch]}]
        elif ch in QCODE:
            keys = [{"type": "qcode", "data": QCODE[ch]}]
        else:
            continue
        send({"execute": "send-key", "arguments": {"keys": keys, "hold-time": 50}})
        r = recv()
        if "error" in r:
            raise SystemExit(f"send-key failed: {r['error']}")
        time.sleep(0.06)
    print("TYPED_OK")

if __name__ == "__main__":
    main()
