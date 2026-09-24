"""Unit tests for the compact capture diagnostics aggregation (no camera/ML)."""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from capture.diagnostics import CaptureDiagnostics  # noqa: E402


class CaptureDiagnosticsTest(unittest.TestCase):
    def _diag(self, **kwargs):
        self.lines = []
        return CaptureDiagnostics(
            enabled=True, interval=1.0, printer=self.lines.append, **kwargs
        )

    def test_disabled_records_and_reports_nothing(self):
        lines = []
        diag = CaptureDiagnostics(enabled=False, printer=lines.append)
        diag.record_stage("pose", 0.05)
        diag.record_frame(0.0, raw_poses=3, accepted=2, tracks=2)
        self.assertIsNone(diag.maybe_report(5.0))
        self.assertEqual(lines, [])

    def test_no_report_before_interval_elapsed(self):
        diag = self._diag()
        diag.record_frame(0.0, raw_poses=2, accepted=2, tracks=2)
        self.assertIsNone(diag.maybe_report(0.5))
        self.assertEqual(self.lines, [])

    def test_reports_once_per_interval_and_resets(self):
        diag = self._diag()
        diag.set_camera_info(backend="dshow", fourcc="MJPG", width=1280, height=720, fps=30.0)
        for _ in range(10):
            diag.record_stage("pose", 0.05)
            diag.record_stage("read", 0.004)
            diag.record_frame(0.0, raw_poses=3, accepted=2, tracks=2, temporarily_missing=1)
        line = diag.maybe_report(1.0)
        self.assertIsNotNone(line)
        self.assertEqual(len(self.lines), 1)
        self.assertIn("[capture]", line)
        self.assertIn("camera=30.0fps", line)
        self.assertIn("loop=10.0fps", line)
        self.assertIn("pose=50.0ms", line)
        self.assertIn("raw_poses=3.0", line)
        self.assertIn("accepted=2.0", line)
        self.assertIn("tracks=2", line)
        self.assertIn("missing=1", line)
        self.assertIn("resolution=1280x720", line)
        self.assertIn("backend=dshow", line)
        self.assertIn("fourcc=MJPG", line)
        # Window reset: a fresh short window does not immediately report again.
        self.assertIsNone(diag.maybe_report(1.2))

    def test_rejection_reasons_are_aggregated(self):
        diag = self._diag()
        diag.record_frame(0.0, raw_poses=3, accepted=2, rejections={"torso_visibility": 1})
        diag.record_frame(0.1, raw_poses=3, accepted=2, rejections={"torso_visibility": 2})
        line = diag.maybe_report(1.0)
        self.assertIn("rejected=torso_visibility:3", line)

    def test_dropped_frames_are_surfaced(self):
        diag = self._diag()
        diag.record_frame(0.0, raw_poses=1, accepted=1, dropped=7)
        line = diag.maybe_report(1.0)
        self.assertIn("dropped=7", line)


if __name__ == "__main__":
    unittest.main()
