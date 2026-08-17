"""Local UDP JSON sender. Emits one packet per frame to 127.0.0.1."""

from __future__ import annotations

import json
import socket


class UdpJsonSender:
    def __init__(self, host: str = "127.0.0.1", port: int = 4242) -> None:
        self.addr = (host, port)
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    def send(self, payload: dict) -> None:
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self._sock.sendto(data, self.addr)

    def close(self) -> None:
        self._sock.close()
