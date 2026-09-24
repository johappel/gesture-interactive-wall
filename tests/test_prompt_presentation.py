"""Contract checks for the calm, rotating monitor invitation."""

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class PromptPresentationContractTest(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((ROOT / "config" / "config.json").read_text(encoding="utf-8-sig"))
        self.prompts = json.loads((ROOT / "config" / "prompts.json").read_text(encoding="utf-8-sig"))["prompts"]
        self.main = (ROOT / "renderer" / "scripts" / "main.gd").read_text(encoding="utf-8")
        self.cue = (ROOT / "renderer" / "scripts" / "prompt_cue.gd").read_text(encoding="utf-8")
        self.body_light = (ROOT / "renderer" / "scripts" / "body_light.gd").read_text(encoding="utf-8")

    def test_config_rotates_all_curated_prompts_with_calm_timings(self):
        prompt = self.config["station"]["prompt"]
        self.assertEqual(prompt["prompt_keys"], ["stay_question", "stay_invitation", "trace_hint"])
        self.assertTrue(all(key in self.prompts for key in prompt["prompt_keys"]))
        self.assertGreater(prompt["fade_in_seconds"], prompt["fade_out_seconds"])
        self.assertGreaterEqual(prompt["fade_in_seconds"], 2.0)
        self.assertGreaterEqual(prompt["fade_out_seconds"], 1.0)
        self.assertGreaterEqual(prompt["underline_seconds"], 1.5)
        self.assertEqual(prompt["star_tail_fade_seconds"], 3.0)
        self.assertGreater(prompt["idle_cycle_seconds"], prompt["underline_seconds"])

    def test_renderer_selects_once_per_idle_phase_and_transitions_both_directions(self):
        for marker in (
            "func _resolve_prompt_keys() -> void:",
            "func _select_next_prompt() -> bool:",
            "# A long quiet phase may offer the next curated invitation.",
            "_prompt_index = (_prompt_index + 1) % _prompt_keys.size()",
            "func _set_monitor_prompt_visible(should_show: bool) -> void:",
            '"modulate:a", 1.0, fade_in',
            '"modulate:a", 0.0, fade_out',
            "PromptCueScript",
            "_monitor_prompt_cue.reveal",
            '"reveal", 1.0, underline_duration',
            '"trail_alpha", 0.0, tail_fade',
            "_prompt_rotation_pending",
            "func _finish_monitor_prompt_hide() -> void:",
        ):
            self.assertIn(marker, self.main)

    def test_cue_has_a_star_that_draws_the_underline_and_a_quiet_halo(self):
        for marker in (
            "class_name PromptCue",
            "draw_set_transform(centre, 0.0, Vector2(1.7, 0.52))",
            "var star := start.lerp(end, reveal)",
            "const TRAIL_FRACTION := 0.62",
            "var tail_start_progress := maxf(0.0, reveal - TRAIL_FRACTION)",
            "for segment in range(tail_segments):",
            "var trail_alpha: float = 1.0:",
            "func _draw_star(position: Vector2, accent_alpha: float) -> void:",
        ):
            self.assertIn(marker, self.cue)

    def test_legacy_single_prompt_remains_a_safe_fallback(self):
        self.assertIn('var fallback_key := str(prompt_cfg.get("prompt_key", ""))', self.main)
        self.assertIn('prompt["prompt_keys"] = []', self.main)

    def test_transient_tracks_require_longer_confirmation_and_do_not_emit_sparks_at_rest(self):
        # Longer than the reactive default of 1 (suppresses 1-3 frame ghosts),
        # but kept low enough that a real arrival lights up without a visible
        # confirmation lag.
        confirmation = self.config["features"]["track_confirmation_frames"]
        self.assertGreaterEqual(confirmation, 3)
        self.assertLessEqual(confirmation, 8)
        self.assertGreater(self.config["effects"]["sparks"]["activation_intensity"], 0)
        self.assertIn("var should_emit := intensity >= activation_intensity", self.body_light)
        self.assertIn("_particles.emitting = should_emit", self.body_light)


if __name__ == "__main__":
    unittest.main()
