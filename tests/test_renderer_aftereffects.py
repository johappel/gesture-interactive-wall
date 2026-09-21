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
        self.field = (ROOT / "renderer" / "scripts" / "aftereffect_wave_field.gd").read_text(encoding="utf-8")
        self.shader = (ROOT / "renderer" / "shaders" / "aftereffect_wave.gdshader").read_text(encoding="utf-8")

    def test_config_has_complete_safe_wave_family(self):
        wave = self.config["effects"]["aftereffect_waves"]
        self.assertTrue(wave["enabled"])
        for key in (
            "group_window_seconds", "group_distance", "group_width_per_departure",
            "duration_seconds", "initial_origin_outset", "origin_escape_distance",
            "start_radius", "propagation_speed", "band_width",
            "source_glow_radius", "echo_spacing", "echo_strength", "max_alpha",
            "fade_start_progress", "fade_end_progress", "glow_strength", "warm_color",
            "blue_color", "dedupe_seconds",
        ):
            self.assertIn(key, wave)
        self.assertGreater(wave["duration_seconds"], 0)
        self.assertLessEqual(wave["max_alpha"], 0.5)
        self.assertLess(wave["fade_start_progress"], wave["fade_end_progress"])
        self.assertGreater(wave["dedupe_seconds"], wave["duration_seconds"])
        # Colours are an aesthetic choice tuned for real facade projection, so
        # only their validity is contractual here, not a specific hue.
        for key in ("warm_color", "blue_color"):
            self.assertRegex(wave[key], r"^#[0-9a-fA-F]{6}$")

    def test_renderer_uses_transient_dedup_and_validates_old_or_invalid_events(self):
        for marker in (
            "AftereffectWavesScript",
            "func _consume_departures",
            "func _valid_departure",
            "Godot's JSON parser may expose an integral JSON id as TYPE_FLOAT",
            "float(int(raw_id)) != float(raw_id)",
            "func _prune_seen_departure_ids",
            "var _last_frame_time := -INF",
            "if float(frame_time) < _last_frame_time",
            "var frames: Array[Dictionary] = []",
            "for index in range(frames.size()):",
            "A departure is intentionally one-shot",
            "IDs are only transient UDP duplicate guards",
        ):
            self.assertIn(marker, self.main)
        self.assertIn("_aftereffect_waves.queue_departure", self.main)

    def test_wave_renderer_aggregates_without_storing_ids_and_uses_shader_field(self):
        self.assertNotIn('"id"', self.waves)
        for marker in (
            "func queue_departure(edge: String, x: float, y: float)",
            "pending[\"count\"] = count + 1",
            "const AftereffectWaveFieldScript",
            "func _create_wave",
            "field.update_wave",
            "Intentionally anonymous: only edge, shared axis and group size survive.",
        ):
            self.assertIn(marker, self.waves)
        self.assertNotIn("draw_polyline", self.waves)

    def test_shader_field_has_outward_virtual_origin_and_soft_additive_light(self):
        for marker in (
            "class_name AftereffectWaveField",
            "initial_outset + escape_distance",
            '"origin_escape_distance"',
            "origin_uv",
            "draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color.WHITE)",
        ):
            self.assertIn(marker, self.field)
        for marker in (
            "shader_type canvas_item;",
            "render_mode unshaded, blend_add;",
            "gaussian_band",
            "source_glow_radius",
            "fade_start_progress",
            "smoothstep(fade_start_progress, fade_end_progress, progress)",
            "travelling_colour = mix(warm_color.rgb, blue_color.rgb",
        ):
            self.assertIn(marker, self.shader)


if __name__ == "__main__":
    unittest.main()
