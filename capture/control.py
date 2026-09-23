"""Debug-only control channel for the simulator.

The renderer never sends production data back to capture. This tiny listener
exists solely so the debug overlay can switch the synthetic scenario while the
simulator is running; it is bound to the loopback interface only and accepts a
single whitelisted field (the scenario name).

No camera, pose, feature or network production values pass through here.
"""

from __future__ import annotations

import json
import socket
from typing import Iterable


class SimControlServer:
    """Receives ``{"type": "sim_control", "scenario": "..."}`` on loopback.

    Frames that do not parse, are not dictionaries, carry the wrong type or
    name an unknown scenario are ignored; the last valid scenario stays active.
    """

    def __init__(self, port: int, scenarios: Iterable[str], host: str = "127.0.0.1") -> None:
        self._scenarios = frozenset(scenarios)
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._sock.bind((host, port))
        # Non-blocking: the simulator polls this once per frame and must never
        # stall its send loop waiting for a control packet.
        self._sock.setblocking(False)

    @property
    def port(self) -> int:
        return int(self._sock.getsockname()[1])

    def poll(self) -> str | None:
        """Return a valid new scenario name, or None if nothing usable arrived."""
        latest: str | None = None
        while True:
            try:
                data, _ = self._sock.recvfrom(4096)
            except (BlockingIOError, OSError):
                break
            scenario = self._parse(data)
            if scenario is not None:
                # Keep draining; only the newest command in this tick counts.
                latest = scenario
        return latest

    def _parse(self, data: bytes) -> str | None:
        try:
            payload = json.loads(data.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None
        if not isinstance(payload, dict) or payload.get("type") != "sim_control":
            return None
        scenario = payload.get("scenario")
        if not isinstance(scenario, str) or scenario not in self._scenarios:
            return None
        return scenario

    def close(self) -> None:
        self._sock.close()