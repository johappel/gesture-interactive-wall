"""Tests for CLI parsing, config overrides and frame building (no camera/ML deps)."""

import io
import os
import sys
import unittest
from types import ModuleType, SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from capture.camera import _backend_id, _enumerated_windows_cameras, choose_camera  # noqa: E402
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


class CameraSelectionTest(unittest.TestCase):
    def setUp(self):
        self.streamcam = {
            "index": 701,
            "backend": "any",
            "name": "Logitech StreamCam",
            "path": r"\\?\usb#streamcam-port-2",
            "vid": "046D",
            "pid": "0893",
        }
        self.c920 = {
            "index": 702,
            "backend": "any",
            "name": "HD Pro Webcam C920",
            "path": r"\\?\usb#c920-port-1",
            "vid": "046D",
            "pid": "082D",
        }
        self.cameras = [self.streamcam, self.c920]

    def test_path_is_preferred(self):
        config = {
            "device_path": self.c920["path"],
            "vid": "046D",
            "pid": "0893",
            "name": "Logitech StreamCam",
        }
        self.assertIs(choose_camera(config, self.cameras), self.c920)

    def test_vid_pid_survive_changed_usb_path_and_index(self):
        config = {
            "device_path": r"\\?\usb#old-port",
            "vid": "0x046d",
            "pid": "0893",
            "name": "Logitech StreamCam",
            "index": 1,
        }
        self.assertIs(choose_camera(config, self.cameras), self.streamcam)

    def test_name_and_legacy_index_fallbacks(self):
        self.assertIs(choose_camera({"name": "logitech streamcam"}, self.cameras), self.streamcam)
        self.assertIs(
            choose_camera({"index": 702, "backend": "any"}, self.cameras), self.c920
        )

    def test_windows_enumeration_encodes_backend_and_deduplicates(self):
        module = ModuleType("cv2_enumerate_cameras")

        def enumerate_cameras(api):
            if api == 700:
                return [
                    SimpleNamespace(index=1, name="StreamCam A", path="usb#instance-a#{dshow}", vid=0x046D, pid=0x0893),
                    SimpleNamespace(index=2, name="StreamCam B", path="usb#instance-b#{dshow}", vid=0x046D, pid=0x0893),
                ]
            return [
                SimpleNamespace(index=2, name="StreamCam A", path="usb#instance-a#{msmf}", vid=0x046D, pid=0x0893)
            ]

        module.enumerate_cameras = enumerate_cameras
        with patch.dict(sys.modules, {"cv2_enumerate_cameras": module}):
            cameras = _enumerated_windows_cameras(_FakeCv2, "any")
        self.assertEqual(len(cameras), 2)
        self.assertEqual({camera["index"] for camera in cameras}, {701, 702})
        self.assertEqual(cameras[0]["source_backend"], "dshow")
        self.assertEqual(cameras[0]["backend"], "any")


class ConfigTest(unittest.TestCase):
    def test_config_has_camera_backend_key(self):
        cfg = load_config()
        self.assertIn("backend", cfg["camera"])
        self.assertIn(cfg["camera"]["backend"], ("any", "dshow", "msmf"))
        for key in ("name", "device_path", "vid", "pid"):
            self.assertIn(key, cfg["camera"])

    def test_config_loader_accepts_windows_utf8_bom(self):
        data = b'\xef\xbb\xbf{"camera":{"index":701}}'

        def fake_open(*_args, **kwargs):
            return io.TextIOWrapper(io.BytesIO(data), encoding=kwargs["encoding"])

        with patch("builtins.open", side_effect=fake_open):
            self.assertEqual(load_config("config.json")["camera"]["index"], 701)


class FrameTest(unittest.TestCase):
    def test_frame_shape(self):
        frame = build_frame(bodies=[{"id": 0}], pairs=[], energy=0.5, t=1.2345)
        self.assertEqual(frame["t"], 1.234)
        self.assertEqual(frame["crowd"], {"count": 1, "energy": 0.5})
        self.assertEqual(frame["bodies"], [{"id": 0}])
        self.assertEqual(frame["pairs"], [])


if __name__ == "__main__":
    unittest.main()
