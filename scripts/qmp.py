#!/usr/bin/env python3
"""Minimal QMP client for the Omarchy VM.

Usage: qmp.py <command> [json-args]
Examples:
  qmp.py query-status
  qmp.py screendump '{"filename": "/tmp/shot.ppm"}'
  qmp.py system_powerdown
  qmp.py send-key '{"keys": [{"type": "qcode", "data": "ret"}]}'
"""
import json
import os
import socket
import sys

SOCK = sys.argv[1] if False else None  # placeholder, real path below

def main():
    sock_path = sys.argv.pop(1) if sys.argv[1].endswith(".sock") else os.path.expanduser("~/omarchy-vm/qmp.sock")
    command = sys.argv[1]
    args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else None

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(15)
    s.connect(sock_path)
    f = s.makefile("rw")

    def send(obj):
        f.write(json.dumps(obj) + "\n")
        f.flush()

    def recv():
        while True:
            line = f.readline()
            if not line:
                raise SystemExit("QMP connection closed")
            msg = json.loads(line)
            if "event" in msg:  # skip async events
                continue
            return msg

    recv()  # greeting
    send({"execute": "qmp_capabilities"})
    r = recv()
    if "error" in r:
        raise SystemExit(f"handshake failed: {r['error']}")

    cmd = {"execute": command}
    if args is not None:
        cmd["arguments"] = args
    send(cmd)
    r = recv()
    print(json.dumps(r.get("return", r.get("error")), indent=2, default=str))

if __name__ == "__main__":
    main()
