"""Tests for CLI parsing, config overrides and frame building (no camera/ML deps)."""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from capture.camera import _backend_id  # noqa: E402
from capture.tracker import apply_overrides, build_frame, build_parser, load_config  # noqa: E402


class _FakeCv2:
    CAP_ANY = 0
    CAP_DSHOW = 700
    CAP_MSMF = 1400


class ParserTest(unittest.TestCase):
    def test_defaults(self):
        args = build_parser().parse_args([])
        self.assertFalse(args.sim)
        self.assertFalse(args.list_cameras)
        self.assertIsNone(args.camera)
        self.assertIsNone(args.backend)

    def test_camera_and_backend(self):
        args = build_parser().parse_args(["--camera", "2", "--backend", "dshow"])
        self.assertEqual(args.camera, 2)
        self.assertEqual(args.backend, "dshow")

    def test_rejects_unknown_backend(self):
        with self.assertRaises(SystemExit):
            build_parser().parse_args(["--backend", "webrtc"])


class OverrideTest(unittest.TestCase):
    def _cfg(self):
        return {"camera": {"index": 0, "backend": "any"}}

    def test_no_override_keeps_config(self):
        args = build_parser().parse_args([])
        cfg = apply_overrides(self._cfg(), args)
        self.assertEqual(cfg["camera"]["index"], 0)
        self.assertEqual(cfg["camera"]["backend"], "any")

    def test_camera_override(self):
        args = build_parser().parse_args(["--camera", "3"])
        cfg = apply_overrides(self._cfg(), args)
        self.assertEqual(cfg["camera"]["index"], 3)

    def test_backend_override(self):
        args = build_parser().parse_args(["--backend", "msmf"])
        cfg = apply_overrides(self._cfg(), args)
        self.assertEqual(cfg["camera"]["backend"], "msmf")


class BackendIdTest(unittest.TestCase):
    def test_known_backends(self):
        self.assertEqual(_backend_id(_FakeCv2, "any"), 0)
        self.assertEqual(_backend_id(_FakeCv2, "dshow"), 700)
        self.assertEqual(_backend_id(_FakeCv2, "msmf"), 1400)

    def test_unknown_backend_raises(self):
        with self.assertRaises(ValueError):
            _backend_id(_FakeCv2, "nope")


class ConfigTest(unittest.TestCase):
    def test_config_has_camera_backend_key(self):
        cfg = load_config()
        self.assertIn("backend", cfg["camera"])
        self.assertIn(cfg["camera"]["backend"], ("any", "dshow", "msmf"))


class FrameTest(unittest.TestCase):
    def test_frame_shape(self):
        frame = build_frame(bodies=[{"id": 0}], pairs=[], energy=0.5, t=1.2345)
        self.assertEqual(frame["t"], 1.234)
        self.assertEqual(frame["crowd"], {"count": 1, "energy": 0.5})
        self.assertEqual(frame["bodies"], [{"id": 0}])
        self.assertEqual(frame["pairs"], [])


if __name__ == "__main__":
    unittest.main()
