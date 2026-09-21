"""Renderer-side contract checks runnable without Godot or a GPU."""

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AftereffectWaveRendererContractTest(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((ROOT / "config" / "config.json").read_text(encoding="utf-8-sig"))
        self.main = (ROOT / "renderer" / "scripts" / "main.gd").read_text(encoding="utf-8")
        self.waves = (ROOT / "renderer" / "scripts" / "aftereffect_waves.gd").read_text(encoding="utf-8")

    def test_config_has_complete_safe_wave_family(self):
        wave = self.config["effects"]["aftereffect_waves"]
        self.assertTrue(wave["enabled"])
        for key in (
            "group_window_seconds", "group_distance", "base_width",
            "group_width_per_departure", "max_width", "fronts",
            "front_interval_seconds", "duration_seconds", "inward_distance",
            "line_width", "max_alpha", "dedupe_seconds",
        ):
            self.assertIn(key, wave)
        self.assertGreater(wave["duration_seconds"], 0)
        self.assertGreaterEqual(wave["fronts"], 1)
        self.assertLessEqual(wave["max_alpha"], 0.5)
        self.assertGreater(wave["dedupe_seconds"], wave["duration_seconds"])

    def test_renderer_uses_transient_dedup_and_validates_old_or_invalid_events(self):
        for marker in (
            "AftereffectWavesScript",
            "func _consume_departures",
            "func _valid_departure",
            "func _prune_seen_departure_ids",
            "var _last_frame_time := -INF",
            "if float(frame_time) < _last_frame_time",
            "IDs are only transient UDP duplicate guards",
        ):
            self.assertIn(marker, self.main)
        self.assertIn("_aftereffect_waves.queue_departure", self.main)

    def test_wave_renderer_aggregates_without_storing_ids_and_draws_broad_fronts(self):
        self.assertNotIn('"id"', self.waves)
        for marker in (
            "func queue_departure(edge: String, x: float, y: float)",
            "pending[\"count\"] = count + 1",
            "var width_norm: float = minf(_base_width + float(count - 1)",
            "for front_index in range(_fronts)",
            "draw_polyline(points, color, _line_width, true)",
        ):
            self.assertIn(marker, self.waves)


if __name__ == "__main__":
    unittest.main()
