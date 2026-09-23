"""Source-level contract tests for the live config reload and the debug
slider overlay. These do not launch Godot; they verify the guarantees that
matter for safety: bounded sliders, atomic LF writes, effects-only reload
(never capture/tracking parameters), and defensive handling of invalid config.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class LiveReloadRendererContractTest(unittest.TestCase):
    def setUp(self):
        self.main = (ROOT / "renderer" / "scripts" / "main.gd").read_text(encoding="utf-8")

    def test_reload_functions_present(self):
        for marker in (
            "func _poll_config_reload() -> void:",
            "func _reload_from_config() -> void:",
            "func _apply_live_effects(",
            "func set_live_effects(",
            "func live_effects_raw() -> Dictionary:",
            "func save_live_effects_to_config() -> bool:",
        ):
            self.assertIn(marker, self.main)

    def test_process_polls_config_on_an_interval(self):
        self.assertIn("CONFIG_POLL_INTERVAL", self.main)
        self.assertIn("_config_poll_elapsed += delta", self.main)
        self.assertIn("_poll_config_reload()", self.main)

    def test_reload_only_triggers_on_modified_time_change(self):
        poll = self.main.split("func _poll_config_reload()", 1)[1].split("\nfunc ", 1)[0]
        self.assertIn("FileAccess.get_modified_time", poll)
        self.assertIn("if mtime == _config_mtime:", poll)
        self.assertIn("return", poll)

    def test_invalid_config_keeps_current_values(self):
        reload = self.main.split("func _reload_from_config()", 1)[1].split("\nfunc ", 1)[0]
        # An unparsable/incomplete file must not wipe the running effects.
        self.assertIn("push_warning", reload)
        self.assertIn("behalte aktuelle Werte", reload)
        # The warning path returns before applying anything.
        self.assertLess(reload.index("behalte aktuelle Werte"), reload.index("_apply_live_effects"))

    def test_reload_applies_only_the_effects_block(self):
        reload = self.main.split("func _reload_from_config()", 1)[1].split("\nfunc ", 1)[0]
        self.assertIn('config.get("effects", {})', reload)
        # The UDP port is bound once and must not be reloaded live.
        self.assertNotIn("_port", reload)
        self.assertNotIn("_udp.bind", reload)

    def test_save_is_atomic_effects_only_and_lf(self):
        save = self.main.split("func save_live_effects_to_config()", 1)[1].split("\nfunc ", 1)[0]
        # Temp file + rename keeps the poller from reading a torn file.
        self.assertIn('_config_path + ".tmp"', save)
        self.assertIn("DirAccess.rename_absolute", save)
        # The effects value is spliced in place by brace span; the rest of the
        # file (and its integer types) is left byte-for-byte untouched.
        self.assertIn("_effects_span(text)", save)
        self.assertIn('JSON.stringify(_effects_raw, "    ", false)', save)
        # Avoid self-triggering the poller after our own write.
        self.assertIn("_config_mtime = FileAccess.get_modified_time", save)

    def test_save_never_round_trips_the_whole_config_through_json(self):
        # Round-tripping would demote every int in camera/pose/features/station
        # to a float (the regression that broke the Windows operations test).
        save = self.main.split("func save_live_effects_to_config()", 1)[1].split("\nfunc ", 1)[0]
        self.assertNotIn("json.parse", save)
        self.assertNotIn("config[\"effects\"] = _effects_raw", save)

    def test_f3_toggles_the_overlay(self):
        self.assertIn("keycode == KEY_F3", self.main)
        self.assertIn("_debug_overlay.toggle()", self.main)

    def test_raw_effects_survive_mode_resolution_for_saving(self):
        # The saved block is the raw config, not the mode-resolved render state,
        # so minimal_mode does not get baked into persisted enabled flags.
        self.assertIn("_effects = _resolve_effect_modes(_effects_raw.duplicate(true))", self.main)


class DebugOverlayContractTest(unittest.TestCase):
    def setUp(self):
        path = ROOT / "renderer" / "scripts" / "debug_overlay.gd"
        self.assertTrue(path.is_file(), "debug_overlay.gd fehlt")
        self.overlay = path.read_text(encoding="utf-8")

    def test_overlay_binds_main_and_toggles(self):
        for marker in ("func bind_main(", "func toggle()", "func sync_from_config()"):
            self.assertIn(marker, self.overlay)

    def test_overlay_never_touches_capture_parameters(self):
        # The overlay is renderer-only. Capture/tracking parameters live in a
        # separate process and must never be written from here.
        for forbidden in ('"camera"', '"pose"', '"features"', '"network"', "track_grace_period"):
            self.assertNotIn(forbidden, self.overlay)

    def test_sliders_are_bounded(self):
        # Every non-color parameter row must carry a finite min/max/step so no
        # slider can drive the engine into an invalid state.
        param_lines = re.findall(r'\{"key": "[^"]+".*\}', self.overlay)
        numeric = [line for line in param_lines if '"type": "color"' not in line and '"min"' in line]
        self.assertTrue(numeric, "keine numerischen Parameterzeilen gefunden")
        for line in numeric:
            self.assertRegex(line, r'"min":\s*[-\d.]+')
            self.assertRegex(line, r'"max":\s*[-\d.]+')
            self.assertRegex(line, r'"step":\s*[-\d.]+')

    def test_crash_critical_minimums_stay_above_zero(self):
        # These clamps mirror the effects' configure(): a zero here would mean
        # zero particle counts or a degenerate wave radius.
        self.assertRegex(self.overlay, r'"amount_min", "min": 1')
        self.assertRegex(self.overlay, r'"amount_max", "min": 1')
        self.assertRegex(self.overlay, r'"start_radius", "min": 0\.001')
        self.assertRegex(self.overlay, r'"propagation_speed", "min": 0\.001')
        self.assertRegex(self.overlay, r'"orbs_min", "min": 1')

    def test_change_handlers_are_guarded_against_sync_feedback(self):
        # Programmatic value updates during sync must not re-emit into config.
        self.assertIn("_suppress", self.overlay)
        for handler in ("_on_slider_changed", "_on_color_changed", "_on_enabled_toggled"):
            block = self.overlay.split("func %s(" % handler, 1)[1].split("\nfunc ", 1)[0]
            self.assertIn("if _suppress:", block)


if __name__ == "__main__":
    unittest.main()
