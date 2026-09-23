"""Tests for the debug-only simulator control channel and the scenario
dropdown in the renderer overlay.

These run without Godot or a socket: the UDP listener is exercised directly,
and the overlay contract is checked at source level.
"""

import json
import socket
import unittest
from pathlib import Path

from capture.control import SimControlServer
from capture.tracker import SIM_SCENARIO_CHOICES

ROOT = Path(__file__).resolve().parents[1]


def _send(port: int, payload) -> None:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        if isinstance(payload, (dict, list)):
            data = json.dumps(payload).encode("utf-8")
        else:
            data = payload if isinstance(payload, bytes) else str(payload).encode("utf-8")
        sock.sendto(data, ("127.0.0.1", port))
    finally:
        sock.close()


class SimControlServerTest(unittest.TestCase):
    def setUp(self):
        # Port 0 lets the OS pick a free port, so tests never clash with a
        # running renderer or simulator.
        self.server = SimControlServer(0, SIM_SCENARIO_CHOICES)

    def tearDown(self):
        self.server.close()

    def test_valid_command_switches_scenario(self):
        _send(self.server.port, {"type": "sim_control", "scenario": "crowd_aura"})
        self.assertEqual(self.server.poll(), "crowd_aura")

    def test_only_the_newest_command_in_a_tick_counts(self):
        _send(self.server.port, {"type": "sim_control", "scenario": "proximity"})
        _send(self.server.port, {"type": "sim_control", "scenario": "long_run"})
        self.assertEqual(self.server.poll(), "long_run")

    def test_unknown_scenario_is_ignored(self):
        _send(self.server.port, {"type": "sim_control", "scenario": "does_not_exist"})
        self.assertIsNone(self.server.poll())

    def test_wrong_type_is_ignored(self):
        _send(self.server.port, {"type": "something_else", "scenario": "proximity"})
        self.assertIsNone(self.server.poll())

    def test_malformed_payload_is_ignored(self):
        _send(self.server.port, b"{ not json")
        _send(self.server.port, "[1, 2, 3]")
        _send(self.server.port, "scenario=crowd_aura")
        self.assertIsNone(self.server.poll())

    def test_poll_returns_none_when_idle(self):
        self.assertIsNone(self.server.poll())

    def test_scenario_choices_include_phase44_and_lifecycle(self):
        self.assertEqual(SIM_SCENARIO_CHOICES[0], "phase44")
        self.assertIn("crowd_aura", SIM_SCENARIO_CHOICES)


class SimControlRendererContractTest(unittest.TestCase):
    def setUp(self):
        self.main = (ROOT / "renderer" / "scripts" / "main.gd").read_text(encoding="utf-8")
        self.overlay = (ROOT / "renderer" / "scripts" / "debug_overlay.gd").read_text(encoding="utf-8")

    def test_renderer_sends_control_packet_to_port_plus_one(self):
        self.assertIn("func request_sim_scenario(scenario: String) -> void:", self.main)
        block = self.main.split("func request_sim_scenario(", 1)[1].split("\nfunc ", 1)[0]
        self.assertIn("var target_port := _port + 1", block)
        self.assertIn('"127.0.0.1"', block)
        self.assertIn('"type": "sim_control"', self.main)

    def test_overlay_has_scenario_dropdown(self):
        for marker in ("_sim_option", "OptionButton.new()", "SIM_SCENARIOS", "_on_sim_scenario_selected"):
            self.assertIn(marker, self.overlay)
        self.assertIn("request_sim_scenario", self.overlay)

    def test_overlay_scenarios_are_a_subset_of_capture_choices(self):
        # The dropdown must never offer a scenario the simulator cannot run.
        for scenario in SIM_SCENARIO_CHOICES:
            self.assertIn('"%s"' % scenario, self.overlay, f"Szenario '{scenario}' fehlt im Dropdown")


class SimLoopClockContractTest(unittest.TestCase):
    def setUp(self):
        self.tracker = (ROOT / "capture" / "tracker.py").read_text(encoding="utf-8")

    def test_scenario_switch_never_rewinds_the_sent_timestamp(self):
        # Rewinding the packet timestamp made the renderer reject every frame
        # and freeze. The scenario phase must have its own clock.
        loop = self.tracker.split("def run_sim(", 1)[1].split("\n\ndef ", 1)[0]
        self.assertIn("scenario_start = start", loop)
        self.assertIn("t = now - start", loop)
        self.assertIn("scenario_time = now - scenario_start", loop)
        self.assertIn("make_simulation_persons(scenario, scenario_time)", loop)
        # The timestamp handed to the tracker/frame stays the monotonic clock.
        self.assertIn("tracker.update(persons, t)", loop)
        # The switch only moves the scenario clock, never `start`.
        switch = loop.split("new_scenario is not None", 1)[1].split("scenario_time", 1)[0]
        self.assertIn("scenario_start = now", switch)
        self.assertNotRegex(switch, r"(?m)^\s*start = now")


if __name__ == "__main__":
    unittest.main()