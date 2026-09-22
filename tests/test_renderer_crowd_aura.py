"""Renderer-side contract checks for the crowd_aura effect family.

These run without Godot or a GPU. They pin the config contract, the isolating
lifecycle (disabled means not created and not simulated), the data robustness
and the removal of the retired effect families.
"""

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

RETIRED_EFFECT_KEYS = ("mist", "crowd_field", "floating_bodies", "waves")


def _quoted_names(block: str) -> set:
    """Return the exact quoted identifiers in a GDScript array literal.

    A plain substring check would wrongly match `waves` inside
    `aftereffect_waves`, so the names are extracted as whole tokens.
    """
    return set(re.findall(r'"([a-z_]+)"', block))


def _effect_names_block(main: str) -> str:
    """Return the array literal inside _effect_names().

    Splitting on the first `]` would hit `Array[String]` in the signature, so
    the block is taken between the opening `[` after the colon and its match.
    """
    body = main.split("func _effect_names()", 1)[1]
    body = body.split(":", 1)[1]
    return body.split("[", 1)[1].split("]", 1)[0]


class CrowdAuraConfigTest(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((ROOT / "config" / "config.json").read_text(encoding="utf-8-sig"))
        self.effects = self.config["effects"]

    def test_config_has_complete_safe_crowd_aura_family(self):
        aura = self.effects["crowd_aura"]
        self.assertTrue(aura["enabled"])
        for key in (
            "min_people", "full_strength_people", "fade_in_seconds", "fade_out_seconds",
            "pulse_seconds", "padding", "softness", "min_alpha", "max_alpha",
            "energy_influence", "individual_dimming_max", "body_clearance",
            "gap_emphasis", "warm_color", "cool_color",
        ):
            self.assertIn(key, aura)
        self.assertGreaterEqual(aura["min_people"], 1)
        self.assertGreater(aura["full_strength_people"], aura["min_people"])
        self.assertGreater(aura["fade_in_seconds"], 0)
        self.assertGreater(aura["fade_out_seconds"], 0)
        self.assertLessEqual(aura["min_alpha"], aura["max_alpha"])
        self.assertLessEqual(aura["max_alpha"], 0.6)
        self.assertGreaterEqual(aura["individual_dimming_max"], 0.0)
        self.assertLess(aura["individual_dimming_max"], 1.0)
        for key in ("warm_color", "cool_color"):
            self.assertRegex(aura[key], r"^#[0-9a-fA-F]{6}$")

    def test_retired_effect_families_are_gone_from_config(self):
        for key in RETIRED_EFFECT_KEYS:
            self.assertNotIn(key, self.effects, f"Altlast '{key}' noch in config.json")

    def test_aftereffect_waves_remains_intact(self):
        self.assertIn("aftereffect_waves", self.effects)
        self.assertTrue(self.effects["aftereffect_waves"]["enabled"])


class CrowdAuraRendererContractTest(unittest.TestCase):
    def setUp(self):
        self.main = (ROOT / "renderer" / "scripts" / "main.gd").read_text(encoding="utf-8")
        self.aura = (ROOT / "renderer" / "scripts" / "crowd_aura.gd").read_text(encoding="utf-8")
        self.shader = (ROOT / "renderer" / "shaders" / "crowd_aura.gdshader").read_text(encoding="utf-8")
        self.body_light = (ROOT / "renderer" / "scripts" / "body_light.gd").read_text(encoding="utf-8")

    def test_effect_names_contain_crowd_aura_and_no_retired_families(self):
        names = _quoted_names(_effect_names_block(self.main))
        self.assertIn("crowd_aura", names)
        self.assertIn("aftereffect_waves", names)
        for key in RETIRED_EFFECT_KEYS:
            self.assertNotIn(key, names, f"Altlast '{key}' noch in _effect_names()")

    def test_disabled_aura_is_not_created_and_not_simulated(self):
        for marker in (
            "func _setup_crowd_aura() -> void:",
            'if not _effect_enabled("crowd_aura", false):',
            "CrowdAuraScript.new()",
            "func _update_crowd_aura(",
            "if _crowd_aura == null:",
        ):
            self.assertIn(marker, self.main)
        # The setup guard must return before creating the node.
        setup = self.main.split("func _setup_crowd_aura()", 1)[1].split("func ", 1)[0]
        self.assertLess(setup.index("return"), setup.index("CrowdAuraScript.new()"))

    def test_aura_is_derived_from_existing_anonymous_crowd_data(self):
        for marker in (
            'data.get("crowd", {})',
            'crowd.get("count")',
            'crowd.get("energy")',
            "normalized_positions",
            "_crowd_aura.update_crowd(",
        ):
            self.assertIn(marker, self.main)
        # No new protocol field is introduced for the aura.
        self.assertNotIn('data.get("aura"', self.main)

    def test_aura_uses_smoothed_collective_strength_not_a_hard_switch(self):
        for marker in (
            "func _target_strength(count: int) -> float:",
            "_fade_in_seconds if target_strength > _strength else _fade_out_seconds",
            "func collective_weight() -> float:",
            "func individual_weight() -> float:",
            "1.0 - _strength * _individual_dimming_max",
        ):
            self.assertIn(marker, self.aura)

    def test_energy_modulates_but_never_gates_visibility(self):
        # Energy must only sway an already present atmosphere. The sway factor
        # is mixed toward 1.0, so energy=0 can never switch the field off.
        self.assertIn("energy_sway", self.shader)
        self.assertIn("mix(1.0, 0.75 + 0.5 * breath", self.shader)
        self.assertIn("step(0.0001, strength)", self.shader)
        # Visibility is gated by strength alone, never by energy.
        self.assertNotIn("step(0.0001, energy", self.shader)

    def test_individual_effects_recede_without_erasing_people(self):
        for marker in (
            "func set_individual_weight(weight: float) -> void:",
            "_individual_weight = clamp(weight, 0.0, 1.0)",
        ):
            self.assertIn(marker, self.body_light)
        self.assertIn("_apply_collective_weight()", self.main)

    def test_crowd_dimming_never_makes_a_person_translucent(self):
        # The regression this guards: dimming a body by lowering its alpha
        # lets the aura shine through and blurs the individual into the group.
        # A person must stay fully opaque; only size and brightness recede.
        self.assertIn("var dim := _individual_weight", self.body_light)
        self.assertIn("Color(core.r, core.g, core.b, 1.0)", self.body_light)
        self.assertNotIn("hdr.r, hdr.g, hdr.b, _individual_weight", self.body_light)

    def test_glow_has_a_definite_core_not_only_a_falloff(self):
        # A pure falloff has no definite centre; many overlapping bodies would
        # merge into one wash. The texture keeps a near-solid core plateau.
        self.assertIn("const CORE_FRACTION", self.body_light)
        self.assertIn("CORE_FRACTION * 0.62", self.body_light)
        self.assertIn("grad.offsets = PackedFloat32Array", self.body_light)

    def test_glow_bloom_stays_narrow_and_high_thresholded(self):
        # The widest bloom pass smears bright cores into one another; only the
        # narrow passes stay enabled and only genuinely bright cores bloom.
        self.assertIn("env.set_glow_level(4, 0.5)", self.main)
        self.assertIn("env.glow_hdr_threshold = 0.95", self.main)
        self.assertNotIn("env.set_glow_level(5", self.main)

    def test_aura_emphasises_the_space_between_bodies(self):
        # The field must be withheld around each body so the "we" reads as the
        # space between people, not as a bright wash over everyone.
        for marker in (
            "uniform int body_count",
            "uniform vec2 body_positions[MAX_BODIES]",
            "uniform float body_clearance",
            "uniform float gap_emphasis",
            "float nearest_body_distance(vec2 uv)",
            "field *= mix(1.0 - clamp(gap_emphasis, 0.0, 1.0), 1.0, clearance)",
        ):
            self.assertIn(marker, self.shader)
        for marker in (
            "const MAX_BODIES := 16",
            "func _update_body_positions(",
            "func _active_body_count() -> int:",
            "set_shader_parameter(\"body_positions\", _body_positions)",
        ):
            self.assertIn(marker, self.aura)

    def test_dimming_never_writes_an_invalid_particle_amount(self):
        # Godot rejects an amount below 1. The weight may reduce the count but
        # must not assign zero while emitting.
        self.assertIn("if should_emit:", self.body_light)
        self.assertIn("_particles.amount = max(amount, 1)", self.body_light)
        self.assertNotIn("_particles.amount = amount if should_emit else 0", self.body_light)

    def test_minimal_mode_does_not_include_crowd_aura(self):
        main = self.main
        minimal = main.split('if bool(resolved.get("minimal_mode", false)):', 1)[1].split("\n\n", 1)[0]
        self.assertIn('"body_glow", "trails", "proximity_bridges"', minimal)
        self.assertNotIn("crowd_aura", minimal)

    def test_shader_is_a_soft_shared_field_not_a_cloud_or_force_field(self):
        for marker in (
            "shader_type canvas_item;",
            "render_mode unshaded, blend_add;",
            "half_extent",
            "smoothstep(1.0 - softness, 1.0 + padding, radial)",
            "mix(warm_color.rgb, cool_color.rgb",
        ):
            self.assertIn(marker, self.shader)
        # No procedural noise/fog simulation: the aura is a smooth field, not
        # a cloud or smoke texture.
        for forbidden in ("noise(", "fbm(", "smoke", "fog_density"):
            self.assertNotIn(forbidden, self.shader.lower())


class RetiredEffectRegressionTest(unittest.TestCase):
    """Guard against the retired effect families creeping back in.

    `aftereffect_waves` is explicitly exempt: it is implemented, wanted and
    must stay untouched.
    """

    def test_no_retired_effect_key_in_config_or_renderer_defaults(self):
        config = json.loads((ROOT / "config" / "config.json").read_text(encoding="utf-8-sig"))
        effects = config["effects"]
        for key in RETIRED_EFFECT_KEYS:
            self.assertNotIn(key, effects)

        main = (ROOT / "renderer" / "scripts" / "main.gd").read_text(encoding="utf-8")
        names = _quoted_names(_effect_names_block(main))
        defaults_block = main.split("func _default_effects()", 1)[1].split("func _default_station", 1)[0]
        for key in RETIRED_EFFECT_KEYS:
            self.assertNotIn(key, names)
            self.assertNotIn(f'"{key}"', defaults_block)

    def test_aftereffect_waves_files_and_family_are_preserved(self):
        for relative in (
            "renderer/scripts/aftereffect_waves.gd",
            "renderer/scripts/aftereffect_wave_field.gd",
            "renderer/shaders/aftereffect_wave.gdshader",
        ):
            self.assertTrue((ROOT / relative).is_file(), relative)
        main = (ROOT / "renderer" / "scripts" / "main.gd").read_text(encoding="utf-8")
        self.assertIn("AftereffectWavesScript", main)
        self.assertIn("_aftereffect_waves.queue_departure", main)


if __name__ == "__main__":
    unittest.main()