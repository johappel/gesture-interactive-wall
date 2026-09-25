"""Unit tests for pose-filter classification and diagnostics (no camera/ML).

These pin the diagnosis of the real "yellow shirt" case: distinguishing a pose
that MediaPipe never produced (A) from a pose WIRKLICHT filtered out (B).
"""

import math
import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from capture.features import (  # noqa: E402
    L_HIP,
    L_SHOULDER,
    POSE_ACCEPTED,
    REJECT_ACTIVE_REGION,
    REJECT_INVALID_LANDMARKS,
    REJECT_OUTSIDE_FRAME,
    REJECT_TORSO_VISIBILITY,
    R_HIP,
    classify_person,
    filter_with_diagnostics,
    torso_visibilities,
)

_N = 33


def person(cx, cy):
    pts = [(cx, cy, 1.0)] * _N
    pts[L_SHOULDER] = (cx - 0.05, cy, 1.0)
    pts[12] = (cx + 0.05, cy, 1.0)  # R_SHOULDER
    pts[L_HIP] = (cx - 0.04, cy + 0.1, 1.0)
    pts[R_HIP] = (cx + 0.04, cy + 0.1, 1.0)
    return pts


class ClassifyPersonTest(unittest.TestCase):
    def test_full_visibility_is_accepted(self):
        self.assertEqual(classify_person(person(0.5, 0.5), min_torso_visibility=0.4), POSE_ACCEPTED)

    def test_single_low_torso_landmark_is_reported(self):
        candidate = person(0.5, 0.5)
        candidate[L_HIP] = (0.46, 0.6, 0.31)  # only one landmark under threshold
        self.assertEqual(
            classify_person(candidate, min_torso_visibility=0.4), REJECT_TORSO_VISIBILITY
        )

    def test_boundary_visibility_is_accepted(self):
        candidate = person(0.5, 0.5)
        candidate[L_HIP] = (0.46, 0.6, 0.4)  # exactly at threshold -> accepted
        self.assertEqual(classify_person(candidate, min_torso_visibility=0.4), POSE_ACCEPTED)

    def test_partly_outside_torso_landmark_keeps_visible_person(self):
        candidate = person(0.05, 0.5)
        candidate[L_SHOULDER] = (-0.04, 0.5, 0.9)
        self.assertEqual(classify_person(candidate, 0.4), POSE_ACCEPTED)

    def test_distant_extrapolation_is_rejected(self):
        candidate = person(0.5, 0.5)
        candidate[L_SHOULDER] = (-0.4, 0.5, 0.9)
        self.assertEqual(classify_person(candidate, 0.4), REJECT_OUTSIDE_FRAME)

    def test_torso_center_outside_image_is_rejected(self):
        candidate = person(0.02, 0.5)
        candidate[L_SHOULDER] = (-0.2, 0.5, 0.9)
        candidate[12] = (-0.2, 0.5, 0.9)
        candidate[L_HIP] = (-0.2, 0.6, 0.9)
        candidate[R_HIP] = (-0.2, 0.6, 0.9)
        self.assertEqual(classify_person(candidate, 0.4), REJECT_OUTSIDE_FRAME)

    def test_nan_landmark_is_invalid(self):
        candidate = person(0.5, 0.5)
        candidate[L_SHOULDER] = (float("nan"), 0.5, 1.0)
        self.assertEqual(
            classify_person(candidate, min_torso_visibility=0.4), REJECT_INVALID_LANDMARKS
        )

    def test_too_few_landmarks_is_invalid(self):
        self.assertEqual(classify_person([(0.5, 0.5, 1.0)], 0.4), REJECT_INVALID_LANDMARKS)

    def test_outside_active_region_is_reported(self):
        region = {"enabled": True, "x_min": 0.2, "x_max": 0.8, "y_min": 0.2, "y_max": 0.8}
        self.assertEqual(
            classify_person(person(0.05, 0.5), active_region=region), REJECT_ACTIVE_REGION
        )


class FilterWithDiagnosticsTest(unittest.TestCase):
    def test_counts_and_details_for_rejected_torso(self):
        low = person(0.5, 0.5)
        low[R_HIP] = (0.54, 0.6, 0.2)
        accepted, counts, details = filter_with_diagnostics(
            [person(0.4, 0.5), low], min_torso_visibility=0.4
        )
        self.assertEqual(len(accepted), 1)
        self.assertEqual(counts, {REJECT_TORSO_VISIBILITY: 1})
        self.assertEqual(details[0]["reason"], REJECT_TORSO_VISIBILITY)
        self.assertEqual(details[0]["threshold"], 0.4)
        self.assertIn("RH", details[0]["visibility"])
        self.assertAlmostEqual(details[0]["visibility"]["RH"], 0.2, places=2)

    def test_all_accepted_leaves_no_rejections(self):
        accepted, counts, details = filter_with_diagnostics(
            [person(0.4, 0.5), person(0.6, 0.5)], min_torso_visibility=0.4
        )
        self.assertEqual(len(accepted), 2)
        self.assertEqual(counts, {})
        self.assertEqual(details, [])


class TorsoVisibilitiesTest(unittest.TestCase):
    def test_reports_four_torso_values(self):
        vis = torso_visibilities(person(0.5, 0.5))
        self.assertEqual(set(vis.keys()), {"LS", "RS", "LH", "RH"})
        for value in vis.values():
            self.assertTrue(math.isfinite(value))


if __name__ == "__main__":
    unittest.main()
